/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

// Consumers of `MarkdownOutputManifest` in other packages should be able to lift this file and be able to use it standalone, without any dependencies from SwiftDocC.

/// A manifest of markdown-generated documentation from a single catalog
public struct MarkdownOutputManifest: Codable {
    public static let version = "0.1.0"
    
    public let manifestVersion: String
    public let title: String
    public var documents: [Document]
    
    public init(title: String, documents: [Document]) {
        self.manifestVersion = Self.version
        self.title = title
        self.documents = documents
    }
}

extension MarkdownOutputManifest {
    
    public enum DocumentType: String, Codable {
        case article, tutorial, symbol
    }
    
    public enum RelationshipType: String, Codable {
        case topics
        case memberSymbols
        case relationships
    }
    
    public struct RelatedDocument: Codable, Hashable {
        public let uri: String
        public let subtype: String
    }
    
    public struct Document: Codable {
        /// The URI of the document
        public let uri: String
        /// The type of the document
        public let documentType: DocumentType
        /// The title of the document
        public let title: String
        
        /// The outgoing references of the document, grouped by relationship type
        public var references: [RelationshipType: Set<RelatedDocument>]
        
        public init(uri: String, documentType: MarkdownOutputManifest.DocumentType, title: String, references: [MarkdownOutputManifest.RelationshipType : Set<RelatedDocument>]) {
            self.uri = uri
            self.documentType = documentType
            self.title = title
            self.references = references
        }
    }
}
