/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation

// Consumers of `MarkdownOutputNode` in other packages should be able to lift this file and be able to use it standalone, without any dependencies from SwiftDocC.

/// A markdown version of a documentation node.
@_spi(MarkdownOutput)
public struct MarkdownOutputNode: Sendable {

    /// The metadata about this node
    public var metadata: Metadata
    /// The markdown content of this node
    public var markdown: String = ""
    
    public init(metadata: Metadata, markdown: String) {
        self.metadata = metadata
        self.markdown = markdown
    }
}

extension MarkdownOutputNode {
    public struct Metadata: Codable, Sendable {
    
        static let version = "0.1.0"
        
        public enum DocumentType: String, Codable, Sendable {
            case article, tutorial, symbol
        }
        
        public struct Availability: Codable, Equatable, Sendable {
            
            public let platform: String
            public let introduced: String?
            public let deprecated: String?
            public let unavailable: Bool
                        
            public init(platform: String, introduced: String? = nil, deprecated: String? = nil, unavailable: Bool) {
                self.platform = platform
                // Can't have deprecated without an introduced
                self.introduced = introduced ?? deprecated
                self.deprecated = deprecated
                // If no introduced, we are unavailable
                self.unavailable = unavailable || introduced == nil
            }
            
            // For a compact representation on-disk and for human and machine readers, availability is stored as a single string:
            // platform: introduced -               (not deprecated)
            // platform: introduced - deprecated    (deprecated)
            // platform: -                          (unavailable)
            public func encode(to encoder: any Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(stringRepresentation)
            }
            
            public init(from decoder: any Decoder) throws {
                let container = try decoder.singleValueContainer()
                let stringRepresentation = try container.decode(String.self)
                self.init(stringRepresentation: stringRepresentation)
            }
            
            public var stringRepresentation: String {
                var stringRepresentation = "\(platform): "
                if unavailable {
                    stringRepresentation += "-"
                } else {
                    if let introduced, introduced.isEmpty == false {
                        stringRepresentation += "\(introduced) -"
                        if let deprecated, deprecated.isEmpty == false {
                            stringRepresentation += " \(deprecated)"
                        }
                    } else {
                        stringRepresentation += "-"
                    }
                }
                return stringRepresentation
            }
            
            public init(stringRepresentation: String) {
                let words = stringRepresentation.split(separator: ":", maxSplits: 1)
                if words.count != 2 {
                    platform = stringRepresentation
                    unavailable = true
                    introduced = nil
                    deprecated = nil
                    return
                }
                platform = String(words[0])
                let available = words[1]
                    .split(separator: "-")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.isEmpty == false }
                
                introduced = available.first
                if available.count > 1 {
                    deprecated = available.last
                } else {
                    deprecated = nil
                }
                
                unavailable = available.isEmpty
            }

        }
        
        public struct Symbol: Codable, Sendable {
            public let kind: String
            public let preciseIdentifier: String
            public let modules: [String]
            
            
            public init(kind: String, preciseIdentifier: String, modules: [String]) {
                self.kind = kind
                self.preciseIdentifier = preciseIdentifier
                self.modules = modules
            }
        }
               
        public let metadataVersion: String
        public let documentType: DocumentType
        public var role: String?
        public let uri: String
        public var title: String
        public let framework: String
        public var symbol: Symbol?
        public var availability: [Availability]?
           
        public init(documentType: DocumentType, uri: String, title: String, framework: String) {
            self.documentType = documentType
            self.metadataVersion = Self.version
            self.uri = uri
            self.title = title
            self.framework = framework
        }
                
        public func availability(for platform: String) -> Availability? {
            availability?.first(where: { $0.platform == platform })
        }
    }
}

// MARK: I/O
extension MarkdownOutputNode {
    /// Data for this node to be rendered to disk
    public var data: Data {
        get throws {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let metadata = try encoder.encode(metadata)
            var data = Data()
            data.append(contentsOf: Self.commentOpen)
            data.append(metadata)
            data.append(contentsOf: Self.commentClose)
            data.append(contentsOf: markdown.utf8)
            return data
        }
    }
    
    private static let commentOpen = "<!--\n".utf8
    private static let commentClose = "\n-->\n\n".utf8
    
    public enum MarkdownOutputNodeDecodingError: Error {
        
        case metadataSectionNotFound
        case metadataDecodingFailed(any Error)
        
        var localizedDescription: String {
            switch self {
            case .metadataSectionNotFound:
                "The data did not contain a metadata section."
            case .metadataDecodingFailed(let error):
                "Metadata decoding failed: \(error.localizedDescription)"
            }
        }
    }
    
    /// Recreates the node from the data exported in ``data``
    public init(_ data: Data) throws {
        guard let open = data.range(of: Data(Self.commentOpen)), let close = data.range(of: Data(Self.commentClose)) else {
            throw MarkdownOutputNodeDecodingError.metadataSectionNotFound
        }
        let metaSection = data[open.endIndex..<close.startIndex]
        do {
            self.metadata = try JSONDecoder().decode(Metadata.self, from: metaSection)
        } catch {
            throw MarkdownOutputNodeDecodingError.metadataDecodingFailed(error)
        }
        
        self.markdown = String(data: data[close.endIndex...], encoding: .utf8) ?? ""
    }
}
