/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension Benchmark {
    /// A duration metric in milliseconds.
    ///
    /// Use this metric to measure how long a given named task takes.
    public class Duration: DynamicallyIdentifiableMetric, BenchmarkBlockMetric {
        public static let identifier = "duration"
        public static let displayName = "Duration for an operation"

        public var identifier: String { "duration-\(self.id)" }
        public var displayName: String { "Duration for '\(self.id)'" }

        public var result: MetricValue?

        private let id: String
        private var startTime = 0.0
        
        /// Creates a new instance with the given name.
        ///
        /// Since this metric can be used multiple times to measure
        /// the duration of various tasks, `init(id:)` requires you
        /// to provide an id for the task being measured. The `id`
        /// parameter will be appended to the metric identifier in the
        /// exported benchmark report to keep the various durations
        /// distinguishable like so: `duration-myTask1`, `duration-my-other-task`, etc.
        public init(id: String) {
            self.id = id
        }
        
        public func begin() {
            startTime = ProcessInfo.processInfo.systemUptime
        }
        
        public func end() {
            // We need to multiply the resulting duration by 1000 to store
            // a value in milliseconds as an integer to avoid floating point
            // encoding artifacts.
            result = .duration((ProcessInfo.processInfo.systemUptime - startTime))
        }
        
        /// Convenience init to use when the duration is tracked elsewhere.
        /// - Parameter id: The id for the metric.
        /// - Parameter duration: The duration value in seconds to be logged.
        public init(id: String, duration: TimeInterval) {
            self.id = id
            result = .duration(duration)
        }
    }
}
