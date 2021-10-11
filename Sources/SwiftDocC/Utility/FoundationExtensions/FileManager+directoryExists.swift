/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension FileManager {
    /// Returns a Boolean value that indicates whether a directory exists at a specified path.
    func directoryExists(atPath path: String) -> Bool {
        var isDirectory = ObjCBool(booleanLiteral: false)
        let fileExistsAtPath = fileExists(atPath: path, isDirectory: &isDirectory)
        return fileExistsAtPath && isDirectory.boolValue
    }
}
