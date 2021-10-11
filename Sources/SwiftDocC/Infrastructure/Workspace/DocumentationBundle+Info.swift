/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension DocumentationBundle {
    /// Information about a documentation bundle that's unrelated to its documentation content.
    ///
    /// This information is meant to be decoded from the bundle's Info.plist file.
    struct Info {
        
        /// Represents a key in an Info.plist file.
        struct Key {
            let rawValue: String
            let argumentName: String
            
            /// The display name of a bundle
            static let bundleDisplayName = Key(rawValue: "CFBundleDisplayName", argumentName: "--fallback-display-name")
            /// A reverse-DNS style bundle identifier
            static let bundleIdentifier = Key(rawValue: "CFBundleIdentifier", argumentName: "--fallback-bundle-identifier")
            /// A version number for a bundle
            static let bundleVersion = Key(rawValue: "CFBundleVersion", argumentName: "--fallback-bundle-version")
            /// The default code language for code listings in a bundle
            static let defaultCodeListingLanaguage = Key(rawValue: "CDDefaultCodeListingLanguage", argumentName: "--default-code-listing-language")
        }
        
        /// The display name of the bundle.
        let displayName: String
        /// The unique identifier of the bundle.
        let identifier: String
        /// The version of the bundle.
        let version: Version
        /// The default language identifier for code listings in the bundle.
        let defaultCodeListingLanguage: String?
        /// The default availability for the various modules in the bundle.
        let defaultAvailability: DefaultAvailability?
        
        /// The keys that must be present in an Info.plist file in order for doc compilation to proceed.
        static let requiredKeys: [Key] = [.bundleDisplayName, .bundleIdentifier, .bundleVersion]
        
        /// Parses a property list dictionary mapping into a new info value.
        ///
        /// - Parameter infoPlist: The property list dictionary to parse.
        /// - Throws: If the property list dictionary is missing required values or contains invalid data.
        init(plist infoPlist: [String: Any]) throws {
            let missingKeys = Self.requiredKeys
                .filter({ !infoPlist.keys.contains($0.rawValue) })
                .sorted(by: { $0.rawValue < $1.rawValue })
            
            guard missingKeys.isEmpty else {
                throw TypedValueError.missingRequiredKeys(missingKeys)
            }
            
            displayName = try infoPlist.typedValue(forKey: .bundleDisplayName)
            identifier = try infoPlist.typedValue(forKey: .bundleIdentifier)
            defaultCodeListingLanguage = try? infoPlist.typedValue(forKey: .defaultCodeListingLanaguage)
            
            if let availabilityPropertyList: [String: [[String: String]]] = try? infoPlist.typedValue(forKey: "CDAppleDefaultAvailability") {
                defaultAvailability = try DefaultAvailability(parsingPropertyList: availabilityPropertyList)
            } else {
                defaultAvailability = nil
            }
            
            let versionString: String = try infoPlist.typedValue(forKey: .bundleVersion)
            guard let version = Version(versionString: versionString) else {
                throw DocumentationBundle.PropertyListError.invalidVersionString(versionString)
            }
            self.version = version
        }
    }
}

fileprivate extension Dictionary where Key == String, Value == Any {
    func typedValue<T>(forKey key: DocumentationBundle.Info.Key) throws -> T {
        return try typedValue(forKey: key.rawValue)
    }
}
