/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

#if !os(Linux) && !os(Android)
import Darwin

/// A throttle object to filter events that come too fast.
fileprivate var throttle = Throttle(interval: .seconds(1))

/// Monitors a directory subtree for file changes.
class DirectoryMonitor {
    
    enum Error: DescribedError {
        /// The Darwin `errno` code for too many open files.
        static let tooManyOpenFilesErrorCode = 24
        
        case urlIsNotDirectory(URL)
        case openFileHandleFailed(URL, code: Int32)
        case attributesNotAccessible(URL)
        case contentsEnumerationFailed(URL)
        case reachedOpenFileLimit(Int)
        
        var errorDescription: String {
            switch self {
            case .urlIsNotDirectory(let url): return "\(url.path) is not a directory"
            case .openFileHandleFailed(let url, let code): return "Failed to open file descriptor for \(url.path) with error code \(code)"
            case .attributesNotAccessible(let url): return "Could not read attributes of \(url.path)"
            case .contentsEnumerationFailed(let url): return "Could not enumerate the contnents of \(url.path)"
            case .reachedOpenFileLimit(let fileCount):
                return """
                Watching the source bundle failed because it contains \(fileCount) files which is
                more than your shell session limit for maximum amount of open files.

                Verify your current session limit by running 'ulimit -n'.

                To preview your source bundle, change your shell session's open file limit
                by running 'ulimit -n COUNT' where COUNT is the new limit
                that is higher than the amount of files in your source bundle and adding
                some buffer for system processes that also need to open files.
                """
            }
        }
    }

    /// A handler to call when a file change has been detected.
    /// - parameter: The root folder URL the monitor is observing.
    /// - parameter: A folder URL where the change did occur.
    typealias ChangeHandler = (URL, URL) -> Void
    
    /// An observed directory structure including the file handler and dispatch source.
    private struct WatchedDirectory {
        let url: URL
        let fileDescriptor: Int32
        let sources: [DispatchSourceFileSystemObject]
    }
    
    /// A list of the directories that the monitor observes for changes.
    private var watchedDirectories = [WatchedDirectory]()
    private let monitorQueue = DispatchQueue(label: "directoryMonitor", qos: .unspecified, attributes: .concurrent) 

    let root: URL
    private let changeHandler: ChangeHandler
    
    var didReloadWatchedDirectoryTree: ((URL?) -> Void)?
    
    private var lastChecksum = ""
    
