/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension Benchmark {
    /// Measures the total output size of a DocC archive.
    public struct ArchiveOutputSize: BenchmarkMetric {
        public static let identifier = "total-archive-output-size"
        public static let displayName = "Total DocC archive size"
        public var result: MetricValue?
        
        public init(archiveDirectory: URL) {
            self.result = MetricValue(directory: archiveDirectory)
        }
    }
    
    /// Measures the output size of the data subdirectory in a DocC archive.
    public struct DataDirectoryOutputSize: BenchmarkMetric {
        public static let identifier = "data-subdirectory-output-size"
        public static let displayName = "Data subdirectory size"
        public var result: MetricValue?
        
        public init(dataDirectory: URL) {
            self.result = MetricValue(directory: dataDirectory)
        }
    }
    
    /// Measures the output size of the index subdirectory in a DocC archive.
    public struct IndexDirectoryOutputSize: BenchmarkMetric {
        public static let identifier = "index-subdirectory-output-size"
        public static let displayName = "Index subdirectory size"
        public var result: MetricValue?
        
        public init(indexDirectory: URL) {
            self.result = MetricValue(directory: indexDirectory)
        }
    }
}

extension MetricValue {
    /// Creates a disk size metric for a given directory.
    ///
    /// This metric measures the real amount of bytes saved to disk
    /// in the given directory and not the disk space reserved for storing the
    /// corresponding files. This behavior helps produce real deltas between
    /// multiple benchmarks.
    init?(directory: URL) {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: .skipsHiddenFiles,
            errorHandler: nil
        ) else {
            return nil
        }
        
        var bytes: Int64 = 0
        for case let url as URL in enumerator {
            bytes += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        
        self = .bytesOnDisk(bytes)
    }
}
