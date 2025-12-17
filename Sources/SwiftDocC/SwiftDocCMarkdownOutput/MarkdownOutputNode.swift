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
    package var metadata: Metadata
    /// The markdown content of this node
    package var markdown: String = ""
    
    package init(metadata: Metadata, markdown: String) {
        self.metadata = metadata
        self.markdown = markdown
    }
}

extension MarkdownOutputNode {
    package struct Metadata: Codable, Sendable {
    
        static let version = SemanticVersion(major: 0, minor: 1, patch: 0)
        
        package enum DocumentType: String, Codable, Sendable {
            case article, tutorial, symbol
        }
        
        package struct Availability: Codable, Equatable, Sendable {
            
            package let platform: String
            /// A string representation of the introduced version
            package let introduced: String?
            /// A string representation of the deprecated version
            package let deprecated: String?
            package let unavailable: Bool
                        
            package init(platform: String, introduced: String? = nil, deprecated: String? = nil, unavailable: Bool) {
                self.platform = platform
                self.introduced = introduced
                self.deprecated = deprecated
                self.unavailable = unavailable
            }
            
            // For a compact representation on-disk and for human and machine readers, availability is stored as a single string:
            // platform: introduced -               (not deprecated)
            // platform: introduced - deprecated    (deprecated)
            // platform: -                          (unavailable)
            package func encode(to encoder: any Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(stringRepresentation)
            }
            
            package init(from decoder: any Decoder) throws {
                let container = try decoder.singleValueContainer()
                let stringRepresentation = try container.decode(String.self)
                self.init(stringRepresentation: stringRepresentation)
            }
            
            package var stringRepresentation: String {
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
            
            package init(stringRepresentation: String) {
                let words = stringRepresentation.split(separator: ":", maxSplits: 1)
                guard words.count == 2 else {
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
        
        package struct Symbol: Codable, Sendable {
            package let kindDisplayName: String
            package let preciseIdentifier: String
            package let modules: [String]
            
            package enum CodingKeys: String, CodingKey {
                case kindDisplayName = "kind"
                case preciseIdentifier
                case modules
            }
            
            package init(kindDisplayName: String, preciseIdentifier: String, modules: [String]) {
                self.kindDisplayName = kindDisplayName
                self.preciseIdentifier = preciseIdentifier
                self.modules = modules
            }
        }
          
        /// A string representation of the metadata version
        package let metadataVersion: String
        package let documentType: DocumentType
        package var role: String?
        package let identifier: String
        package var title: String
        package let framework: String
        package var symbol: Symbol?
        package var availability: [Availability]?
           
        package init(documentType: DocumentType, identifier: String, title: String, framework: String) {
            self.documentType = documentType
            self.metadataVersion = Self.version.stringRepresentation()
            self.identifier = identifier
            self.title = title
            self.framework = framework
        }
                
        package func availability(for platform: String) -> Availability? {
            availability?.first(where: { $0.platform == platform })
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
    
    /// Recreates the node from the data exported in ``data``
    package init(_ data: Data) throws {
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
