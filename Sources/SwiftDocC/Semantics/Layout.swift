/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// Possible layouts for certain containers of markup content.
public enum Layout: String, CaseIterable, Codable, DirectiveArgumentValueConvertible {
    /// A container split vertically into a left and right section.
    case horizontal
    
    /// A container split horizontally into a top and bottom section.
    case vertical
    
    public init?(rawDirectiveArgumentValue: String) {
        self.init(rawValue: rawDirectiveArgumentValue)
    }
    
    public var description: String {
        switch self {
        case .horizontal: return "horizontal"
        case .vertical: return "vertical"
        }
    }
}
