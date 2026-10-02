/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

package import Foundation

/// A markdown version of a documentation node.
package struct MarkdownOutputNode: Sendable {

    /// The metadata about this node
    var metadata: Metadata
    /// The markdown content of this node
    var markdown: String = ""
    
    init(metadata: Metadata, markdown: String) {
        self.metadata = metadata
        self.markdown = markdown
    }
}

extension MarkdownOutputNode {
    struct Metadata: Codable, Sendable {
    
        static let version = SemanticVersion(major: 0, minor: 2, patch: 0)
        
        enum DocumentType: String, Codable, Sendable {
            case article, tutorial, symbol
        }
        
        // Completely unavailable symbols are not included in the documentation output so don't need representation in this structure.
        // It only has to deal with introduced and deprecated versions.
        struct Availability: Codable, Equatable, Sendable {
            
            enum Version: Codable, Equatable, Sendable {
                case unversioned
                case versioned(String)
                
                init(string: String?) {
                    switch string?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    case nil, "", Availability.availableToken, Availability.deprecatedToken:
                        self = .unversioned
                    case .some(let value):
                        self = .versioned(value)
                    }
                }
            }
            
            let platform: String
            /// When the symbol was introduced
            let introduced: Version
            /// When the symbol was deprecated
            let deprecated: Version?
                            
            private static let availableToken = "available"
            private static let deprecatedToken = "deprecated"
            private static let versionSeparator = " - "
            
            init(platform: String, introduced: Version, deprecated: Version? = nil) {
                self.platform = platform
                self.introduced = introduced
                self.deprecated = deprecated
            }
            
            // For a compact representation on-disk and for human and machine readers, availability is stored as a single string:
            // iOS: 14.0                (available from 14.0, not deprecated)
            // iOS: 14.0 - 15.0         (available from 14.0, deprecated at 15.0)
            // iOS: 14.0 - deprecated   (available from 14.0, deprecated unconditionally, no version)
            // iOS: available           (available, no minimum version, not deprecated)
            // iOS: available - 15.0    (available, no minimum version, deprecated at 15.0)
            // iOS: deprecated          (available, no minimum version, deprecated unconditionally, no version)
            func encode(to encoder: any Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(stringRepresentation)
            }
            
            init(from decoder: any Decoder) throws {
                let container = try decoder.singleValueContainer()
                let stringRepresentation = try container.decode(String.self)
                self.init(stringRepresentation: stringRepresentation)
            }
            
            var stringRepresentation: String {
                var stringRepresentation = "\(platform): "
                let versions: [String]
            
                switch (introduced, deprecated) {
                case (.unversioned, nil):
                    versions = [Self.availableToken]
                case (.unversioned, .unversioned):
                    versions = [Self.deprecatedToken]
                case (.unversioned, .versioned(let deprecatedVersion)):
                    versions = [Self.availableToken, deprecatedVersion]
                case (.versioned(let introducedVersion), nil):
                    versions = [introducedVersion]
                case (.versioned(let introducedVersion), .unversioned):
                    versions = [introducedVersion, Self.deprecatedToken]
                case (.versioned(let introducedVersion), .versioned(let deprecatedVersion)):
                    versions = [introducedVersion, deprecatedVersion]
                }
                                    
                stringRepresentation += versions.joined(separator: Self.versionSeparator)
                return stringRepresentation
            }
            
            init(stringRepresentation: String) {
                let words = stringRepresentation.split(separator: ":", maxSplits: 1)
                guard words.count == 2 else {
                    platform = stringRepresentation
                    introduced = .unversioned
                    deprecated = nil
                    return
                }
                platform = String(words[0])
                let available = words[1]
                    .split(separator: Self.versionSeparator)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.isEmpty == false }
                                
                if available.first == Self.deprecatedToken {
                    // Special case where the first version doesn't refer to introduction
                    self.introduced = .unversioned
                    self.deprecated = .unversioned
                } else {
                    self.introduced = Version(string: available.first)
                    if available.count > 1 {
                        self.deprecated = Version(string: available[1])
                    } else {
                        self.deprecated = nil
                    }
                }
            }

        }
        
        struct Symbol: Codable, Sendable {
            let kindDisplayName: String
            let preciseIdentifier: String
            let modules: [String]
            
            enum CodingKeys: String, CodingKey {
                case kindDisplayName = "kind"
                case preciseIdentifier
                case modules
            }
            
            init(kindDisplayName: String, preciseIdentifier: String, modules: [String]) {
                self.kindDisplayName = kindDisplayName
                self.preciseIdentifier = preciseIdentifier
                self.modules = modules
            }
        }
          
        /// A string representation of the metadata version
        let metadataVersion: String
        let documentType: DocumentType
        var role: String?
        let identifier: String
        var title: String
        let framework: String
        var symbol: Symbol?
        var availability: [Availability]?
        var deprecation: String?
           
        init(documentType: DocumentType, identifier: String, title: String, framework: String) {
            self.documentType = documentType
            self.metadataVersion = Self.version.stringRepresentation()
            self.identifier = identifier
            self.title = title
            self.framework = framework
        }
    }
}

// MARK: I/O
extension MarkdownOutputNode {
    /// Data for this node to be rendered to disk as a markdown file. This method renders the metadata as a JSON header wrapped in an HTML comment block, then includes the document content.
    package func generateDataRepresentation() throws -> Data {
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
    
    private static let commentOpen = "<!--\n".utf8
    private static let commentClose = "\n-->\n\n".utf8
    
    package enum MarkdownOutputNodeDecodingError: DescribedError {
        
        case metadataSectionNotFound
        case metadataDecodingFailed(any Error)
        case markdownSectionDecodingFailed
        
        package var errorDescription: String {
            switch self {
            case .metadataSectionNotFound:
                "The data did not contain a metadata section."
            case .metadataDecodingFailed(let error):
                "Metadata decoding failed: \(error.localizedDescription)"
            case .markdownSectionDecodingFailed:
                "Markdown section was not UTF-8 encoded"
            }
        }
    }
    
    /// Recreates the node from the data exported in ``generateDataRepresentation()``
    init(_ data: Data) throws {
        guard let open = data.range(of: Data(Self.commentOpen)), let close = data.range(of: Data(Self.commentClose)) else {
            throw MarkdownOutputNodeDecodingError.metadataSectionNotFound
        }
        let metaSection = data[open.endIndex..<close.startIndex]
        do {
            self.metadata = try JSONDecoder().decode(Metadata.self, from: metaSection)
        } catch {
            throw MarkdownOutputNodeDecodingError.metadataDecodingFailed(error)
        }
        
        guard let markdown = String(data: data[close.endIndex...], encoding: .utf8) else {
            throw MarkdownOutputNodeDecodingError.markdownSectionDecodingFailed
        }
        self.markdown = markdown
    }
}
