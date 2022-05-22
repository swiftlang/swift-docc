/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocCUtilities
@testable import SwiftDocC
import SwiftDocCTestUtilities

/// A Data provider and file manager that accepts pre-built documentation bundles with files on the local filesystem.
///
/// `TestFileSystem` is a file manager that keeps a directory structure in memory including the file data
/// for fast access without hitting the disk. When you create an instance pass all folders to the initializer like so:
/// ```swift
/// let bundle = Folder(name: "unit-test.docc", content: [
///   ... files ...
/// ])
///
/// let testDataProvider = try TestFileSystem(
///   folders: [bundle, Folder.emptyHTMLTemplateDirectory]
/// )
/// ```
/// This will create or copy from disk the `folders` list and you can use the data provider
/// as a `FileManagerProtocol` and `DocumentationWorkspaceDataProvider`.
///
/// ## Expectations
/// This is a simplistic file system implementation aiming to satisfy our current unit test needs.
/// Care was taken that it mimics real file system behavior but if discrepancies are found while adding new tests
/// we will have to make adjustments.
///
/// Aspects of the current implementation worth noting:
/// 1. The in-memory file system is case sensitive (much like Linux)
/// 2. No support for file links
/// 3. No support for relative paths or traversing the tree upwards (e.g. "/root/nested/../other" will not resolve)
///
/// - Note: This class is thread-safe by using a naive locking for each accesss to the files dictionary.
/// - Warning: Use this type for unit testing.
class TestFileSystem: FileManagerProtocol, DocumentationWorkspaceDataProvider {
    let currentDirectoryPath = "/"
    
    var identifier: String = UUID().uuidString
    
    private var _bundles = [DocumentationBundle]()
    public func bundles(options: BundleDiscoveryOptions) throws -> [DocumentationBundle] {
        // Ignore the bundle discovery options, these test bundles are already built.
        return _bundles
    }
    
    /// Thread safe access to the file system.
    private var filesLock = NSRecursiveLock()
    
    /// A plain index of paths and their contents.
    var files = [String: Data]()
    
    /// Set to `true` to disable write operations for folders and files.
    /// For example use this for large conversions when the output is not of interest.
    var disableWriting = false
    
    /// A data fixture to use in the `files` index to mark folders.
    static let folderFixtureData = "Folder".data(using: .utf8)!
    
    convenience init(folders: [Folder]) throws {
        self.init()
        
        // Default system paths
        files["/"] = Self.folderFixtureData
 
        // Import given folders
        try updateDocumentationBundles(withFolders: folders)
    }
    
    public func updateDocumentationBundles(withFolders folders: [Folder]) throws {
        _bundles.removeAll()
        
        for folder in folders {
            let files = try addFolder(folder)
            if let info = folder.recursiveContent.mapFirst(where: { $0 as? InfoPlist }) {
                let files = files.filter({ $0.hasPrefix(folder.absoluteURL.path) }).compactMap({ URL(string: $0) })

                let markupFiles = files.filter({ DocumentationBundleFileTypes.isMarkupFile($0) })
                let miscFiles = files.filter({ !DocumentationBundleFileTypes.isMarkupFile($0) })
                let graphs = files.filter({ DocumentationBundleFileTypes.isSymbolGraphFile($0) })
                let customHeader = files.first(where: { DocumentationBundleFileTypes.isCustomHeader($0) })
                let customFooter = files.first(where: { DocumentationBundleFileTypes.isCustomFooter($0) })
                
                let bundle = DocumentationBundle(
                    info: DocumentationBundle.Info(
                        displayName: info.content.displayName,
                        identifier: info.content.identifier,
                        version: info.content.versionString
                    ),
                    symbolGraphURLs: graphs,
                    markupURLs: markupFiles,
                    miscResourceURLs: miscFiles,
                    customHeader: customHeader,
                    customFooter: customFooter
                )
                _bundles.append(bundle)
            }
        }
    }

    func contentsOfURL(_ url: URL) throws -> Data {
        filesLock.lock()
        defer { filesLock.unlock() }

        guard let file = files[url.path] else {
            throw Errors.invalidPath(url.path)
        }
        return file
    }
    
    func filesIn(folder: Folder, at: URL) throws -> [String: Data] {
        filesLock.lock()
        defer { filesLock.unlock() }

        var result = [String: Data]()
        for file in folder.content {
            switch file {
                case let folder as Folder:
                    result[at.appendingPathComponent(folder.name).path] = Self.folderFixtureData
                    result.merge(try filesIn(folder: folder, at: at.appendingPathComponent(folder.name)), uniquingKeysWith: +)
                case let file as File & DataRepresentable:
                    result[at.appendingPathComponent(file.name).path] = try file.data()
                    if let copy = file as? CopyOfFile {
                        result[copy.original.path] = try file.data()
                    }
                default: break
            }
        }
        return result
    }
    
    @discardableResult
    func addFolder(_ folder: Folder) throws -> [String] {
        guard !disableWriting else { return [] }
        
        filesLock.lock()
        defer { filesLock.unlock() }

        let rootURL = URL(fileURLWithPath: "/\(folder.name)")
        files[rootURL.path] = Self.folderFixtureData
        let fileList = try filesIn(folder: folder, at: rootURL)
        files.merge(fileList, uniquingKeysWith: +)
        return Array(fileList.keys)
    }
    
