/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

enum ZipFileError: Error, CustomStringConvertible {
    case noCentralDirectory
    case readOffEndOfSource
    case spannedArchivesNotSupported
    case badDirectoryEntry(at: Int)
    case badZip64Record(at: Int)
    case badPathInDirectory(String)
    case duplicateEntry(String)
    case fileNotFound(String)
    case itemIsADirectory(String)
    case itemIsNotADirectory(String)
    case unsupportedCompression(String)
    case badLocalHeader(for: String)
    case unsupportedVersion(UInt16)
    case fileTooLarge(String)

    var description: String {
        switch self {
            case .noCentralDirectory:
                "Zip file central directory missing"
            case .readOffEndOfSource:
                "Attempt to read off end of zip file"
            case .spannedArchivesNotSupported:
                "Spanned zip archives are not supported"
            case .badDirectoryEntry(let ndx):
                "Bad zip directory entry at \(ndx)"
            case .badZip64Record(let ndx):
                "Bad Zip64 record at \(ndx)"
            case .badPathInDirectory(let path):
                "Bad path in zip directory: \"\(path)\""
            case .duplicateEntry(let path):
                "Duplicate entry in zip directory: \"\(path)\""
            case .fileNotFound(let path):
                "File not found in zip: \"\(path)\""
            case .itemIsADirectory(let path):
                "Item in zip at path \"\(path)\" is a directory"
            case .itemIsNotADirectory(let path):
                "Item in zip at path \"\(path)\" is not a directory"
            case .unsupportedCompression(let path):
                "Unsupported compression for item in zip with path \"\(path)\""
            case .badLocalHeader(for: let path):
                "Bad local header in zip for \"\(path)\""
            case .unsupportedVersion(let version):
                "Unsupported zip version \(version)"
            case .fileTooLarge(let name):
                "File \"\(name)\" is too large for a non-Zip64 archive"
        }
    }
}
