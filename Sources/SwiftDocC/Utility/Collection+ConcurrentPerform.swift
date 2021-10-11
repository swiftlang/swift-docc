/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

// Until we find a better way to manage memory on Linux we will disable
// concurrency in the Collection extensions in this file and have tests expect
// them to work serially on Linux. rdar://75794062

#if os(macOS) || os(iOS)
private let useConcurrentCollectionExtensions = true
#else
private let useConcurrentCollectionExtensions = false
#endif

extension Collection where Index == Int {

    /// Concurrently transforms the elements of a collection.
    /// - Parameters:
    ///   - batches: The number of batches to split the elements.
    ///   - block: A `(Element) -> Result` block that will be used to transform each of the collections elements concurrently.
    ///
    /// Use ``concurrentMap(batches:block)`` when you want to transform a collection concurrently and preserve the count and order of the elements.
    /// > Warning: As multiple copies of `block` are executed concurrently, mutating shared state outside the closure is not safe.
    func concurrentMap<Result>(
        batches: UInt = UInt(ProcessInfo.processInfo.processorCount * 4),
        block: (Element) -> Result) -> [Result] {
        
        // If concurrency is disabled fall back on `map`.
        guard useConcurrentCollectionExtensions else { return map(block) }
        
        guard !isEmpty else { return [] }
        precondition(batches > 0, "The number of concurrent batches should be greater than zero.")
        
        let batchElementCount = Int(Double(count) / Double(batches) + 1)
        let allResults = Synchronized<[Int: [Result]]>([:])
        
        // Concurrently run `block` over slices of the collection.
        DispatchQueue.concurrentPerform(iterations: Int(batches)) { batch in
            // Determine the start index and the elements count of each batch.
            let startOffset = batch * batchElementCount
            let batchCount = Swift.min(batchElementCount, count - startOffset)
            guard batchCount > 0 else { return }

            // Create a new array to collect results within this batch.
            var batchResults = Array<Result>()
            batchResults.reserveCapacity(batchCount)
            
            // Run serially `block` over the elements
            for offset in startOffset ..< startOffset + batchCount {
                batchResults.append(block(self[offset]))
            }
            
            // Add the batch results to a dictionary keyed by the batch number
            allResults.sync({ $0[batch] = batchResults })
        }
        
        // Stitch together the batch results in the correct order
        return allResults.sync({ allResults in
            // Sort the keys to preserve the original element order.
            return allResults.keys.sorted().reduce(into: [Result]()) { result, batchNr in
                result.append(contentsOf: allResults[batchNr]!)
            }
        })
    }

    /// Concurrently performs a block over the elements of the collection.
    /// - Parameters:
    ///   - batches: The number of batches to split the elements.
    ///   - block: A `(Element) -> Void` block that will be executed for each of the collections elements concurrently.
    /// > Note: Unlike `map` or similar functions, this function does not preserve the element order from the collection
    ///         to the order of elements in the results array.
    func concurrentPerform(
        batches: UInt = UInt(ProcessInfo.processInfo.processorCount * 4),
        block: (Element) -> Void) {

        // If concurrency is disabled fall back on `forEach`.
        guard useConcurrentCollectionExtensions else { return forEach(block) }

        let _ = concurrentPerform { element, _ in block(element) } as [Void]
    }
    
    /// Concurrently performs a block over the elements of the collection and collects any results.
    /// - Parameters:
    ///   - batches: The number of batches to split the elements.
    ///   - block: A `(Element, inout [Result]) -> Void` block that will be executed for each of the collections elements concurrently.
    ///
    /// The difference in behavior compared to ``concurrentMap(batches:block:)`` is that with this API you
    /// can freely mutate the returned results from each block. For example use `concurrentPerform(batches:block:)`
    /// to process a collection of inputs and add any encountered problems (if any) to the results to handle
    /// synchronously after the concurrent work is completed.
    ///
    /// > Warning: As multiple copies of `block` are executed concurrently, mutating shared state outside the closure is not safe.
    ///
    /// > Note: Mutating the results parameter of `block` from inside the block is safe as that parameter is
    ///         shared only between the blocks in a single batch which are executed serially.
    ///
    /// > Note: Unlike `map` or similar functions, this function does not preserve the element order from the collection
    ///         to the order of elements in the results array.
    func concurrentPerform<Result>(
        batches: UInt = UInt(ProcessInfo.processInfo.processorCount * 4),
        block: (Element, inout [Result]) -> Void) -> [Result] {
        
        // If concurrency is disabled fall back on `forEach`.
        guard useConcurrentCollectionExtensions else {
            var results = [Result]()
            forEach { block($0, &results) }
            return results
        }

        guard !isEmpty else { return [] }
        precondition(batches > 0, "The number of concurrent batches should be greater than zero.")
        
        let batchElementCount = Int(Double(count) / Double(batches) + 1)
        let allResults = Synchronized<[Result]>([])
        
        // Concurrently run `block` over slices of the collection.
        DispatchQueue.concurrentPerform(iterations: Int(batches)) { batch in
            // Determine the start index and the elements count of each batch.
            let startOffset = batch * batchElementCount
            let batchCount = Swift.min(batchElementCount, count - startOffset)
            guard batchCount > 0 else { return }

            // Create a new array to collect results within this batch.
            var batchResults = Array<Result>()
            batchResults.reserveCapacity(batchCount)
            
            // Run serially `block` over the elements
            for offset in startOffset ..< startOffset + batchCount {
                block(self[offset], &batchResults)
            }
            
            allResults.sync({ $0.append(contentsOf: batchResults) })
        }
        
        // Return the collected results from all batches.
        return allResults.sync({ $0 })
    }
}
