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
/// If this environment variable is set to "YES", DocC will format render node JSON with spacing and indentation,
/// and sort the keys (on supported platforms), to make it deterministic and easy to read.
let jsonFormattingKey = "DOCC_JSON_PRETTYPRINT"
public internal(set) var shouldPrettyPrintOutputJSON = NSString(string: ProcessInfo.processInfo.environment[jsonFormattingKey] ?? "NO").boolValue

extension CodingUserInfoKey {
    /// A user info key to indicate that Render JSON references should not be encoded.
    static let skipsEncodingReferences = CodingUserInfoKey(rawValue: "skipsEncodingReferences")!
    
    /// A user info key that encapsulates variant overrides.
    ///
    /// This key is used by encoders to accumulate language-specific variants of documentation in a ``VariantOverrides`` value.
    static let variantOverrides = CodingUserInfoKey(rawValue: "variantOverrides")!
    
    static let baseEncodingPath = CodingUserInfoKey(rawValue: "baseEncodingPath")!
}

extension Encoder {
    /// The variant overrides accumulated as part of the encoding process.
    var userInfoVariantOverrides: VariantOverrides? {
        userInfo[.variantOverrides] as? VariantOverrides
    }
    
    /// The base path to use when creating dynamic JSON pointers
    /// with this encoder.
    var baseJSONPatchPath: [String]? {
        userInfo[.baseEncodingPath] as? [String]
    }
    
    /// A Boolean that is true if this encoder skips the encoding of any render references.
    ///
    /// These references will then be encoded at a later stage by `TopicRenderReferenceEncoder`.
    var skipsEncodingReferences: Bool {
        guard let userInfoValue = userInfo[.skipsEncodingReferences] as? Bool else {
            // The value doesn't exist so we should encode reference. Return false.
            return false
        }
        
        return userInfoValue
    }
}

extension JSONEncoder {
    /// The variant overrides accumulated as part of the encoding process.
    var userInfoVariantOverrides: VariantOverrides? {
        get {
            userInfo[.variantOverrides] as? VariantOverrides
        }
        set {
            userInfo[.variantOverrides] = newValue
        }
    }
    
    /// The base path to use when creating dynamic JSON pointers
    /// with this encoder.
    var baseJSONPatchPath: [String]? {
        get {
            userInfo[.baseEncodingPath] as? [String]
        }
        set {
            userInfo[.baseEncodingPath] = newValue
        }
    }
    
    /// A Boolean that is true if this encoder skips the encoding any render references.
    ///
    /// These references will then be encoded at a later stage by `TopicRenderReferenceEncoder`.
    var skipsEncodingReferences: Bool {
        get {
            guard let userInfoValue = userInfo[.skipsEncodingReferences] as? Bool else {
                // The value doesn't exist so we should encode reference. Return false.
                return false
            }
            
            return userInfoValue
        }
        set {
            userInfo[.skipsEncodingReferences] = newValue
        }
    }
}

/// A namespace for encoders for render node JSON.
public enum RenderJSONEncoder {
    /// Creates a new JSON encoder for render node values.
    ///
    /// Returns an encoder that's configured to encode ``RenderNode`` values.
    ///
    /// > Important: Don't reuse encoders returned by this function to encode multiple render nodes, as the encoder accumulates state during the encoding
    /// process which should not be shared in other encoding units. Instead, call this API to create a new encoder for each render node you want to encode.
    ///
    /// - Parameters:
    ///     - prettyPrint: If `true`, the encoder formats its output to make it easy to read; if `false`, the output is compact.
    ///     - emitVariantOverrides: Whether the encoder should emit the top-level ``RenderNode/variantOverrides`` property that holds language-
    ///     specific documentation data.
    /// - Returns: The new JSON encoder.
    public static func makeEncoder(
        prettyPrint: Bool = shouldPrettyPrintOutputJSON,
        emitVariantOverrides: Bool = true
    ) -> JSONEncoder {
        let encoder = JSONEncoder()
        
        if prettyPrint {
            if #available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *) {
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            } else {
                encoder.outputFormatting = [.prettyPrinted]
            }
        }
        
        if emitVariantOverrides {
            encoder.userInfo[.variantOverrides] = VariantOverrides()
        }
        
        return encoder
    }
}

/// A namespace for decoders for render node JSON.
public enum RenderJSONDecoder {
    /// Creates a new JSON decoder for render node values.
    ///
    /// - Returns: The new JSON decoder.
    public static func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }
}

// This API improves the encoding/decoding to or from JSON with better error messages.
public extension RenderNode {
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
    static func decode(fromJSON data: Data, with decoder: JSONDecoder = RenderJSONDecoder.makeDecoder()) throws -> RenderNode {
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
    /// - Parameters:
    ///     - encoder: The object that encodes the render node.
    ///     - renderReferenceCache: A cache for encoded render reference data. When encoding a large number of render nodes, use the same cache instance
    ///     to avoid encoding the same reference objects repeatedly.
    /// - Throws: A ``CodingError`` in case the encoder couldn't encode the render node.
    /// - Returns: The data for the encoded render node.
    func encodeToJSON(
        with encoder: JSONEncoder = RenderJSONEncoder.makeEncoder(),
        renderReferenceCache: RenderReferenceCache? = nil
    ) throws -> Data {
        do {
            // If there is no topic reference cache, just encode the reference.
            // To skim a little off the duration we first do a quick check if the key is present at all.
            guard let renderReferenceCache = renderReferenceCache else {
                return try encoder.encode(self)
            }
            
            // Since we're using a reference cache, skip encoding the references and encode them separately.
            encoder.skipsEncodingReferences = true
            var renderNodeData = try encoder.encode(self)
            
            // Add render references, using the encoder cache.
            try TopicRenderReferenceEncoder.addRenderReferences(
                to: &renderNodeData,
                references: references,
                encodeAccumulatedVariantOverrides: variantOverrides == nil,
                encoder: encoder,
                renderReferenceCache: renderReferenceCache
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
