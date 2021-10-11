/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A swift source file.
class SwiftFile {
    var contents = ""
    
    init(imports: String) {
        contents = imports.appending("\n\n")
    }
    
    func append(_ block: ()->String) {
        contents.append(block())
        contents.append("\n")
    }
    
    func write(to: URL) throws {
        let dirFolder = to.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dirFolder.path) {
            try FileManager.default.createDirectory(at: dirFolder, withIntermediateDirectories: false, attributes: nil)
        }
        try contents.write(to: to, atomically: true, encoding: .utf8)
    }
}
