/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A reference to a URL.
public struct LinkReference: RenderReference {
    /// The type of this link reference.
    ///
    /// This value is always `.link`.
    public var type: RenderReferenceType = .link
    
    /// The identifier of this reference.
    public var identifier: RenderReferenceIdentifier
    
    /// The plain text title of the destination page.
    public var title: String
    
    /// The formatted title of the destination page.
    public var titleInlineContent: [RenderInlineContent]
    
    /// The topic url for the destination page.
    public var url: String
    
    
    /// Creates a new link reference with its initial values.
    ///
    /// - Parameters:
    ///   - identifier: The identifier of this reference.
    ///   - title: The plain text title of the destination page.
    ///   - titleInlineContent: The formatted title of the destination page.
    ///   - url: The topic url for the destination page.
    public init(identifier: RenderReferenceIdentifier, title: String, titleInlineContent: [RenderInlineContent]? = nil, url: String) {
        self.identifier = identifier
        self.title = title
        self.titleInlineContent = titleInlineContent ?? [.text(title)]
        self.url = url
    }
    
    enum CodingKeys: String, CodingKey {
        case type, identifier, title, titleInlineContent, url
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        type = try values.decode(RenderReferenceType.self, forKey: .type)
        identifier = try values.decode(RenderReferenceIdentifier.self, forKey: .identifier)
        
        let urlPath = try values.decode(String.self, forKey: .url)
        
        if let formattedTitle = try values.decodeIfPresent([RenderInlineContent].self, forKey: .titleInlineContent) {
            self.titleInlineContent = formattedTitle
            self.title = try values.decodeIfPresent(String.self, forKey: .title) ?? formattedTitle.plainText
        } else if let plainTextTitle = try values.decodeIfPresent(String.self, forKey: .title) {
            self.titleInlineContent = [.text(plainTextTitle)]
            self.title = plainTextTitle
        } else {
            self.titleInlineContent = [.text(urlPath)]
            self.title = urlPath
        }
        
        url = urlPath
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(type, forKey: .type)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(title, forKey: .title)
        try container.encode(titleInlineContent, forKey: .titleInlineContent)
        try container.encode(url, forKey: .url)
    }
}
