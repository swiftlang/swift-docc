/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
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

extension Collection where Index == Int, Self: SendableMetatype {

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
            var batchResults = [Result]()
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
            var batchResults = [Result]()
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

extension Collection {
    /// Concurrently performs work on slices of the collection's elements, combining the partial results into a final result.
    ///
    /// This method is intended as a building block that other higher-level `concurrent...` methods can be built upon.
    /// That said, calling code can opt to use this method directly as opposed to writing overly specific single-use helper methods.
    ///
    /// - Parameters:
    ///   - taskName: A human readable name of the tasks that the collection uses to perform this work.
    ///   - batchWork: The concurrent work to perform on each slice of the collection's elements.
    ///   - initialResult: The initial result to accumulate the partial results into.
    ///   - combineResults: A closure that updates the accumulated result with a partial result from performing the work over one slice of the collection's elements.
    /// - Returns: The final result of accumulating all partial results, out of order, into the initial result.
    func _concurrentPerform<Result, PartialResult>(
        taskName: String? = nil,
        batchWork: (consuming SubSequence) throws -> PartialResult,
        initialResult: Result,
        combineResults: (inout Result, consuming PartialResult) -> Void
    ) async throws -> Result {
        try await withoutActuallyEscaping(batchWork) { work in
            try await withoutActuallyEscaping(combineResults) { combineResults in
                try await withThrowingTaskGroup(of: PartialResult.self, returning: Result.self) { taskGroup in
                    var remaining = self[...]
                    
                    // Don't run more tasks in parallel than there are cores to run them
                    let maxParallelTasks: Int = ProcessInfo.processInfo.processorCount
                    // Finding the right number of tasks is a balancing act.
                    // If the tasks are too small, then there's increased overhead from scheduling a lot of tasks and accumulating their results.
                    // If the tasks are too large, then there's a risk that some tasks take longer to complete than others, increasing the amount of idle time.
                    //
                    // Here, we aim to schedule at most 10 tasks per core but create fewer tasks if the collection is fairly small to avoid some concurrent overhead.
                    // The table below shows the approximate number of tasks per CPU core and the number of elements per task, within parenthesis,
                    // for different collection sizes and number of CPU cores, given a minimum task size of 20 elements:
                    //
                    //               |     500    |    1000    |    2500    |    5000    |    10000    |    25000
                    //     ----------|------------|------------|------------|------------|-------------|-------------
                    //       8 cores |  ~3,2 (20) |  ~6,3 (20) |  ~9,8 (32) |  ~9,9 (63) |  ~9,9 (126) |  ~9,9 (313)
                    //      12 cores |  ~2,1 (20) |  ~4,2 (20) | ~10,0 (21) | ~10,0 (42) | ~10,0  (84) | ~10,0 (209)
                    //      16 cores |  ~1,6 (20) |  ~3,2 (20) |  ~7,9 (20) |  ~9,8 (32) |  ~9,9  (63) | ~10,0 (157)
                    //      32 cores |  ~0,8 (20) |  ~1,6 (20) |  ~4,0 (20) |  ~7,9 (20) |  ~9,8  (32) |  ~9,9  (79)
                    //
                    let numberOfElementsPerTask: Int = Swift.max(
                        Int(Double(remaining.count) / Double(maxParallelTasks * 10) + 1),
                        20 // (this is a completely arbitrary task size threshold)
                    )
                    
                    // Start the first round of work.
                    // If the collection is big, this will add one task per core.
                    // If the collection is small, this will only add a few tasks.
                    for _ in 0..<maxParallelTasks {
                        if !remaining.isEmpty {
                            let slice = remaining.prefix(numberOfElementsPerTask)
                            remaining = remaining.dropFirst(numberOfElementsPerTask)
                            
                            // Start work of one slice of the known pages
                            #if compiler(<6.2)
                            taskGroup.addTask {
                                return try work(slice)
                            }
                            #else
                            taskGroup.addTask(name: taskName) {
                                return try work(slice)
                            }
                            #endif
                        }
                    }
                    
                    var result = initialResult
                    
                    for try await partialResult in taskGroup {
                        // Check if the larger task group has been cancelled and if so, avoid doing any further work.
                        try Task.checkCancellation()
                        
                        combineResults(&result, partialResult)
                        
                        // Now that one task has finished, and one core is available for work,
                        // see if we have more slices to process and add one more task to process that slice.
                        if !remaining.isEmpty {
                            let slice = remaining.prefix(numberOfElementsPerTask)
                            remaining = remaining.dropFirst(numberOfElementsPerTask)
                            
                            // Start work of one slice of the known pages
                            #if compiler(<6.2)
                            taskGroup.addTask {
                                return try work(slice)
                            }
                            #else
                            taskGroup.addTask(name: taskName) {
                                return try work(slice)
                            }
                            #endif
                        }
                    }
                    
                    return result
                }
            }
        }
    }
}
