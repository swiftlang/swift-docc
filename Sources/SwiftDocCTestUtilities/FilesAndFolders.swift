/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import SwiftDocC

/*
    This file contains API for working with folder hierarchies, and is extensible to allow for testing
    for hierarchies as well.
*/

/// An abstract representation of a file (or folder).
public protocol File {
    /// The name of the file.
    var name: String { get }

    /// Writes the file to a given URL.
    func write(to url: URL) throws
}

public extension File {
    /// Writes the file inside of a folder and returns the URL that it was written to.
    @discardableResult
    func write(inside url: URL) throws -> URL {
        let outputURL = url.appendingPathComponent(name)
        try write(to: outputURL)
        return outputURL
    }
}

/// An item which provides data.
public protocol DataRepresentable {
    func data() throws -> Data
}

/// `DataRepresentable` can automatically write itself to disk via `Data.write(to:)`
public extension DataRepresentable {
    func write(to url: URL) throws {
        try data().write(to: url)
    }
}

// MARK: -

/// An abstract representation of a folder, containing some files or folders.
public struct Folder: File {
    public init(name: String, content: [File]) {
        self.name = name
        self.content = content
    }
    
    public let name: String

    /// The files and sub folders that this folder contains.
    public let content: [File]
    
    public func appendingFile(_ newFile: File) -> Folder {
        return Folder(name: name, content: content + [newFile])
    }

    public func write(to url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: nil)
        for file in content {
            try file.write(inside: url)
        }
    }
}

extension Folder {
    /// Returns a flat list of a folder's recursive listing for testing purposes.
    public var recursiveContent: [File] {
        var result = content
        for file in content {
            if let content = (file as? Folder)?.recursiveContent {
                result.append(contentsOf: content)
            }
        }
        return result
    }
}

/// A representation of an Info.plist file.
public struct InfoPlist: File, DataRepresentable {
    public let name = "Info.plist"

    /// The information that the Into.plist file contains.
    public let content: Content

    public init(displayName: String? = nil, identifier: String? = nil) {
        self.content = Content(
            displayName: displayName,
            identifier: identifier
        )
    }

    public struct Content: Codable, Equatable {
        public let displayName: String?
        public let identifier: String?

        fileprivate init(displayName: String?, identifier: String?) {
            self.displayName = displayName
            self.identifier = identifier
        }

        enum CodingKeys: String, CodingKey {
            case displayName = "CFBundleDisplayName"
            case identifier = "CFBundleIdentifier"
        }
    }

    public func data() throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        
        return try encoder.encode([
            Content.CodingKeys.displayName.rawValue: content.displayName,
            Content.CodingKeys.identifier.rawValue: content.identifier,
        ])
    }
}

/// A representation of a text file with some UTF-8 content.
public struct TextFile: File, DataRepresentable {
    public init(name: String, utf8Content: String) {
        self.name = name
        self.utf8Content = utf8Content
    }
    
    public let name: String

    /// The UTF8 content of the file.
    public let utf8Content: String

    public func data() throws -> Data {
        return utf8Content.data(using: .utf8)!
    }
}

/// A representation of a text file with some UTF-8 content.
public struct JSONFile<Content: Codable>: File, DataRepresentable {
    public init(name: String, content: Content) {
        self.name = name
        self.content = content
    }
    
    public let name: String

    /// The UTF8 content of the file.
    public let content: Content

    public func data() throws -> Data {
        return try JSONEncoder().encode(content)
    }
}

/// A copy of another file on disk somewhere.
public struct CopyOfFile: File, DataRepresentable {
    enum Error: LocalizedError {
        case notAFile(URL)
        var errorDescription: String {
            switch self {
                case .notAFile(let url): return "Original url is not a file: '\(url.path)'"
            }
        }
    }
    
    /// The original file.
    public let original: URL
    public let name: String
    
    public init(original: URL, newName: String? = nil) {
        self.original = original
        self.name = newName ?? original.lastPathComponent
    }
    
    public func data() throws -> Data {
        // Note that `CopyOfFile` always reads a file from disk and so it's okay
        // to use `FileManager.default` directly here instead of `FileManagerProtocol`.
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: original.path, isDirectory: &isDirectory), !isDirectory.boolValue else { throw Error.notAFile(original) }
        return try Data(contentsOf: original)
    }
    
    public func write(to url: URL) throws {
        try FileManager.default.copyItem(at: original, to: url)
    }
}

public struct CopyOfFolder: File {
    /// The original file.
    let original: URL
    public let name: String
    let shouldCopyFile: (URL) -> Bool
    
    public init(original: URL, newName: String? = nil, filter shouldCopyFile: @escaping (URL) -> Bool = { _ in true }) {
        self.original = original
        self.name = newName ?? original.lastPathComponent
        self.shouldCopyFile = shouldCopyFile
    }
    
    public func write(to url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: nil)
        for filePath in try FileManager.default.contentsOfDirectory(atPath: original.path) {
            // `contentsOfDirectory(atPath)` includes hidden files, skipHiddenFiles option doesn't help on Linux.
            guard !filePath.hasPrefix(".") else { continue }
            let originalFileURL = original.appendingPathComponent(filePath)
            guard shouldCopyFile(originalFileURL) else { continue }
            
            try FileManager.default.copyItem(at: originalFileURL, to: url.appendingPathComponent(filePath))
        }
    }
}

/// A file backed by `Data`.
public struct DataFile: File, DataRepresentable {
    public var name: String
    var _data: Data
    
    public init(name: String, data: Data) {
        self.name = name
        self._data = data
    }

    public func data() throws -> Data {
        return _data
    }
}

