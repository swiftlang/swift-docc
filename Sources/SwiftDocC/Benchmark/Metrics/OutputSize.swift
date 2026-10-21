/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation

extension Benchmark {
    /// Measures the total output size of a DocC archive.
    public struct ArchiveOutputSize: BenchmarkMetric {
        public static let identifier = "total-archive-output-size"
        public static let displayName = "Total DocC archive size"
        public var result: MetricValue?
        
        package init(archiveDirectory: URL, fileManager: some FileManagerProtocol = FileManager.default) {
            self.result = MetricValue(directory: archiveDirectory,
                                      fileManager: fileManager)
        }

        public init(archiveDirectory: URL) {
            self.init(archiveDirectory: archiveDirectory, fileManager: FileManager.default)
        }
    }
    
    /// Measures the output size of the data subdirectory in a DocC archive.
    public struct DataDirectoryOutputSize: BenchmarkMetric {
        public static let identifier = "data-subdirectory-output-size"
        public static let displayName = "Data subdirectory size"
        public var result: MetricValue?
        
        package init(dataDirectory: URL, fileManager: some FileManagerProtocol = FileManager.default) {
            self.result = MetricValue(directory: dataDirectory,
                                      fileManager: fileManager)
        }

        public init(dataDirectory: URL) {
            self.init(dataDirectory: dataDirectory, fileManager: FileManager.default)
        }
    }
    
    /// Measures the output size of the index subdirectory in a DocC archive.
    public struct IndexDirectoryOutputSize: BenchmarkMetric {
        public static let identifier = "index-subdirectory-output-size"
        public static let displayName = "Index subdirectory size"
        public var result: MetricValue?
        
        package init(indexDirectory: URL, fileManager: some FileManagerProtocol = FileManager.default) {
            self.result = MetricValue(directory: indexDirectory,
                                      fileManager: fileManager)
        }

        public init(indexDirectory: URL) {
            self.init(indexDirectory: indexDirectory, fileManager: FileManager.default)
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
    init?(directory: URL, fileManager: some FileManagerProtocol) {
        do {
            let bytes = try fileManager.sizeOfDirectory(
                at: directory,
                options: [.skipsHiddenFiles]
            )
            self = .bytesOnDisk(bytes)
        } catch {
            return nil
        }
    }
}
