/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/*
    This file contains API for working with folder hierarchies, and is extensible to allow for testing
    for hierarchies as well.
*/

/// An abstract representation of a file (or folder).
protocol File {
    /// The name of the file.
    var name: String { get }

    /// Writes the file to a given URL.
    func write(to url: URL) throws
}

extension File {
    /// Writes the file inside of a folder and returns the URL that it was written to.
    @discardableResult
    func write(inside url: URL) throws -> URL {
        let outputURL = url.appendingPathComponent(name)
        try write(to: outputURL)
        return outputURL
    }
}

/// An item which provides data.
protocol DataRepresentable {
    func data() throws -> Data
}

/// `DataRepresentable` can automatically write itself to disk via `Data.write(to:)`
extension DataRepresentable {
    func write(to url: URL) throws {
        try data().write(to: url)
    }
}

// MARK: -

/// An abstract representation of a folder, containing some files or folders.
struct Folder: File {
    let name: String

    /// The files and sub folders that this folder contains.
    let content: [File]
    
    func appendingFile(_ newFile: File) -> Folder {
        return Folder(name: name, content: content + [newFile])
    }

    func write(to url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: nil)
        for file in content {
            try file.write(inside: url)
        }
    }
}

extension Folder {
    /// Returns a flat list of a folder's recursive listing for testing purposes.
    var recursiveContent: [File] {
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
struct InfoPlist: File, DataRepresentable {
    let name = "Info.plist"

    /// The information that the Into.plist file contains.
    let content: Content

    init(displayName: String, identifier: String, versionString: String = "1.0", developmentRegion: String = "en") {
        self.content = Content(
            displayName: displayName,
            identifier: identifier,
            versionString: versionString,
            developmentRegion: developmentRegion
        )
    }

    struct Content: Codable, Equatable {
        let displayName: String
        let identifier: String
        let versionString: String
        let developmentRegion: String

        fileprivate init(displayName: String, identifier: String, versionString: String, developmentRegion: String) {
            self.displayName = displayName
            self.identifier = identifier
            self.versionString = versionString
            self.developmentRegion = developmentRegion
        }

        enum CodingKeys: String, CodingKey {
            case displayName = "CFBundleDisplayName"
            case identifier = "CFBundleIdentifier"
            case versionString = "CFBundleVersion"
            case developmentRegion = "CFBundleDevelopmentRegion"
        }
    }

    func data() throws -> Data {
        // TODO: Replace this with PropertListEncoder (see below) when it's available in swift-corelibs-foundation
        // https://github.com/apple/swift-corelibs-foundation/commit/d2d72f88d93f7645b94c21af88a7c9f69c979e4f
        let infoPlist = [
            Content.CodingKeys.displayName.rawValue: content.displayName,
            Content.CodingKeys.identifier.rawValue: content.identifier,
            Content.CodingKeys.versionString.rawValue: content.versionString,
            Content.CodingKeys.developmentRegion.rawValue: content.developmentRegion,
        ]

        return try PropertyListSerialization.data(
            fromPropertyList: infoPlist,
            format: .xml,
            options: 0
        )
    }
}

/// A representation of a text file with some UTF-8 content.
struct TextFile: File, DataRepresentable {
    let name: String

    /// The UTF8 content of the file.
    let utf8Content: String

    func data() throws -> Data {
        return utf8Content.data(using: .utf8)!
    }
}

/// A representation of a text file with some UTF-8 content.
struct JSONFile<Content: Codable>: File, DataRepresentable {
    let name: String

    /// The UTF8 content of the file.
    let content: Content

    func data() throws -> Data {
        return try JSONEncoder().encode(content)
    }
}

/// A copy of another file on disk somewhere.
struct CopyOfFile: File, DataRepresentable {
    enum Error: DescribedError {
        case notAFile(URL)
        var errorDescription: String {
            switch self {
                case .notAFile(let url): return "Original url is not a file: \(url.path.singleQuoted)"
            }
        }
    }
    
    /// The original file.
    let original: URL
    let name: String
    
    init(original: URL, newName: String? = nil) {
        self.original = original
        self.name = newName ?? original.lastPathComponent
    }
    
    func data() throws -> Data {
        // Note that `CopyOfFile` always reads a file from disk and so it's okay
        // to use `FileManager.default` directly here instead of `FileManagerProtocol`.
        guard !FileManager.default.directoryExists(atPath: original.path) else { throw Error.notAFile(original) }
        return try Data(contentsOf: original)
    }
    
    func write(to url: URL) throws {
        try FileManager.default.copyItem(at: original, to: url)
    }
}

struct CopyOfFolder: File {
    /// The original file.
    let original: URL
    let name: String
    let shouldCopyFile: (URL) -> Bool
    
    init(original: URL, newName: String? = nil, filter shouldCopyFile: @escaping (URL) -> Bool = { _ in true }) {
        self.original = original
        self.name = newName ?? original.lastPathComponent
        self.shouldCopyFile = shouldCopyFile
    }
    
    func write(to url: URL) throws {
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
struct DataFile: File, DataRepresentable {
    var name: String
    var _data: Data
    
    init(name: String, data: Data) {
        self.name = name
        self._data = data
    }

    func data() throws -> Data {
        return _data
    }
}

/// A temporary folder which can write files to a temporary location on disk and
/// will delete itself when its instance is released from memory.
class TempFolder: File {
    let name: String
    let url: URL

    /// The files and sub folders that this folder contains.
    let content: [File]
    
    func write(to url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: nil)
        for file in content {
            try file.write(inside: url)
        }
    }

    init(content: [File], atRoot root: URL) throws {
        self.content = content

        url = root
        name = url.absoluteString

        try write(to: url)
    }
    
    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}
