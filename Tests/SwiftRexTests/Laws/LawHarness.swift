// SPDX-License-Identifier: Apache-2.0

import DataStructure
import Testing

// Property-based law harness built on FP's `Gen`. Each `forAll` overload threads one seeded
// `SplitMix64` through all of its generators and the whole sample run, so a failure is fully
// reproducible: rerun with the same `seed` to replay the exact inputs.

/// Default seed for the law suites. Override per-call to reproduce or vary a run.
let lawSeed: UInt64 = 0xA11C_E5_FACE

/// Records a failure on the first sample that violates `property`, naming the sample index and
/// seed so the case can be replayed.
private func check(
    _ count: Int,
    seed: UInt64,
    _ sourceLocation: SourceLocation,
    _ draw: (inout SplitMix64) -> Bool
) {
    var rng = SplitMix64(seed: seed)
    for index in 0..<count where !draw(&rng) {
        Issue.record("law violated at sample \(index) of \(count) (seed: \(seed))", sourceLocation: sourceLocation)
        return
    }
}

func forAll<A>(
    _ ga: Gen<SplitMix64, A>,
    count: Int = 300,
    seed: UInt64 = lawSeed,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ property: (A) -> Bool
) {
    check(count, seed: seed, sourceLocation) { property(ga(&$0)) }
}

func forAll<A, B>(
    _ ga: Gen<SplitMix64, A>,
    _ gb: Gen<SplitMix64, B>,
    count: Int = 300,
    seed: UInt64 = lawSeed,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ property: (A, B) -> Bool
) {
    check(count, seed: seed, sourceLocation) { property(ga(&$0), gb(&$0)) }
}

func forAll<A, B, C>(
    _ ga: Gen<SplitMix64, A>,
    _ gb: Gen<SplitMix64, B>,
    _ gc: Gen<SplitMix64, C>,
    count: Int = 300,
    seed: UInt64 = lawSeed,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ property: (A, B, C) -> Bool
) {
    check(count, seed: seed, sourceLocation) { property(ga(&$0), gb(&$0), gc(&$0)) }
}

func forAll<A, B, C, D>(
    _ ga: Gen<SplitMix64, A>,
    _ gb: Gen<SplitMix64, B>,
    _ gc: Gen<SplitMix64, C>,
    _ gd: Gen<SplitMix64, D>,
    count: Int = 300,
    seed: UInt64 = lawSeed,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ property: (A, B, C, D) -> Bool
) {
    check(count, seed: seed, sourceLocation) { property(ga(&$0), gb(&$0), gc(&$0), gd(&$0)) }
}

func forAll<A, B, C, D, E>(
    _ ga: Gen<SplitMix64, A>,
    _ gb: Gen<SplitMix64, B>,
    _ gc: Gen<SplitMix64, C>,
    _ gd: Gen<SplitMix64, D>,
    _ ge: Gen<SplitMix64, E>,
    count: Int = 300,
    seed: UInt64 = lawSeed,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ property: (A, B, C, D, E) -> Bool
) {
    check(count, seed: seed, sourceLocation) { property(ga(&$0), gb(&$0), gc(&$0), gd(&$0), ge(&$0)) }
}
