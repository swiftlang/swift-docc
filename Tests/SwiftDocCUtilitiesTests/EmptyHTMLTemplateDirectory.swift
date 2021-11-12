/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
@testable import SwiftDocC

/// A folder that represents a fake html-build dir for testing.
extension Folder {
    static let emptyHTMLTemplateDirectory = Folder(name: "template", content: [
        TextFile(name: "index.html", utf8Content: ""),
    ])
}
