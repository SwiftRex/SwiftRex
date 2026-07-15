// SPDX-License-Identifier: Apache-2.0

@testable import SwiftRex
import Testing

@Suite("Transceiver / Rig")
struct TransceiverRigTests {
    private func acceptTransceiver<T: Transceiver>(_: T.Type) {}
    private func acceptRig<R: Rig>(_: R.Type) {}

    // Compiling is the proof: the core types plug into the radio spine — anything with `(Action, State)`
    // is a `Transceiver`, and anything that also reaches the world (`+ Environment`) is a `Rig`.
    @Test func coreTypesConform() {
        acceptTransceiver(Store<Int, Int, Void>.self)      // StoreType: Transceiver
        acceptTransceiver(Reducer<Int, Int>.self)          // Reducer: Transceiver
        acceptTransceiver(Behavior<Int, Int, Void>.self)   // Rig refines Transceiver
        acceptRig(Behavior<Int, Int, Void>.self)           // Behavior: Rig
    }
}
