/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A manifest of markdown-generated documentation from a single catalog
package struct MarkdownOutputManifest: Codable, Sendable {
    package static let version = SemanticVersion(major: 0, minor: 1, patch: 0)
    
    /// The version of this manifest
    let manifestVersion: SemanticVersion
    /// The manifest title, this will typically match the module that the manifest is generated for
    package let title: String
    /// All documents contained in the manifest
    var documents: Set<Document>
    /// Relationships involving documents in the manifest
    var relationships: Set<Relationship>
    
    init(title: String, documents: Set<Document> = [], relationships: Set<Relationship> = []) {
        self.manifestVersion = Self.version
        self.title = title
        self.documents = documents
        self.relationships = relationships
    }
    
    package func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(manifestVersion, forKey: .manifestVersion)
        try container.encode(title, forKey: .title)
        try container.encode(documents.sorted(), forKey: .documents)
        try container.encode(relationships.sorted(), forKey: .relationships)
    }
}

extension MarkdownOutputManifest {
    
    enum DocumentType: String, Codable, Sendable {
        case article, tutorial, symbol
    }
    
    enum RelationshipType: String, Codable, Sendable {
        /// For this relationship, the source URI will be the URI of a document, and the target URI will be the topic to which it belongs
        case belongsToTopic
        /// For this relationship, the source and target URIs will be indicated by the directionality of the subtype, e.g. source "conformsTo" target. 
        case relatedSymbol
    }
        
    /// A relationship between two documents in the manifest.
    ///
    /// Parent / child symbol relationships are not included here, because those relationships are implicit in the identifier structure of the documents. 
    struct Relationship: Codable, Hashable, Sendable, Comparable {
        
        let sourceIdentifier: String
        let relationshipType: RelationshipType
        let subtype: RelationshipsGroup.Kind?
        let targetIdentifier: String
        
        enum CodingKeys: String, CodingKey {
            case sourceIdentifier
            case relationshipType
            case subtype
            case targetIdentifier
        }

        init(sourceIdentifier: String, relationshipType: MarkdownOutputManifest.RelationshipType, subtype: RelationshipsGroup.Kind? = nil, targetIdentifier: String) {
            self.sourceIdentifier = sourceIdentifier
            self.relationshipType = relationshipType
            self.subtype = subtype
            self.targetIdentifier = targetIdentifier
        }
        
        static func < (lhs: MarkdownOutputManifest.Relationship, rhs: MarkdownOutputManifest.Relationship) -> Bool {
            if lhs.sourceIdentifier < rhs.sourceIdentifier {
                return true
            } else if lhs.sourceIdentifier == rhs.sourceIdentifier {
                return lhs.targetIdentifier < rhs.targetIdentifier
            } else {
                return false
            }
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: MarkdownOutputManifest.Relationship.CodingKeys.self)
            self.sourceIdentifier = try container.decode(String.self, forKey: .sourceIdentifier)
            self.relationshipType = try container.decode(RelationshipType.self, forKey: .relationshipType)
            let subtypeValue = try container.decodeIfPresent(String.self, forKey: .subtype)
            self.subtype = subtypeValue.flatMap(RelationshipsGroup.Kind.init(rawValue:))
            self.targetIdentifier = try container.decode(String.self, forKey: .targetIdentifier)
        }
        
        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(sourceIdentifier, forKey: .sourceIdentifier)
            try container.encode(relationshipType, forKey: .relationshipType)
            try container.encodeIfPresent(subtype?.rawValue, forKey: .subtype)
            try container.encode(targetIdentifier, forKey: .targetIdentifier)
        }
    }
    
    struct Document: Codable, Hashable, Sendable, Comparable {
        
        /// The identifier of the document
        let identifier: String
        /// The type of the document
        let documentType: DocumentType
        /// The title of the document
        let title: String
                
        init(identifier: String, documentType: MarkdownOutputManifest.DocumentType, title: String) {
            self.identifier = identifier
            self.documentType = documentType
            self.title = title
        }
                
        static func < (lhs: MarkdownOutputManifest.Document, rhs: MarkdownOutputManifest.Document) -> Bool {
            lhs.identifier < rhs.identifier
        }
    }
}
