/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A section that contains a REST API endpoint.
///
/// This section is similar to ``DeclarationRenderSection`` for symbols and
/// describes a tokenized endpoint for a REST API. The token list starts with
/// an HTTP method token followed by tokens for the complete endpoint URL. Any path
/// components that are dynamic instead of fixed are represented with a parameter name
/// enclosed in curly brackets.
///
/// A complete token representation for the endpoint `GET https://www.example.com/api/artists/{id}`
/// is (the token kind is in brackets):
///  - (method) `GET`
///  - (baseURL) `https://www.example.com`
///  - (path) `/api/artists/`
///  - (parameter) `{id}`
public struct RESTEndpointRenderSection: RenderSection {
    public var kind: RenderSectionKind = .restEndpoint
    /// A single token in a REST endpoint.
    public struct Token: Codable {
        /// The kind of REST endpoint token.
        public enum Kind: String, Codable {
            case method, baseURL, path, parameter, text
        }
        
        /// The endpoint specific token kind.
        public let kind: Kind
        /// The plain text of the token.
        public let text: String
    }
    
    /// The title for the section.
    public let title: String
    
    /// The list of tokens.
    public let tokens: [Token]
    
    /// Creates a new REST endpoint section.
    /// - Parameters:
    ///   - title: The title for the section.
    ///   - tokens: The list of tokens.
    public init(title: String, tokens: [Token]) {
        self.title = title
        self.tokens = tokens
    }
}
