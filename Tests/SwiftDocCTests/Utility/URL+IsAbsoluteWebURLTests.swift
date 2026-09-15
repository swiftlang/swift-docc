/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
@testable import SwiftDocC
import Testing

struct URL_IsAbsoluteWebURLTests {
    @Test(arguments: [
        (URL(fileURLWithPath: "/Users/username/Documents/Some Folder/Some Document.txt"), false),
        (URL(string: "doc://swift-doc")!, false),
        (URL(string: "swift.org")!, false),
        (URL(string: "https://swift.org")!, true),
    ])
    func recognizesAbsoluteWebURLs(url: URL, isAbsoluteWebURL: Bool) {
        #expect(url.isAbsoluteWebURL == isAbsoluteWebURL)
    }
}
