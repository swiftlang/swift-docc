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
    package let manifestVersion: SemanticVersion
    /// The manifest title, this will typically match the module that the manifest is generated for
    package let title: String
    /// All documents contained in the manifest
    package var documents: Set<Document>
    /// Relationships involving documents in the manifest
    package var relationships: Set<Relationship>
    
    package init(title: String, documents: Set<Document> = [], relationships: Set<Relationship> = []) {
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
    
    package enum DocumentType: String, Codable, Sendable {
        case article, tutorial, symbol
    }
    
    package enum RelationshipType: String, Codable, Sendable {
        /// For this relationship, the source URI will be the URI of a document, and the target URI will be the topic to which it belongs
        case belongsToTopic
        /// For this relationship, the source and target URIs will be indicated by the directionality of the subtype, e.g. source "conformsTo" target. 
        case relatedSymbol
    }
    
    package enum RelationshipSubType: String, Codable, Sendable {
        /// One or more protocols to which a type conforms.
        case conformsTo
        /// One or more types that conform to a protocol.
        case conformingTypes
        /// One or more types that are parents of the symbol.
        case inheritsFrom
        /// One or more types that are children of the symbol.
        case inheritedBy
    }
    
    /// A relationship between two documents in the manifest.
    ///
    /// Parent / child symbol relationships are not included here, because those relationships are implicit in the identifier structure of the documents. See ``children(of:)``.
    package struct Relationship: Codable, Hashable, Sendable, Comparable {
        
        package let sourceIdentifier: String
        package let relationshipType: RelationshipType
        package let subtype: RelationshipSubType?
        package let targetIdentifier: String
        
        package init(sourceIdentifier: String, relationshipType: MarkdownOutputManifest.RelationshipType, subtype: RelationshipSubType? = nil, targetIdentifier: String) {
            self.sourceIdentifier = sourceIdentifier
            self.relationshipType = relationshipType
            self.subtype = subtype
            self.targetIdentifier = targetIdentifier
        }
        
        package static func < (lhs: MarkdownOutputManifest.Relationship, rhs: MarkdownOutputManifest.Relationship) -> Bool {
            if lhs.sourceIdentifier < rhs.sourceIdentifier {
                return true
            } else if lhs.sourceIdentifier == rhs.sourceIdentifier {
                return lhs.targetIdentifier < rhs.targetIdentifier
            } else {
                return false
            }
        }
    }
    
    package struct Document: Codable, Hashable, Sendable, Comparable {
        
        /// The identifier of the document
        package let identifier: String
        /// The type of the document
        package let documentType: DocumentType
        /// The title of the document
        package let title: String
                
        package init(identifier: String, documentType: MarkdownOutputManifest.DocumentType, title: String) {
            self.identifier = identifier
            self.documentType = documentType
            self.title = title
        }
                
        package static func < (lhs: MarkdownOutputManifest.Document, rhs: MarkdownOutputManifest.Document) -> Bool {
            lhs.identifier < rhs.identifier
        }
    }
    
    /// All documents in the manifest that have a given document as a parent, e.g. Framework/Symbol/property is a child of Framework/Symbol
    package func children(of parent: Document) -> Set<Document> {
        let parentPrefix = parent.identifier + "/"
        let prefixEnd = parentPrefix.endIndex
        return documents.filter { document in
            guard document.identifier.hasPrefix(parentPrefix) else {
                return false
            }
            let components = document.identifier[prefixEnd...].components(separatedBy: "/")
            return components.count == 1
        }
    }
}
