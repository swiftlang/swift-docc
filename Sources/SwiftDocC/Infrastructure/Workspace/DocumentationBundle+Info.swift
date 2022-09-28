/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension DocumentationBundle {
    /// Information about a documentation bundle that's unrelated to its documentation content.
    ///
    /// This information is meant to be decoded from the bundle's Info.plist file.
    public struct Info: Codable, Equatable {
        /// The display name of the bundle.
        public var displayName: String
        
        /// The unique identifier of the bundle.
        public var identifier: String
        
        /// The version of the bundle.
        public var version: String?
        
        /// The default language identifier for code listings in the bundle.
        public var defaultCodeListingLanguage: String?
        
        /// The default availability for the various modules in the bundle.
        public var defaultAvailability: DefaultAvailability?
        
        /// The default kind for the various modules in the bundle.
        public var defaultModuleKind: String?
        
        /// The keys that must be present in an Info.plist file in order for doc compilation to proceed.
        static let requiredKeys: Set<CodingKeys> = [.displayName, .identifier]
        
        enum CodingKeys: String, CodingKey, CaseIterable {
            case displayName = "CFBundleDisplayName"
            case identifier = "CFBundleIdentifier"
            case version = "CFBundleVersion"
            case defaultCodeListingLanguage = "CDDefaultCodeListingLanguage"
            case defaultAvailability = "CDAppleDefaultAvailability"
            case defaultModuleKind = "CDDefaultModuleKind"
            
            var argumentName: String? {
                switch self {
                case .displayName:
                    return "--fallback-display-name"
                case .identifier:
                    return "--fallback-bundle-identifier"
                case .version:
                    return "--fallback-bundle-version"
                case .defaultCodeListingLanguage:
                    return "--default-code-listing-language"
                case .defaultModuleKind:
                    return "--fallback-default-module-kind"
                case .defaultAvailability:
                    return nil
                }
            }
        }
        
        enum Error: DescribedError {
            case wrongType(expected: Any.Type, actual: Any.Type)
            case plistDecodingError(_ context: DecodingError.Context)
            
            var errorDescription: String {
                switch self {
                case .wrongType(let expected, let actual):
                    return "Expected '\(expected)', but found '\(actual)'."
                case .plistDecodingError(let context):
                    let message = "Unable to decode Info.plist file. Verify that it is correctly formed."
                    let verboseMessage = ((context.underlyingError as? NSError)?.userInfo["NSDebugDescription"] as? String) ?? context.debugDescription
                    return [message, verboseMessage].joined(separator: " ")
                }
            }
        }
        
        /// Creates documentation bundle information from the given Info.plist data, falling back to the values
        /// in the given bundle discovery options if necessary.
        init(
            from infoPlist: Data? = nil,
            bundleDiscoveryOptions options: BundleDiscoveryOptions? = nil,
            derivedDisplayName: String? = nil
        ) throws {
            if let infoPlist = infoPlist {
                let propertyListDecoder = PropertyListDecoder()
                
                if let options = options {
                    propertyListDecoder.userInfo[.bundleDiscoveryOptions] = options
                }
                
                if let derivedDisplayName = derivedDisplayName {
                    propertyListDecoder.userInfo[.derivedDisplayName] = derivedDisplayName
                }
                
                do {
                    self = try propertyListDecoder.decode(
                        DocumentationBundle.Info.self,
                        from: infoPlist
                    )
                } catch DecodingError.dataCorrupted(let context) {
                    throw Error.plistDecodingError(context)
                }
                
            } else {
                try self.init(
                    with: nil,
                    bundleDiscoveryOptions: options,
                    derivedDisplayName: derivedDisplayName
                )
            }
        }
        
        public init(from decoder: Decoder) throws {
            let bundleDiscoveryOptions = decoder.userInfo[.bundleDiscoveryOptions] as? BundleDiscoveryOptions
            let derivedDisplayName = decoder.userInfo[.derivedDisplayName] as? String
            
            try self.init(
                with: decoder.container(keyedBy: CodingKeys.self),
                bundleDiscoveryOptions: bundleDiscoveryOptions,
                derivedDisplayName: derivedDisplayName
            )
        }
        
        private init(
            with values: KeyedDecodingContainer<DocumentationBundle.Info.CodingKeys>?,
            bundleDiscoveryOptions: BundleDiscoveryOptions?,
            derivedDisplayName: String?
        ) throws {
            // Here we define two helper functions that simplify
            // the decoding logic where we'll need to first check if the value
            // is in the Codable container, and then fall back to the
            // Info.plist fallbacks in the bundle discovery options if necessary.
            
            /// Helper function that decodes a value of the given type for the given key,
            /// if present in either the Codable container or Info.plist fallbacks.
            func decodeOrFallbackIfPresent<T>(
                _ expectedType: T.Type,
                with key: CodingKeys
            ) throws -> T? where T : Decodable {
                try values?.decodeIfPresent(T.self, forKey: key)
                    ?? bundleDiscoveryOptions?.infoPlistFallbacks.decodeIfPresent(T.self, forKey: key.rawValue)
            }
            
            /// Helper function that decodes a value of the given type for the given key
            /// in either the Codable container or Info.plist fallbacks.
            func decodeOrFallback<T>(
                _ expectedType: T.Type,
                with key: CodingKeys
            ) throws -> T where T : Decodable {
                if let bundleDiscoveryOptions = bundleDiscoveryOptions {
                    return try values?.decodeIfPresent(T.self, forKey: key)
                    ?? bundleDiscoveryOptions.infoPlistFallbacks.decode(T.self, forKey: key.rawValue)
                } else if let values = values {
                    return try values.decode(T.self, forKey: key)
                } else {
                    throw DocumentationBundle.PropertyListError.keyNotFound(key.rawValue)
                }
            }
            
            // Before decoding, confirm that all required keys are present
            // in either the decoding container or Info.plist fallbacks.
            //
            // This allows us to throw a more comprehensive error that includes
            // **all** missing required keys, instead of just the first one hit.
            
            var givenKeys = Set(values?.allKeys ?? []).union(
                bundleDiscoveryOptions?.infoPlistFallbacks.keys.compactMap {
                    CodingKeys(stringValue: $0)
                } ?? []
            )
            
            // If present, we can use `Info.displayName` as a fallback
            // for `Info.identifier`.
            if givenKeys.contains(.displayName) {
                givenKeys.insert(.identifier)
            }
            
            // If present, we can use the `derivedDisplayName`
            // as a fallback for the `Info.displayName` and `Info.identifier`.
            if derivedDisplayName != nil {
                givenKeys.formUnion([.displayName, .identifier])
            }
            
            let missingKeys = Self.requiredKeys.subtracting(givenKeys)
            
            guard missingKeys.isEmpty else {
                throw TypedValueError.missingRequiredKeys(missingKeys.sorted(by: \.rawValue))
            }
            
            // Now that we've confirmed that all keys are here, begin
            // by decoding the required keys, throwing an error if we fail to
            // decode them for some reason.
            
            // It's safe to unwrap `derivedDisplayName` because it will only be accessed if neither the decoding container nor the bundle discovery options
            // contain a display name. If they do but that value fails to decode, that error would be raised before accessing `derivedDisplayName`.
            self.displayName = try decodeOrFallbackIfPresent(String.self, with: .displayName) ?? derivedDisplayName!
            self.identifier = try decodeOrFallbackIfPresent(String.self, with: .identifier) ?? self.displayName
            self.version = try decodeOrFallbackIfPresent(String.self, with: .version)
            
            // Finally, decode the optional keys if they're present.
            
            self.defaultCodeListingLanguage = try decodeOrFallbackIfPresent(String.self, with: .defaultCodeListingLanguage)
            self.defaultModuleKind = try decodeOrFallbackIfPresent(String.self, with: .defaultModuleKind)
            self.defaultAvailability = try decodeOrFallbackIfPresent(DefaultAvailability.self, with: .defaultAvailability)
        }
        
        init(
            displayName: String,
            identifier: String,
            version: String? = nil,
            defaultCodeListingLanguage: String? = nil,
            defaultModuleKind: String? = nil,
            defaultAvailability: DefaultAvailability? = nil
        ) {
            self.displayName = displayName
            self.identifier = identifier
            self.version = version
            self.defaultCodeListingLanguage = defaultCodeListingLanguage
            self.defaultModuleKind = defaultModuleKind
            self.defaultAvailability = defaultAvailability
        }
    }
}

