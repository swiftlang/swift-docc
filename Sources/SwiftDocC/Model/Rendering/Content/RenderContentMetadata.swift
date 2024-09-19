/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Additional metadata that might belong to a content element.
public struct RenderContentMetadata: Equatable, Codable, Hashable {
    /// An optional named anchor to the current element.
    public var anchor: String?
    /// An optional custom title.
    public var title: String?
    /// An optional custom abstract.
    public var abstract: [RenderInlineContent]?
    /// An optional identifier for the device frame that should wrap this element.
    public var deviceFrame: String?
}

extension RenderContentMetadata {
    public func rawIndexableTextContent(references: [String : RenderReference]) -> String {
        return (title ?? "")
            + (abstract?.rawIndexableTextContent(references: references) ?? "")
    }
}
