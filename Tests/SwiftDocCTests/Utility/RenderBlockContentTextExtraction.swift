/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

extension Sequence where Element == RenderBlockContent {
    var paragraphText: [String] {
        compactMap { block in
            switch block {
            case .paragraph(let p):
                switch p.inlineContent[0] {
                case .text(let text): return text
                default: return nil
                }
            default: return nil
            }
        }
    }
}