    /// Returns a hash checksum of the recursive listing of the monitored folder (including recursive modification times).
    private func watchedURLChecksum() throws -> (checksum: String, count: Int) {
        let fileManager = FileManager()
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .contentModificationDateKey]
        guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles]) else {
            throw Error.contentsEnumerationFailed(root)
        }

        var files = ""
        var watchedFileCount = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                let modificationDate = resourceValues.contentModificationDate,
                let isDirectory = resourceValues.isDirectory else {
                
                throw Error.attributesNotAccessible(fileURL)
            }
            
            watchedFileCount += 1
            
            // Don't include directory names in the checksum since we're interested only in content changes
            guard !isDirectory else {
                continue
            }
            
            files += "\(fileURL.path) \(modificationDate.timeIntervalSinceReferenceDate)\n"
        }
        return (Checksum.md5(of: Data(files.utf8)), watchedFileCount)
    }
    
    /// Creates a new monitor observing `root` for changes.
    /// - parameter root: The root directory that you monitor for changes.
    /// - parameter changeHandler: A handler to invoke when changes are detected. 
    init(root: URL, changeHandler: @escaping ChangeHandler) throws {
        var isDirectory = ObjCBool(booleanLiteral: false)
        FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory)
        guard isDirectory.boolValue else {
            throw Error.urlIsNotDirectory(root)
        }
        
        self.root = root.resolvingSymlinksInPath().standardized
        self.changeHandler = changeHandler
    }
    
    /// Returns a list of directories found under the given URL parameter. 
    /// In case the parameter is a file path the method returns an empty list. 
    private func allDirectories(in url: URL) throws -> [(directory: URL, files: [URL])] {
        let contents = Set<URL>(try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles))
        let childrenHere = contents.filter { url in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
        let files = Array(contents.subtracting(childrenHere))
        
        return try [(directory: url, files: files)] 
            + childrenHere.flatMap { try allDirectories(in: $0) }
    }
    
    private func didChange(url: URL) {
        changeHandler(root, url)
    }

    /// A flag to keep track if the tree should be reloaded.
    /// 
    /// It's needed because a throttled sequence of quick changes might be:
    /// ```none
    /// [file change], [directory change], [file change]
    /// ```
    /// and we keep track via `shouldReloadDirectoryTree` if there was a directory level change
    /// in the sequence and therefore when the last event triggers the event handler we
    /// should reload the directory tree.
    private let shouldReloadDirectoryTree = Synchronized(false)

    /// Starts monitoring the given URL for changes and returns the dispatch source object for this operation.
    private func watch(url: URL, for events: DispatchSource.FileSystemEvent, on queue: DispatchQueue) throws -> (descriptor: Int32, source: DispatchSourceFileSystemObject) {
        let fileDescriptor = open(url.path, O_EVTONLY)
        if fileDescriptor == -1 {
            throw Error.openFileHandleFailed(url, code: Darwin.errno)
        }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: events, queue: queue)
        
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            // Throttle multiple events in quick succession.
            throttle.schedule {
                self.shouldReloadDirectoryTree.sync { shouldReload in
                    shouldReload = shouldReload || FileManager.default.directoryExists(atPath: url.path)
                }
                
                // If the observed directory has been deleted stop the monitor.
                guard FileManager.default.directoryExists(atPath: self.root.path) else {
                    return self.stop()
                }
                
                // Check the root directory contents' checksum before calling `didChange(url:)`
                // to avoid reacting to changes in hidden files which are ignored by the checksum function.
                guard let newChecksum = try? self.watchedURLChecksum().checksum,
                    self.lastChecksum != newChecksum else { return }
                self.lastChecksum = newChecksum
                
                self.didChange(url: url)
                
                // Reload the content recursively, if a directory was modified. (No need for single file changes)
                if self.shouldReloadDirectoryTree.sync({ $0 }) {
                    do {
                        try self.restart()
                        self.shouldReloadDirectoryTree.sync { shouldReload in
                            shouldReload = false
                        }
                        self.didReloadWatchedDirectoryTree?(url)
                    } catch {
                        var stderr = LogHandle.standardError
                        print("Unexpected error while monitoring \(self.root.path). Monitoring functionality is stopped.", to: &stderr)
                    }
                }
            }
        }
        source.setCancelHandler {
            close(fileDescriptor)
        }
        source.resume()
        
        return (descriptor: fileDescriptor, source: source)
    }

    /// Provided a URL and a monitor queue, returns a `WatchedDirectory` with event handling hooked up.
    private func watchedDirectory(at url: URL, files: [URL], on queue: DispatchQueue) throws -> WatchedDirectory {
        let watched = try watch(url: url, for: .all, on: queue)
        return try WatchedDirectory(url: url, 
            fileDescriptor: watched.descriptor, 
            sources: [watched.source] + files.map { try watch(url: $0, for: .write, on: queue).source } )
    }
    
    /// Start monitoring the root directory and its contents.
    func start() throws {
        let watchedFiles = try watchedURLChecksum()
        lastChecksum = watchedFiles.checksum
        
        do {
            watchedDirectories = try allDirectories(in: root)
                .map { return try watchedDirectory(at: $0.directory, files: $0.files, on: monitorQueue) }
        } catch Error.openFileHandleFailed(_, let errorCode) where errorCode == Error.tooManyOpenFilesErrorCode {
            // In case we've reached the file descriptor limit throw a detailed user error
            // with recovery instructions.
            throw Error.reachedOpenFileLimit(watchedFiles.count)
        }
    }
    
    func restart() throws {
        stop()
        try start()
    }
    
    /// Stop monitoring.
    func stop() {
        for directory in watchedDirectories {
            for source in directory.sources {
                source.cancel()
            }
        }
        watchedDirectories = []
    }
    
    deinit {
        stop()
    }
}

#endif
