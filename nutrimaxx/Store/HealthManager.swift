import Foundation
import HealthKit

/// Wraps HealthKit access: reads weight and active energy (with live updates
/// via observer queries) and writes logged nutrition back to Apple Health.
@MainActor
final class HealthManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var latestWeightKg: Double?
    @Published var activeEnergyTodayKcal: Double?

    private let store = HKHealthStore()
    private var observersStarted = false

    var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var weightType: HKQuantityType? { HKObjectType.quantityType(forIdentifier: .bodyMass) }
    private var activeEnergyType: HKQuantityType? { HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) }

    private var readTypes: Set<HKObjectType> {
        Set([weightType, activeEnergyType].compactMap { $0 })
    }

    private var shareTypes: Set<HKSampleType> {
        let ids: [HKQuantityTypeIdentifier] = [
            .dietaryEnergyConsumed, .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal,
        ]
        return Set(ids.compactMap { HKObjectType.quantityType(forIdentifier: $0) })
    }

    func requestAuthorization() async {
        guard isHealthDataAvailable else { return }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            isAuthorized = true
            await refresh()
            startObservers()
        } catch {
            isAuthorized = false
        }
    }

    // MARK: - Reading

    func refresh() async {
        await refreshLatestWeight()
        await refreshActiveEnergyToday()
    }

    private func refreshLatestWeight() async {
        guard let type = weightType else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let sample: HKQuantitySample? = await withCheckedContinuation { cont in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                cont.resume(returning: samples?.first as? HKQuantitySample)
            }
            store.execute(query)
        }
        if let sample {
            latestWeightKg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
        }
    }

    private func refreshActiveEnergyToday() async {
        guard let type = activeEnergyType else { return }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let total: Double? = await withCheckedContinuation { cont in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                cont.resume(returning: stats?.sumQuantity()?.doubleValue(for: .kilocalorie()))
            }
            store.execute(query)
        }
        if let total { activeEnergyTodayKcal = total }
    }

    // MARK: - Live updates

    private func startObservers() {
        guard !observersStarted else { return }
        observersStarted = true
        for type in [weightType, activeEnergyType].compactMap({ $0 }) {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, _ in
                Task { await self?.refresh() }
                completion()
            }
            store.execute(query)
        }
    }

    // MARK: - Writing nutrition

    /// Save a logged food entry's nutrition to Apple Health at its date.
    func saveNutrition(for entry: FoodEntry) {
        guard isHealthDataAvailable, isAuthorized else { return }
        var samples: [HKQuantitySample] = []

        func add(_ identifier: HKQuantityTypeIdentifier, _ unit: HKUnit, _ value: Double) {
            guard value > 0, let type = HKObjectType.quantityType(forIdentifier: identifier) else { return }
            let quantity = HKQuantity(unit: unit, doubleValue: value)
            samples.append(HKQuantitySample(type: type, quantity: quantity, start: entry.date, end: entry.date))
        }

        add(.dietaryEnergyConsumed, .kilocalorie(), entry.nutrients.calories)
        add(.dietaryProtein, .gram(), entry.nutrients.protein)
        add(.dietaryCarbohydrates, .gram(), entry.nutrients.carbs)
        add(.dietaryFatTotal, .gram(), entry.nutrients.fat)

        guard !samples.isEmpty else { return }
        store.save(samples) { _, _ in }
    }
}
