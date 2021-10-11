/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// An image asset file.
struct ImageFile {
    static var counter = 0
    let name: String
    
    static let data = try! Data(contentsOf: URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("image@2x.png"))
    
    init() {
        Self.counter += 1
        name = "image\(Self.counter).png"
    }
    
    func write(to: URL) throws {
        try Self.data.write(to: to)
    }
}
