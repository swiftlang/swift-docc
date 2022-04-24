/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension Benchmark {
    /// A anchor sections hash metric produced off the given documentation context.
    ///
    /// Use this metric to verify that your code changes
    /// did not affect the anchor sections in the compiled documentation.
    public class TopicAnchorHash: BenchmarkMetric {
        public static let identifier = "topic-anchor-hash"
        public static let displayName = "Topic Anchor Checksum"
        
        /// Creates a new metric and stores the checksum of the given documentation context anchor sections.
        /// - Parameter context: A documentation context containing a topic graph.
        public init(context: DocumentationContext) {
            guard let checksum = context.nodeAnchorSections.keys
                .sorted(by: { lhs, rhs -> Bool in
                    return lhs.absoluteString < rhs.absoluteString
                })
                // It's ok to force unwrap we enumerate only valid keys above.
                .map({ "\(context.nodeAnchorSections[$0]!.reference.absoluteString):\(context.nodeAnchorSections[$0]!.title)\n" })
                .joined()
                .data(using: .utf8).map(Checksum.md5) else { return }
            
            result = .checksum(checksum)
        }
        
        public var result: MetricValue?
    }
}
