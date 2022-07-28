/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension Benchmark {
    /// A hash metric produced off the given documentation context.
    ///
    /// Use this metric to verify that your code changes
    /// did not affect the topic graph of the compiled documentation.
    public class TopicGraphHash: BenchmarkMetric {
        public static let identifier = "topic-graph-hash"
        public static let displayName = "Topic Graph Checksum"
        
        /// Creates a new metric and stores the checksum of the given documentation context topic graph.
        /// - Parameter context: A documentation context containing a topic graph.
        public init(context: DocumentationContext) {
            guard let checksum = context.dumpGraph().data(using: .utf8).map(Checksum.md5) else { return }
            result = .checksum(checksum)
        }
        
        public var result: MetricValue?
    }
}
