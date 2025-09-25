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
    
    /// The version of this manifest
    public let manifestVersion: String
    /// The manifest title, this will typically match the module that the manifest is generated for
    public let title: String
    /// All documents contained in the manifest
    public var documents: Set<Document>
    /// Relationships involving documents in the manifest
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
        /// For this relationship, the source URI will be the URI of a document, and the target URI will be the topic to which it belongs
        case belongsToTopic
        /// For this relationship, the source and target URIs will be indicated by the directionality of the subtype, e.g. source "conformsTo" target. 
        case relatedSymbol
    }
    
    /// A relationship between two documents in the manifest.
    ///
    /// Parent / child symbol relationships are not included here, because those relationships are implicit in the URI structure of the documents. See ``children(of:)``.
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
    
    public func children(of parent: Document) -> Set<Document> {
        let parentPrefix = parent.uri + "/"
        let prefixEnd = parentPrefix.endIndex
        return documents.filter { document in
            guard document.uri.hasPrefix(parentPrefix) else {
                return false
            }
            let components = document.uri[prefixEnd...].components(separatedBy: "/")
            return components.count == 1
        }
    }
}
