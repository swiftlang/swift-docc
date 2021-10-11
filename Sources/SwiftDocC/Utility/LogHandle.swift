/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// An object that writes logs to the given output device.
///
/// You can use log handle objects to write to standard output, standard error, or any given file handle.
public enum LogHandle: TextOutputStream {
    
    /// A log handle that will perform writes to standard output.
    case standardOutput
    
    /// A log handle that will perform writes to standard error.
    case standardError
    
    /// A log handle that will ignore all write requests.
    ///
    /// This log handle's intended use case is for testing scenarios when logs can be ignored.
    case none
    
    /// A log handle that will write to the given file handle.
    case file(FileHandle)
    
    /// A log handle that writes to an NSString reference.
    case memory(LogStorage)
    
    /// A by-reference string storage.
    public class LogStorage {
        var text = ""
    }
    
    /// Writes the given string to the log handle.
    public mutating func write(_ string: String) {
        switch self {
        case .standardOutput:
            fputs(string, stdout)
            fflush(stdout)
        case .standardError:
            fputs(string, stderr)
            fflush(stderr)
        case .none:
            return
        case .file(let fileHandle):
            fileHandle.write(Data(string.utf8))
        case .memory(let storage):
            storage.text.append(string)
        }
    }
}