extension XCTestCase {
    /// Creates a ``Folder`` and writes its content to a temporary location on disk.
    ///
    /// - Parameters:
    ///   - content: The files and subfolders to write to a temporary location
    /// - Returns: The temporary location where the temporary folder was written.
    public func createTempFolder(content: [File]) throws -> URL {
        let temporaryDirectory = try createTemporaryDirectory().appendingPathComponent("TempDirectory-\(ProcessInfo.processInfo.globallyUniqueString)")
        let folder = Folder(name: temporaryDirectory.lastPathComponent, content: content)
        try folder.write(to: temporaryDirectory)
        return temporaryDirectory
    }
}

// MARK: Dump

extension Folder {
    /// Creates a file and folder hierarchy from the given file paths.
    ///
    /// ## Example
    /// For example, `makeStructure(filePaths: ["one/two/a.json", "one/two/b.json"])` creates the following files and folders.
    /// ```
    /// one/
    /// ╰─ two/
    ///    ├─ a.json
    ///    ╰─ b.json
    /// ```
    ///
    /// - Note: If there are more than one first path component in the provided paths, the return value will contain more than one element.
    public static func makeStructure(
        filePaths: [String],
        renderNodeReferencePrefix: String? = nil,
        isEmptyDirectoryCheck: (String) -> Bool = { _ in false }
    ) -> [File] {
        guard !filePaths.isEmpty else {
            return []
        }
        typealias Path = [String]
        
        func _makeStructure(paths: [Path], accumulatedBasePath: String) -> [File] {
            assert(paths.allSatisfy { !$0.isEmpty })
            
            let grouped = [String: [Path]](grouping: paths, by: { $0.first! }).mapValues {
                $0.map { Array($0.dropFirst()) }
            }
            
            return grouped.map { pathComponent, remaining in
                let absolutePath = "\(accumulatedBasePath)/\(pathComponent)"
                if remaining == [[]] && !isEmptyDirectoryCheck(absolutePath) {
                    return JSONFile(name: pathComponent, content: makeMinimalTestRenderNode(path: (renderNodeReferencePrefix ?? "") + absolutePath))
                } else {
                    return Folder(name: pathComponent, content: _makeStructure(paths: remaining.filter { !$0.isEmpty }, accumulatedBasePath: absolutePath))
                }
            }
        }
        
        if filePaths.allSatisfy({ $0.hasPrefix("/")}) {
            let subPaths = filePaths.map { $0.dropFirst() }.filter { !$0.isEmpty }
            return [Folder(name: "", content: _makeStructure(paths: subPaths.map { String($0).components(separatedBy: CharacterSet(charactersIn: "/")) }, accumulatedBasePath: ""))]
        }
        
        return _makeStructure(paths: filePaths.map { $0.components(separatedBy: CharacterSet(charactersIn: "/")) }, accumulatedBasePath: "")
    }
}

private func makeMinimalTestRenderNode(path: String) -> RenderNode {
    let reference = ResolvedTopicReference(id: "org.swift.test", path: path, sourceLanguage: .swift)
    let rawReference = reference.url.absoluteString
    let title = path.components(separatedBy: "/").last ?? path
    
    var renderNode = RenderNode(identifier: reference, kind: .article)
    renderNode.metadata.title = title
    renderNode.references = [
        rawReference: TopicRenderReference(
            identifier: RenderReferenceIdentifier(rawReference),
            title: title,
            abstract: [],
            url: reference.path,
            kind: .article
        )
    ]
    return renderNode
}

/// A node in a tree structure that can be printed into a visual representation for debugging.
private struct DumpableNode {
    var name: String
    var children: [DumpableNode]?
    
    init(_ file: File) {
        if let folder = file as? Folder {
            name = file.name
            children = folder.content.map { DumpableNode($0) }
        } else {
            name = file.name
            children = nil
        }
    }
}

extension File {
    /// Returns a stable string representation of the file and folder hierarchy that can be checked in tests.
    ///
    /// ## Example
    /// ```swift
    /// Folder(name: "one", content: [
    ///     Folder(name: "two", content: [
    ///         TextFile(name: "a.json", utf8Content: ""),
    ///         TextFile(name: "b.json", utf8Content: ""),
    ///     ])
    /// ])
    /// ```
    /// The string `dump()` for the folder hierarchy above is shown below:
    /// ```
    /// one/
    /// ╰─ two/
    ///    ├─ a.json
    ///    ╰─ b.json
    /// ```
    public func dump() -> String {
        Self.dump(.init(self))
            .trimmingCharacters(in: .newlines) // remove the trailing newline
    }

    private static func dump(_ node: DumpableNode, decorator: String = "") -> String {
        var result = ""
        result.append(decorator)
        if !decorator.isEmpty {
            result.append("─ ")
        }
        result.append(node.name)
        guard let children = node.children else {
            return result + "\n"
        }
        result.append("/\n")
        
        let sortedChildren = children.sorted(by: { lhs, rhs in
            // Sort files before folders if the folder name is a prefix of the file name
            switch (lhs.children, rhs.children) {
            case (nil, nil):
                return lhs.name < rhs.name
            case (nil, _) where lhs.name.hasPrefix(rhs.name):
                return true
            case (_, nil) where rhs.name.hasPrefix(lhs.name):
                return false
            default:
                return lhs.name < rhs.name
            }
        })
        
        for (index, child) in sortedChildren.enumerated() {
            var decorator = decorator
            if decorator.hasSuffix("├") {
                decorator = decorator.dropLast() + "│  "
            }
            if decorator.hasSuffix("╰") {
                decorator = decorator.dropLast() + "   "
            }
            let newDecorator = decorator + (index == sortedChildren.count-1 ? "╰" : "├")
            result.append(dump(child, decorator: newDecorator))
        }
        return result
    }
}