    func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
        filesLock.lock()
        defer { filesLock.unlock() }
        
        guard let data = files[path] else {
            isDirectory?.initialize(to: ObjCBool(false))
            return false
        }
        
        isDirectory?.initialize(to: data == Self.folderFixtureData ? ObjCBool(true) : ObjCBool(false))
        return true
    }
    
    func fileExists(atPath path: String) -> Bool {
        filesLock.lock()
        defer { filesLock.unlock() }

        return files.keys.contains(path)
    }
    
    func copyItem(at srcURL: URL, to dstURL: URL) throws {
        guard !disableWriting else { return }
        
        filesLock.lock()
        defer { filesLock.unlock() }

        let srcPath = srcURL.path
        let dstPath = dstURL.path
        
        files[dstPath] = files[srcPath]
        for (path, data) in files where path.hasPrefix(srcPath) {
            files[path.replacingOccurrences(of: srcPath, with: dstPath)] = data
        }
    }
    
    func moveItem(at srcURL: URL, to dstURL: URL) throws {
        guard !disableWriting else { return }
        
        filesLock.lock()
        defer { filesLock.unlock() }

        let srcPath = srcURL.path

        try copyItem(at: srcURL, to: dstURL)
        files.removeValue(forKey: srcPath)
        
        for (path, _) in files where path.hasPrefix(srcPath) {
            files.removeValue(forKey: path)
        }
    }
    
    func createDirectory(atPath path: String, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]? = nil) throws {
        guard !disableWriting else { return }
        
        filesLock.lock()
        defer { filesLock.unlock() }

        guard let target = URL(string: path) else {
            throw Errors.invalidPath(path)
        }
        
        let parent = target.deletingLastPathComponent()
        
        if parent.pathComponents.count > 1 {
            // If it's not the root folder, check if parents exist
            if createIntermediates == false {
                guard files.keys.contains(parent.path) else {
                    throw Errors.invalidPath(path)
                }
            } else {
                // Create missing parent directories
                try createDirectory(atPath: parent.path, withIntermediateDirectories: true)
            }
        }
        
        files[path] = Self.folderFixtureData
    }
    
    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]? = nil) throws {
        guard !disableWriting else { return }
        
        filesLock.lock()
        defer { filesLock.unlock() }

        try createDirectory(atPath: url.path, withIntermediateDirectories: createIntermediates)
    }
    
    func contentsEqual(atPath path1: String, andPath path2: String) -> Bool {
        filesLock.lock()
        defer { filesLock.unlock() }

        return files[path1] == files[path2]
    }
    
    func removeItem(at: URL) throws {
        guard !disableWriting else { return }
        
        filesLock.lock()
        defer { filesLock.unlock() }

        files.removeValue(forKey: at.path)
        for (path, _) in files where path.hasPrefix(at.path) {
            files.removeValue(forKey: path)
        }
    }
    
    func createFile(at: URL, contents: Data) throws {
        filesLock.lock()
        defer { filesLock.unlock() }

        guard let fileURL = URL(string: at.path),
              files.keys.contains(fileURL.deletingLastPathComponent().path) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError, userInfo: [NSFilePathErrorKey: at.path])
        }
        
        if !disableWriting {
            files[at.path] = contents
        }
    }
    
    func createFile(at url: URL, contents: Data, options: NSData.WritingOptions?) throws {
        try createFile(at: url, contents: contents)
    }
    
    func contents(atPath: String) -> Data? {
        filesLock.lock()
        defer { filesLock.unlock() }

        return files[atPath]
    }
    
    func contentsOfDirectory(atPath path: String) throws -> [String] {
        filesLock.lock()
        defer { filesLock.unlock() }
        
        var results = Set<String>()
        
        let paths = files.keys.filter { $0.hasPrefix(path) }
        for p in paths {
            let endOfPath = String(p.dropFirst(path.count))
            guard !endOfPath.isEmpty else { continue }
            let pathParts = endOfPath.components(separatedBy: "/")
            if pathParts.count == 1 {
                results.insert(pathParts[0])
            }
        }
        return Array(results)
    }



    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions) throws -> [URL] {

        if let keys = keys {
            XCTAssertTrue(
                keys.isEmpty,
                "includingPropertiesForKeys is not implemented in contentsOfDirectory in TestFileSystem"
            )
        }
        
        if mask != .skipsHiddenFiles && mask.isEmpty {
            XCTFail("The given directory enumeration option(s) have not been implemented in the test file system: \(mask)")
        }

        let skipHiddenFiles = mask == .skipsHiddenFiles
        let contents = try contentsOfDirectory(atPath: url.path)
        let output: [URL] = contents.filter({ skipHiddenFiles ? !$0.hasPrefix(".") : true}).map {
            url.appendingPathComponent($0)
        }

        return output
    }

    
    enum Errors: DescribedError {
        case invalidPath(String)
        var errorDescription: String {
            switch self { 
                case .invalidPath(let path): return "Invalid path \(path.singleQuoted)"
            }
        }
    }
    
    func dump() -> String {
        filesLock.lock()
        defer { filesLock.unlock() }

        return files.keys.sorted().joined(separator: "\n")
    }
}
