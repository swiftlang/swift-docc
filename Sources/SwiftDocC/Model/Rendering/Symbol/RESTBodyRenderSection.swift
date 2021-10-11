/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A section that contains a REST request-body details.
struct RESTBodyRenderSection: RenderSection, Equatable {
    public var kind: RenderSectionKind = .restBody
    /// A title for the section.
    public let title: String
    
    /// Content encoding MIME type for the request body.
    public let mimeType: String
    
    /// A declaration that describes the body content.
    public let bodyContentType: [DeclarationRenderSection.Token]
    
    /// Details about the request body, if available.
    public let content: [RenderBlockContent]?
    
    /// A list of request parameters, if applicable.
    ///
    /// If the body content is `multipart/form-data` encoded, it contains a list
    /// of parameters. Each of these parameters is a ``RESTParameter``
    /// and it has its own value-content encoding, name, type, and description.
    public let parameters: [RenderProperty]?

    /// Creates a new REST body section.
    /// - Parameters:
    ///   - title: The title for the section.
    ///   - mimeType: Content MIME type for the request body.
    ///   - bodyContentType: A declaration that describes the body content.
    ///   - content: Details about the request body, if any.
    ///   - parameters: The list of parameters for the body, if any.
    public init(title: String, mimeType: String, bodyContentType: [DeclarationRenderSection.Token], content: [RenderBlockContent]?, parameters: [RenderProperty]?) {
        self.title = title
        self.mimeType = mimeType
        self.bodyContentType = bodyContentType
        self.content = content
        self.parameters = parameters
    }
}
