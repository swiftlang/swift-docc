/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension MarkdownOutputNode {
    public struct Metadata: Codable {
    
        static let version = SemanticVersion(major: 0, minor: 1, patch: 0)
        public enum DocumentType: String, Codable {
            case article, tutorial, symbol
        }
        
        public struct Availability: Codable, Equatable {
            let platform: String
            let introduced: String?
            let deprecated: String?
            let unavailable: String?
        }
        
        public let version: String
        public let documentType: DocumentType
        public let uri: String
        public var title: String
        public let framework: String
        public var symbolKind: String?
        public var symbolAvailability: [Availability]?
        
        public init(documentType: DocumentType, bundle: DocumentationBundle, reference: ResolvedTopicReference) {
            self.documentType = documentType
            self.version = Self.version.description
            self.uri = reference.path
            self.title = reference.lastPathComponent
            self.framework = bundle.displayName
        }
    }
    
}
