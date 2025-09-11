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
        
        public struct Symbol: Codable {
                       
            public let availability: [Availability]?
            public let kind: String
            public let preciseIdentifier: String
            public let modules: [String]
            
            public struct Availability: Codable, Equatable {

                let platform: String
                let introduced: String?
                let deprecated: String?
                let unavailable: Bool
                
                public init(platform: String, introduced: String? = nil, deprecated: String? = nil, unavailable: Bool) {
                    self.platform = platform
                    self.introduced = introduced
                    self.deprecated = deprecated
                    self.unavailable = unavailable
                }
            }
            
            public init(availability: [MarkdownOutputNode.Metadata.Symbol.Availability]? = nil, kind: String, preciseIdentifier: String, modules: [String]) {
                self.availability = availability
                self.kind = kind
                self.preciseIdentifier = preciseIdentifier
                self.modules = modules
            }
            
            public func availability(for platform: String) -> Availability? {
                availability?.first(where: { $0.platform == platform })
            }
        }
               
        public let metadataVersion: String
        public let documentType: DocumentType
        public var role: String?
        public let uri: String
        public var title: String
        public let framework: String
        public var symbol: Symbol?
                
        public init(documentType: DocumentType, bundle: DocumentationBundle, reference: ResolvedTopicReference) {
            self.documentType = documentType
            self.metadataVersion = Self.version.description
            self.uri = reference.path
            self.title = reference.lastPathComponent
            self.framework = bundle.displayName
        }
    }
    
}
