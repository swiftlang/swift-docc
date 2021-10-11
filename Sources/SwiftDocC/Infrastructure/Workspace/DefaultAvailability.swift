/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A collection of modules and the default platform availability for symbols in that module.
///
/// Default availability is used as a fallback value for symbols without explicit availability information.
///
/// This information can be authored in the bundle's Info.plist file, as a dictionary of module names to arrays of platform "name" and "version" pairs:
/// ```
/// <key>CDAppleDefaultAvailability</key>
/// <dict>
///     <key>Module Name</key>
///     <array>
///         <dict>
///             <key>name</key>
///             <string>Platform Name</string>
///             <key>version</key>
///             <string>Version Number</string>
///         </dict>
///     </array>
/// </dict>
/// ```
public struct DefaultAvailability {

    /// A platform name and version number pair.
    public struct ModuleAvailability: Hashable {
        /// The keys to use when decoding the platform name and version from property list content.
        private enum Keys: String {
            case name, version
        }

        /// The name of the platform, e.g. "macOS".
        public var platformName: PlatformName

        // FIXME: Should this use `Foundation.OperatingSystemVersion` or something similar?

        /// A string representation of the version for this platform.
        public var platformVersion: String

        /// Create a new module availability with a given platform name and platform version.
        ///
        /// - Parameters:
        ///   - platformName: A platform name, such as "iOS" or "macOS"; see ``PlatformName``.
        ///   - platformVersion: A 2- or 3-component version string, such as `"13.0"` or `"13.1.2"`
        init(platformName: PlatformName, platformVersion: String) {
            self.platformName = platformName
            self.platformVersion = platformVersion
        }

        /// Parses a property list dictionary containing a single platform name-version pair into a new module availability.
        ///
        /// - Parameter availability: The property list dictionary to parse.
        /// - Throws: A ``DocumentationBundle/PropertyListError/keyNotFound`` error if the is property list dictionary is missing values or
        ///           a ``DocumentationBundle/PropertyListError/invalidVersionString`` error if the version string is invalid.
        init(parsingPropertyList availability: [String: String]) throws {
            guard let name = availability[Keys.name.rawValue] else {
                throw DocumentationBundle.PropertyListError.keyNotFound(Keys.name.rawValue)
            }
            guard let versionString = availability[Keys.version.rawValue] else {
                throw DocumentationBundle.PropertyListError.keyNotFound(Keys.version.rawValue)
            }
            guard let version = Version(versionString: versionString), (2...3).contains(version.count) else {
                throw DocumentationBundle.PropertyListError.invalidVersionString(versionString)
            }
            
            platformName = PlatformName(operatingSystemName: name)
            platformVersion = versionString
        }
    }

    /// A map of modules and the default platform availability for symbols in that module.
    ///
    /// For example: "ModuleName" -> ["macOS 10.15", "iOS 13.0"]
    var modules: [String: [ModuleAvailability]]

    /// Parses a property list dictionary mapping modules to platform-version pairs into a new default availability.
    ///
    /// - Parameter modules: The property list dictionary to parse.
    ///
    /// The property list dictionary must follow this format:
    /// ```swift
    /// [
    ///   "ModuleName": [
    ///     ["iOS": "13.0"],
    ///     ["macOS": "10.15"],
    ///     // additional platforms ...
    ///   ],
    ///   // additional modules ...
    /// ]
    /// ```
    init(parsingPropertyList modules: [String: [[String: String]]]) throws {
        self.modules = try modules.reduce(into: [String: [ModuleAvailability]](), { result, module in
            result[module.key] = try module.value.map(ModuleAvailability.init(parsingPropertyList:))
        })
        .mapValues { platformAvailabilities -> [DefaultAvailability.ModuleAvailability] in
            // If a module doesn't contain default introduced availability for macCatalyst,
            // infer it from iOS. Their platform versions are always the same.
            if !platformAvailabilities.contains(where: { $0.platformName == .catalyst }),
                let iOSAvailability = platformAvailabilities.first(where: { $0.platformName == .iOS } ) {
                return platformAvailabilities + [
                    DefaultAvailability.ModuleAvailability(platformName: .catalyst, platformVersion: iOSAvailability.platformVersion)
                ]
            } else {
                return platformAvailabilities
            }
        }
    }
}
