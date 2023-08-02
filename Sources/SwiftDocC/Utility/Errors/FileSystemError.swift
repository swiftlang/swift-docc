/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public enum FileSystemError: Error, DescribedError {
    /// No data could be read from file at `path`.
    case noDataReadFromFile(path: String)

    public var errorDescription: String {
        switch self {
        case .noDataReadFromFile(let path):
            return "No data could be read from file at `\(path)`"
        }
    }
}
