/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A section that displays a list of REST responses.
struct RESTResponseRenderSection: RenderSection, Equatable {
    public var kind: RenderSectionKind = .restResponses
    /// The title for the section.
    public let title: String
    /// The list of possible REST responses.
    public let items: [RESTResponse]
    
    /// Creates a new REST response section.
    /// - Parameters:
    ///   - title: The title for the section.
    ///   - items: The list of possible REST responses.
    public init(title: String, items: [RESTResponse]) {
        self.title = title
        self.items = items
    }
}

/// A REST response that includes the HTTP status, reason,
/// and the MIME type encoding of the response body.
///
/// If the response is a decodable object, a declaration-style `type` property
/// describes the expected type and can provide an optional link to the expected
/// documentation symbol.
struct RESTResponse: Codable, TextIndexing, Equatable {
    /// The HTTP status code for the response.
    public let status: UInt
    /// An optional plain-text reason for the response.
    public let reason: String?
    /// An optional response MIME content-type.
    public let mimeType: String?
    /// A type declaration of the response's content.
    public let type: [DeclarationRenderSection.Token]
    /// Response details, if any.
    public let content: [RenderBlockContent]?

    /// Creates a new REST response section.
    /// - Parameters:
    ///   - status: The HTTP status code for the response.
    ///   - reason: An optional plain-text reason for the response.
    ///   - mimeType: An optional response MIME content-type.
    ///   - type: A type declaration of the response's content.
    ///   - content: Response details, if any.
    public init(
        status: UInt,
        reason: String?,
        mimeType: String?,
        type: [DeclarationRenderSection.Token],
        content: [RenderBlockContent]?
    ) {
        self.status = status
        self.reason = reason
        self.mimeType = mimeType
        self.type = type
        self.content = content
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(UInt.self, forKey: .status)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
        type = try container.decode([DeclarationRenderSection.Token].self, forKey: .type)
        content = try container.decodeIfPresent([RenderBlockContent].self, forKey: .content)
    }
}
