import Foundation
import HealthKit

/// Wraps HealthKit access for weight and active energy. Falls back to the
/// reference values from the screenshots when HealthKit has no data (e.g. a
/// fresh Simulator), so the UI always shows something sensible.
@MainActor
final class HealthManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var latestWeightKg: Double? = 72.5
    @Published var activeEnergyTodayKcal: Double? = 78

    private let store = HKHealthStore()

    var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        if let weight = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(weight)
        }
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energy)
        }
        return types
    }

    func requestAuthorization() async {
        guard isHealthDataAvailable else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            await refresh()
        } catch {
            isAuthorized = false
        }
    }

    func refresh() async {
        await refreshLatestWeight()
        await refreshActiveEnergyToday()
    }

    private func refreshLatestWeight() async {
        guard let type = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return }
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
        guard let type = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
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
}
