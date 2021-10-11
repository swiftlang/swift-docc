/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A compound section that contains a list of declaration sections.
public struct DeclarationsRenderSection: RenderSection, Codable, Equatable {
    /// The section title, by default `nil`.
    public static var title: String? = nil
    
    public var kind: RenderSectionKind = .declarations
    /// The list of declaration sections.
    public var declarations: [DeclarationRenderSection]
    
    /// Creates a new declarations section.
    /// - Parameter declarations: The list of declaration sections to include.
    public init(declarations: [DeclarationRenderSection]) {
        self.declarations = declarations
    }
}

extension DeclarationsRenderSection: TextIndexing {
    public var headings: [String] {
        return []
    }
    
    public func rawIndexableTextContent(references: [String : RenderReference]) -> String {
        return ""
    }
}

/// A section that contains a symbol declaration.
public struct DeclarationRenderSection: Codable, Equatable {
    /// The platforms this declaration applies to.
    public let platforms: [PlatformName?]
    
    /// The list of declaration tokens that make up the declaration.
    ///
    /// For example, the declaration "var x: Int?" is comprised of a:
    ///  - "var" keyword token
    ///  - " x: " string token
    ///  - an "Int?" type-identifier token
    public let tokens: [Token]
    
    /// The programming languages that this declaration uses.
    public let languages: [String]?
    
    /// A lexical token to use in declarations.
    ///
    /// A lexical token is a string with an associated meaning in source code.
    /// For example, `123` is represented as a single token of kind "number".
    public struct Token: Codable, Hashable {
        /// The token text content.
        public let text: String
        /// The token programming kind.
        public let kind: Kind
        
        /// The list of all expected tokens in a declaration.
        public enum Kind: String, Codable, RawRepresentable {
            /// A known keyword, like "class" or "var".
            case keyword
            /// An attribute, for example, "@main".
            case attribute
            /// A numeric literal, like "1.25" or "0xff".
            case number
            /// A string literal.
            case string
            /// An identifier, for example a property or a function name.
            case identifier
            /// A type identifier, for example, an integer or raw data.
            case typeIdentifier
            /// A generic parameter in a function signature.
            case genericParameter
            /// A plain text, such as whitespace or punctuation.
            case text
            /// A parameter name to use inside a function body.
            case internalParam
            /// A parameter name to use when calling a function.
            case externalParam
            /// A label that precedes an identifier.
            case label
        }
        
        /// If the token is a known symbol, its identifier.
        ///
        /// This value can be used to look up more information in the render node's ``RenderNode/references`` object.
        public let identifier: String?
        
        /// If the token is a known symbol, its precise identifier as vended in the symbol graph.
        public let preciseIdentifier: String?
        
        /// Creates a new declaration token with optional identifier and precise identifier.
        /// - Parameters:
        ///   - text: The text content of the token.
        ///   - kind: The kind of the token.
        ///   - identifier: If the token refers to a known symbol, its identifier.
        ///   - preciseIdentifier: If the refers to a symbol, its precise identifier.
        public init(text: String, kind: Kind, identifier: String? = nil, preciseIdentifier: String? = nil) {
            self.text = text
            self.kind = kind
            self.identifier = identifier
            self.preciseIdentifier = preciseIdentifier
        }
      
        /// The token's identifier, if that token is a known symbol.
        @available(*, deprecated, renamed: "identifier", message: "Please use identifier instead")
        public var reference: String? {
            return identifier
        }
        
        // MARK: - Codable
        
        private enum CodingKeys: CodingKey {
            case text, kind, identifier, preciseIdentifier
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(text, forKey: .text)
            try container.encode(kind, forKey: .kind)
            try container.encodeIfPresent(identifier, forKey: .identifier)
            try container.encodeIfPresent(preciseIdentifier, forKey: .preciseIdentifier)
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            text = try container.decode(String.self, forKey: .text)
            kind = try container.decode(Kind.self, forKey: .kind)
            preciseIdentifier = try container.decodeIfPresent(String.self, forKey: .preciseIdentifier)
            identifier = try container.decodeIfPresent(String.self, forKey: .identifier)

            if let reference = identifier {
                decoder.registerReferences([reference])
            }
        }
    }
    
    /// Creates a new declaration section.
    /// - Parameters:
    ///   - languages: The source languages to which this declaration applies.
    ///   - platforms: The platforms to which this declaration applies.
    ///   - tokens: The list of declaration tokens.
    public init(languages: [String]?, platforms: [PlatformName?], tokens: [Token]) {
        self.languages = languages
        self.platforms = platforms
        self.tokens = tokens
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tokens = try container.decode([Token].self, forKey: .tokens)
        platforms = try container.decode([PlatformName?].self, forKey: .platforms)
        languages = try container.decodeIfPresent([String].self, forKey: .languages)
    }
}

extension DeclarationRenderSection: TextIndexing {
    public var headings: [String] {
        return []
    }

    public func rawIndexableTextContent(references: [String : RenderReference]) -> String {
        return ""
    }
}
