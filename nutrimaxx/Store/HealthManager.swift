import Foundation
import HealthKit

/// Wraps HealthKit: reads body + activity metrics (with live updates), and
/// writes logged nutrition tagged with our entry id so edits/deletes stay in sync.
@MainActor
final class HealthManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var latestWeightKg: Double?
    @Published var activeEnergyTodayKcal: Double?
    @Published var restingEnergyTodayKcal: Double?
    @Published var stepsToday: Double?
    @Published var waterTodayLiters: Double?

    private let store = HKHealthStore()
    private var observersStarted = false

    static let entryIDKey = "nutrimaxx.entryID"

    var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private func qty(_ id: HKQuantityTypeIdentifier) -> HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: id)
    }

    private var readIDs: [HKQuantityTypeIdentifier] {
        [.bodyMass, .activeEnergyBurned, .basalEnergyBurned, .stepCount, .dietaryWater,
         .dietaryEnergyConsumed, .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal]
    }
    private var shareIDs: [HKQuantityTypeIdentifier] {
        [.dietaryEnergyConsumed, .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal, .dietaryWater]
    }

    private var readTypes: Set<HKObjectType> { Set(readIDs.compactMap { qty($0) }) }
    private var shareTypes: Set<HKSampleType> { Set(shareIDs.compactMap { qty($0) }) }

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
        activeEnergyTodayKcal = await sumToday(.activeEnergyBurned, unit: .kilocalorie())
        restingEnergyTodayKcal = await sumToday(.basalEnergyBurned, unit: .kilocalorie())
        stepsToday = await sumToday(.stepCount, unit: .count())
        waterTodayLiters = await sumToday(.dietaryWater, unit: .liter())
    }

    private func refreshLatestWeight() async {
        guard let type = qty(.bodyMass) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let sample: HKQuantitySample? = await withCheckedContinuation { cont in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                cont.resume(returning: samples?.first as? HKQuantitySample)
            }
            store.execute(query)
        }
        if let sample { latestWeightKg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo)) }
    }

    private func sumToday(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        guard let type = qty(id) else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { cont in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                cont.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    /// Daily body-weight samples over the last `days` days, for the trend chart.
    func weightSeries(days: Int = 30) async -> [(date: Date, kg: Double)] {
        guard let type = qty(.bodyMass) else { return [] }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        let samples: [HKQuantitySample] = await withCheckedContinuation { cont in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                cont.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }
        return samples.map { ($0.endDate, $0.quantity.doubleValue(for: .gramUnit(with: .kilo))) }
    }

    // MARK: - Live updates

    private func startObservers() {
        guard !observersStarted else { return }
        observersStarted = true
        let ids: [HKQuantityTypeIdentifier] = [.bodyMass, .activeEnergyBurned, .basalEnergyBurned, .stepCount, .dietaryWater]
        for type in ids.compactMap({ qty($0) }) {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, _ in
                Task { await self?.refresh() }
                completion()
            }
            store.execute(query)
        }
    }

    // MARK: - Writing nutrition

    func saveNutrition(for entry: FoodEntry) {
        guard isHealthDataAvailable, isAuthorized else { return }
        let metadata = [Self.entryIDKey: entry.id.uuidString]
        var samples: [HKQuantitySample] = []

        func add(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit, _ value: Double) {
            guard value > 0, let type = qty(id) else { return }
            let quantity = HKQuantity(unit: unit, doubleValue: value)
            samples.append(HKQuantitySample(type: type, quantity: quantity, start: entry.date, end: entry.date, metadata: metadata))
        }
        add(.dietaryEnergyConsumed, .kilocalorie(), entry.nutrients.calories)
        add(.dietaryProtein, .gram(), entry.nutrients.protein)
        add(.dietaryCarbohydrates, .gram(), entry.nutrients.carbs)
        add(.dietaryFatTotal, .gram(), entry.nutrients.fat)

        guard !samples.isEmpty else { return }
        store.save(samples) { _, _ in }
    }

    /// Remove any Health samples previously written for this entry id.
    func deleteNutrition(entryID: UUID) {
        guard isHealthDataAvailable, isAuthorized else { return }
        let predicate = HKQuery.predicateForObjects(withMetadataKey: Self.entryIDKey, allowedValues: [entryID.uuidString])
        for type in [HKQuantityTypeIdentifier.dietaryEnergyConsumed, .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal].compactMap({ qty($0) }) {
            store.deleteObjects(of: type, predicate: predicate) { _, _, _ in }
        }
    }

    func updateNutrition(for entry: FoodEntry) {
        deleteNutrition(entryID: entry.id)
        // Give the deletes a moment before re-writing.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.saveNutrition(for: entry)
        }
    }

    /// Log a water amount (in liters) to Health at the current time.
    func addWater(liters: Double) {
        guard isHealthDataAvailable, isAuthorized, liters > 0, let type = qty(.dietaryWater) else { return }
        let quantity = HKQuantity(unit: .liter(), doubleValue: liters)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: Date(), end: Date())
        store.save(sample) { [weak self] _, _ in
            Task { await self?.refresh() }
        }
    }
}
