/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

public extension RenderNode {
    /// A tag that can be assigned to a render node.
    struct Tag: Codable, Equatable {
        /// The tag type.
        let type: String
        /// The text to display.
        let text: String
        
        /// A pre-defined SPI tag.
        static let spi = Tag(type: "spi", text: "SPI")
    }
}
