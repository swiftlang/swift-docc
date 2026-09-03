/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import DocCCommon

extension SourceLanguage {
    /// A "class" HTML attributes that CSS queries can use to hide or show language specific content.
    package var filterAttribute: HTMLNode.Attribute {
        .class("\(id.lowercased())-only")
    }
}
