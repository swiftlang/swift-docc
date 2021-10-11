/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// An environmental variable to control the output formatting of the encoded render JSON.
///
/// If this environment variable is set to "YES", DocC will format render node JSON with spacing and indentation to make it easy to read.
let jsonFormattingKey = "DOCC_JSON_PRETTYPRINT"
public let shouldPrettyPrintOutputJSON = NSString(string: ProcessInfo.processInfo.environment[jsonFormattingKey] ?? "NO").boolValue

public extension CodingUserInfoKey {
    // A user info key to store topic reference cache in `JSONEncoder`.
    static let renderReferenceCache = CodingUserInfoKey(rawValue: "renderReferenceCache")!
}

/// A namespace for encoders for render node JSON.
enum RenderJSONEncoder {
    /// Creates a new JSON encoder for render node values.
    ///
    /// - Parameter prettyPrint: If `true`, the encoder formats its output to make it easy to read; if `false`, the output is compact.
    /// - Returns: The new JSON encoder.
    static func encoder(prettyPrint: Bool) -> JSONEncoder {
        let encoder = JSONEncoder()
        if prettyPrint {
            if #available(OSX 10.13, *) {
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            } else {
                encoder.outputFormatting = [.prettyPrinted]
            }
        }
        return encoder
    }
}

// This API improves the encoding/decoding to or from JSON with better error messages.
public extension RenderNode {
    /// The default decoder for render node JSON.
    static var defaultJSONDecoder = JSONDecoder()
    /// The default encoder for render node JSON.
    static var defaultJSONEncoder = RenderJSONEncoder.encoder(
        prettyPrint: shouldPrettyPrintOutputJSON
    )

    /// An error that describes failures that may occur while encoding or decoding a render node.
    enum CodingError: DescribedError {
        /// JSON data could not be decoded as a render node value.
        case decoding(description: String, context: DecodingError.Context)
        /// A render node value could not be encoded as JSON.
        case encoding(description: String, context: EncodingError.Context)
        
        /// A user-facing description of the coding error.
        public var errorDescription: String {
            switch self {
            case .decoding(let description, let context):
                let contextMessage = context.codingPath.map { $0.stringValue }.joined(separator: ", ")
                if contextMessage.isEmpty { return description }
                return "\(description)\nKeypath: \(contextMessage)"
            case .encoding(let description, let context):
                let contextMessage = context.codingPath.map { $0.stringValue }.joined(separator: ", ")
                if contextMessage.isEmpty { return description }
                return "\(description)\nKeypath: \(contextMessage)"
            }
        }
        
    }
    
    /// Decodes a render node value from the given JSON data.
    ///
    /// - Parameters:
    ///   - data: The JSON data to decode.
    ///   - decoder: The object that decodes the JSON data.
    /// - Throws: A ``CodingError`` in case the decoder is unable to find a key or value in the data, the type of a decoded value is wrong, or the data is corrupted.
    /// - Returns: The decoded render node value.
    static func decode(fromJSON data: Data, with decoder: JSONDecoder = RenderNode.defaultJSONDecoder) throws -> RenderNode {
        do {
            return try decoder.decode(RenderNode.self, from: data)
        } catch {
            if let error = error as? DecodingError {
                switch error {
                case .dataCorrupted(let context):
                    throw CodingError.decoding(description: "\(error.localizedDescription)\n\(context.debugDescription)", context: context)
                case .keyNotFound(let key, let context):
                    throw CodingError.decoding(description: "\(error.localizedDescription)\nKey: \(key.stringValue).\n\(context.debugDescription)", context: context)
                case .valueNotFound(_, let context):
                    throw CodingError.decoding(description: "\(error.localizedDescription)\n\(context.debugDescription)", context: context)
                case .typeMismatch(_, let context):
                    throw CodingError.decoding(description: "\(error.localizedDescription)\n\(context.debugDescription)", context: context)
                @unknown default:
                    // Re-throws if an unknown decoding error happens.
                    throw error
                }
            }
            // Re-throws if any other error happens.
            throw error
        }
    }
    
    /// Encodes a render node value as JSON data.
    ///
    /// - Parameter encoder: The object that encodes the render node.
    /// - Throws: A ``CodingError`` in case the encoder couldn't encode the render node.
    /// - Returns: The data for the encoded render node.
    func encodeToJSON(with encoder: JSONEncoder = RenderNode.defaultJSONEncoder) throws -> Data {
        do {
            // If there is no topic reference cache, just encode the reference.
            // To skim a little off the duration we first do a quick check if the key is present at all.
            guard encoder.userInfo.keys.contains(.renderReferenceCache) else {
                return try encoder.encode(self)
            }
            
            // Encode the render node as usual. `RenderNode` will skip encoding the references itself
            // because the `.renderReferenceCache` key is set.
            var renderNodeData = try encoder.encode(self)
            
            // Add render references, using the encoder cache.
            TopicRenderReferenceEncoder.addRenderReferences(
                to: &renderNodeData,
                references: references,
                encoder: encoder
            )
            
            return renderNodeData

        } catch {
            if let error = error as? EncodingError {
                switch error {
                case .invalidValue(_, let context):
                    throw CodingError.encoding(description: "\(error.localizedDescription)\n\(context.debugDescription)", context: context)
                @unknown default:
                    // Re-throws if an unknown encoding error happens.
                    throw error
                }
            }
            
            // Re-throws if any other error happens.
            throw error
        }
    }
}