extension BundleDiscoveryOptions {
    /// Creates new bundle discovery options with the given information.
    ///
    /// The given fallback values will be used if any of the discovered bundles are missing that
    /// value in their Info.plist configuration file.
    ///
    /// - Parameters:
    ///   - fallbackDisplayName: A fallback display name for the bundle.
    ///   - fallbackIdentifier: A fallback identifier for the bundle.
    ///   - fallbackVersion: A fallback version for the bundle.
    ///   - fallbackDefaultCodeListingLanguage: A fallback default code listing language for the bundle.
    ///   - fallbackDefaultAvailability: A fallback default availability for the bundle.
    ///   - additionalSymbolGraphFiles: Additional symbol graph files to augment any discovered bundles.
    public init(
        fallbackDisplayName: String? = nil,
        fallbackIdentifier: String? = nil,
        fallbackVersion: String? = nil,
        fallbackDefaultCodeListingLanguage: String? = nil,
        fallbackDefaultModuleKind: String? = nil,
        fallbackDefaultAvailability: DefaultAvailability? = nil,
        additionalSymbolGraphFiles: [URL] = []
    ) {
        // Iterate over all possible coding keys with a switch
        // to build up the dictionary of fallback options.
        // This ensures that when new coding keys are added, the compiler will enforce
        // that we handle them here as well.
        
        let fallbacks = DocumentationBundle.Info.CodingKeys.allCases.compactMap { key -> (String, Any)? in
            let value: Any?
            
            switch key {
            case .displayName:
                value = fallbackDisplayName
            case .identifier:
                value = fallbackIdentifier
            case .version:
                value = fallbackVersion
            case .defaultCodeListingLanguage:
                value = fallbackDefaultCodeListingLanguage
            case .defaultAvailability:
                value = fallbackDefaultAvailability
            case .defaultModuleKind:
                value = fallbackDefaultModuleKind
            }
            
            guard let unwrappedValue = value else {
                return nil
            }
            
            return (key.rawValue, unwrappedValue)
        }
        
        self.init(
            infoPlistFallbacks: Dictionary(uniqueKeysWithValues: fallbacks),
            additionalSymbolGraphFiles: additionalSymbolGraphFiles
        )
    }
}

private extension CodingUserInfoKey {
    /// A user info key to store bundle discovery options in the decoder.
    static let bundleDiscoveryOptions = CodingUserInfoKey(rawValue: "bundleDiscoveryOptions")!
    /// A user info key to store derived display name in the decoder.
    static let derivedDisplayName = CodingUserInfoKey(rawValue: "derivedDisplayName")!
}
