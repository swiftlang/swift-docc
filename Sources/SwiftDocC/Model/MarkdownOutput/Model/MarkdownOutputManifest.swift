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
public struct MarkdownOutputManifest: Codable, Sendable {
    public static let version = "0.1.0"
    
    public let manifestVersion: String
    public let title: String
    public var documents: Set<Document>
    public var relationships: Set<Relationship>
    
    public init(title: String, documents: Set<Document> = [], relationships: Set<Relationship> = []) {
        self.manifestVersion = Self.version
        self.title = title
        self.documents = documents
        self.relationships = relationships
    }
}

extension MarkdownOutputManifest {
    
    public enum DocumentType: String, Codable, Sendable {
        case article, tutorial, symbol
    }
    
    public enum RelationshipType: String, Codable, Sendable {
        case belongsToTopic
        case memberSymbol
        case relatedSymbol
    }
    
    public struct Relationship: Codable, Hashable, Sendable {
        
        public let sourceURI: String
        public let relationshipType: RelationshipType
        public let subtype: String?
        public let targetURI: String
        
        public init(sourceURI: String, relationshipType: MarkdownOutputManifest.RelationshipType, subtype: String? = nil, targetURI: String) {
            self.sourceURI = sourceURI
            self.relationshipType = relationshipType
            self.subtype = subtype
            self.targetURI = targetURI
        }
    }
    
    public struct Document: Codable, Hashable, Sendable {
        /// The URI of the document
        public let uri: String
        /// The type of the document
        public let documentType: DocumentType
        /// The title of the document
        public let title: String
                
        public init(uri: String, documentType: MarkdownOutputManifest.DocumentType, title: String) {
            self.uri = uri
            self.documentType = documentType
            self.title = title
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
        }
    }
}
