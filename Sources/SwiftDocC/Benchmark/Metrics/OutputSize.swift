/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension Benchmark {
    /// A disk size metric for a given directory.
    ///
    /// - Note: This metric measures the real amount of bytes saved to disk
    /// in the given directory and not the disk space reserved for storing the
    /// corresponding files. This behavior helps produce real deltas between
    /// multiple benchmarks.
    public class OutputSize: BenchmarkMetric {
        public static let identifier = "output-size"
        public static let displayName = "Compiled output size (bytes)"
        
        public var result: MetricValue? = nil
        
        /// Logs the recursive file size of the given directory contents.
        public init(dataURL: URL) {
            guard let enumerator = FileManager.default.enumerator(
                at: dataURL,
                includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
                options: .skipsHiddenFiles,
                errorHandler: nil) else { return }
            
            var bytes: Int64 = 0
            for case let url as URL in enumerator {
                bytes += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
            }
            
            result = .integer(bytes)
        }
    }
}
