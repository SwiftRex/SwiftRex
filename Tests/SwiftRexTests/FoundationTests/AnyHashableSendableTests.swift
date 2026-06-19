import Foundation
@testable import SwiftRex
import Testing

private enum FeatureAID: Hashable { case fetch, search }
private enum FeatureBID: Hashable { case fetch, search }

@Suite("AnyHashableSendable")
struct AnyHashableSendableTests {
    @Test("Equal values of the same type are equal")
    func sameTypeEquality() {
        let stringIds = ["fetch", "fetch"].map(AnyHashableSendable.init)
        let intIds = [42, 42].map(AnyHashableSendable.init)
        let enumIds = [FeatureAID.fetch, FeatureAID.fetch].map(AnyHashableSendable.init)
        #expect(stringIds[0] == stringIds[1])
        #expect(intIds[0] == intIds[1])
        #expect(enumIds[0] == enumIds[1])
    }

    @Test("Different values of the same type are not equal")
    func sameTypeInequality() {
        #expect(AnyHashableSendable("fetch") != AnyHashableSendable("search"))
        #expect(AnyHashableSendable(FeatureAID.fetch) != AnyHashableSendable(FeatureAID.search))
    }

    @Test("Numeric and Bool ids never unify across types (no Foundation bridging)")
    func crossTypeNumericIdsAreDistinct() {
        #expect(AnyHashableSendable(1) != AnyHashableSendable(1.0))
        #expect(AnyHashableSendable(1) != AnyHashableSendable(true))
        #expect(AnyHashableSendable(1.0) != AnyHashableSendable(true))
        #expect(AnyHashableSendable(Int(1)) != AnyHashableSendable(Int8(1)))
    }

    @Test("Same-shaped enums from different scopes are distinct ids")
    func distinctEnumTypesNeverCollide() {
        #expect(AnyHashableSendable(FeatureAID.fetch) != AnyHashableSendable(FeatureBID.fetch))
    }

    @Test("Works as a dictionary key")
    func dictionaryKeying() {
        var registry: [AnyHashableSendable: Int] = [:]
        registry[AnyHashableSendable("fetch")] = 1
        registry[AnyHashableSendable(FeatureAID.fetch)] = 2
        registry[AnyHashableSendable(FeatureBID.fetch)] = 3

        #expect(registry.count == 3)
        #expect(registry[AnyHashableSendable("fetch")] == 1)
        #expect(registry[AnyHashableSendable(FeatureAID.fetch)] == 2)
        #expect(registry[AnyHashableSendable(FeatureBID.fetch)] == 3)
        #expect(registry[AnyHashableSendable("missing")] == nil)
    }

    @Test("Equal values hash equally")
    func hashingConsistency() {
        let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let ids = [uuid, uuid].map(AnyHashableSendable.init)
        #expect(ids[0].hashValue == ids[1].hashValue)
    }
}

@Suite("EffectScheduling id factories")
struct EffectSchedulingIdFactoryTests {
    @Test("String id round-trips through replacing")
    func replacingStringId() {
        let scheduling = EffectScheduling.replacing(id: "fetch")
        #expect(scheduling.id == AnyHashableSendable("fetch"))
        #expect(scheduling.exclusive)
    }

    @Test("keyed sets the id with no coalesce, delay, or replacement")
    func keyedIdHasNoOtherKnobs() {
        let scheduling = EffectScheduling.keyed(id: "socket")
        #expect(scheduling.id == AnyHashableSendable("socket"))
        #expect(scheduling.coalesce == nil)
        #expect(scheduling.delay == nil)
        #expect(!scheduling.exclusive)
        #expect(!scheduling.cancelsOnly)
    }

    @Test("UUID id round-trips through debounce")
    func debounceUUIDId() {
        let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!
        let scheduling = EffectScheduling.debounce(id: uuid, delay: .milliseconds(300))
        #expect(scheduling.id == AnyHashableSendable(uuid))
        #expect(scheduling.coalesce == .debounce(.milliseconds(300)))
    }

    @Test("Enum id round-trips through throttle")
    func throttleEnumId() {
        let scheduling = EffectScheduling.throttle(id: FeatureAID.search, interval: .seconds(1))
        #expect(scheduling.id == AnyHashableSendable(FeatureAID.search))
        #expect(scheduling.coalesce == .throttle(.seconds(1)))
    }

    @Test("Enum id round-trips through cancelInFlight, distinct across enum types")
    func cancelInFlightEnumId() {
        let scheduling = EffectScheduling.cancelInFlight(id: FeatureAID.fetch)
        #expect(scheduling.cancelsOnly)
        #expect(scheduling.id == AnyHashableSendable(FeatureAID.fetch))
        #expect(scheduling.id != AnyHashableSendable(FeatureBID.fetch))
    }

    @Test("Pre-wrapped id is accepted unambiguously")
    func preWrappedId() {
        #expect(EffectScheduling.replacing(id: AnyHashableSendable("x")).id == AnyHashableSendable("x"))
    }
}
