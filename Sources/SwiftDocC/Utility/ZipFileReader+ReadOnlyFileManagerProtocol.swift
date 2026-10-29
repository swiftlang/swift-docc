/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

package import Foundation
package import Zip

extension ZipFileReader: ReadOnlyFileManagerProtocol {

    package func contents(atPath path: String) -> Data? {
        try? contents(of: URL(filePath: path))
    }

    package func contents(of url: URL) throws -> Data {
        let file = try open(path: url.path)
        var data = Data()
        let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 65536,
                                                            alignment: 16)
        defer {
            buffer.deallocate()
        }

        while true {
            var span = OutputRawSpan(buffer: buffer, initializedCount: 0)
            try file.read(into: &span)
            if span.byteCount == 0 {
                break
            }

            data.append(buffer.baseAddress!.assumingMemoryBound(to: UInt8.self),
                        count: span.byteCount)
        }

        return data
    }

    package var currentDirectoryPath: String { "/" }

    package func contentsOfDirectory(atPath path: String) throws -> [String] {
        guard let item = item(at: path) else {
            throw ZipFileError.fileNotFound(path)
        }

        switch item.kind {
            case .file:
                throw ZipFileError.itemIsNotADirectory(path)
            case let .directory(contents):
                return Array(contents.keys)
        }
    }

    package func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions) throws -> [URL] {
        let path = url.path
        guard let item = item(at: path) else {
            throw ZipFileError.fileNotFound(path)
        }

        switch item.kind {
            case .file:
                throw ZipFileError.itemIsNotADirectory(path)
            case let .directory(contents):
                var result: [URL] = []
                for (name, child) in contents {
                    let itemURL = url.appending(
                        path: name,
                        directoryHint: child.isDirectory 
                            ? .isDirectory : .notDirectory
                    )
                    result.append(itemURL)
                }
                return result
        }
    }

    package func contentsOfDirectory(at url: URL, options mask: FileManager.DirectoryEnumerationOptions) throws -> (files: [URL], directories: [URL]) {
        let path = url.path
        guard let item = item(at: path) else {
            throw ZipFileError.fileNotFound(path)
        }

        switch item.kind {
            case .file:
                throw ZipFileError.itemIsNotADirectory(path)
            case let .directory(contents):
                var files: [URL] = []
                var directories: [URL] = []
                for (name, child) in contents {
                    let itemURL = url.appending(
                        path: name,
                        directoryHint: child.isDirectory 
                            ? .isDirectory : .notDirectory
                    )
                    if child.isDirectory {
                        directories.append(itemURL)
                    } else {
                        files.append(itemURL)
                    }
                }
                return (files: files, directories: directories)
        }
    }

    package func sizeOfDirectory(at url: URL, options mask: FileManager.DirectoryEnumerationOptions) throws -> Int64 {
        guard let item = item(at: url.path) else {
            throw ZipFileError.fileNotFound(url.path)
        }

        if !item.isDirectory {
            throw ZipFileError.itemIsNotADirectory(url.path)
        }

        var totalSize = Int64(0)
        var stack = [item]

        while let dir = stack.popLast() {
            guard case let .directory(contents) = dir.kind else {
                fatalError("Unexpected non-directory found in directory stack")
            }

            for (_, child) in contents {
                switch child.kind {
                    case .file: 
                        totalSize += Int64(child.uncompressedSize)
                    case .directory:
                        stack.append(child)
                }
            }
        }

        return totalSize
    }

}