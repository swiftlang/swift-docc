/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension Benchmark {
    /// A hash metric produced off the externally resolved links and symbols.
    ///
    /// Use this metric to verify that your code changes
    /// did not affect external resolving.
    public class ExternalTopicsHash: BenchmarkMetric {
        public static let identifier = "external-topics-hash"
        public static let displayName = "External Topics Checksum"
        
        /// Creates a new metric and stores the checksum of the given documentation context external topics.
        /// - Parameter context: A documentation context.
        public init(context: DocumentationContext) {
            // If there are no externally resolved topics return quickly.
            guard !context.externallyResolvedLinks.isEmpty || !context.externallyResolvedSymbols.isEmpty else {
                return
            }
            
            // Make a flat string of all successfully resolved external topics.
            // Note: We have to sort the URLs to produce a stable checksum.
            let sourceString = context.externallyResolvedLinks.values.compactMap({
                switch $0 {
                case .success(let resolved):
                    return resolved.absoluteString
                case .failure(_, _):
                    return nil
                }
            }).sorted().joined()
                + context.externallyResolvedSymbols.map({ $0.absoluteString }).sorted().joined()

            result = .checksum(Checksum.md5(of: Data(sourceString.utf8)))
        }
        
        public var result: MetricValue?
    }
}
