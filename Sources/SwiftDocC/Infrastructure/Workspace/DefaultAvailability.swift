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
public struct DefaultAvailability: Codable, Equatable {

    /// A platform name and version number pair.
    public struct ModuleAvailability: Codable, Hashable {
        enum CodingKeys: String, CodingKey {
            case platformName = "name"
            case platformVersion = "version"
        }

        /// The name of the platform, e.g. "macOS".
        public var platformName: PlatformName

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

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            platformName = try values.decode(PlatformName.self, forKey: .platformName)
            platformVersion = try values.decode(String.self, forKey: .platformVersion)
            
            guard let version = Version(versionString: platformVersion), (2...3).contains(version.count) else {
                throw DocumentationBundle.PropertyListError.invalidVersionString(platformVersion)
            }
        }
    }

    /// A map of modules and the default platform availability for symbols in that module.
    ///
    /// For example: "ModuleName" -> ["macOS 10.15", "iOS 13.0"]
    var modules: [String: [ModuleAvailability]]

    init(with modules: [String: [ModuleAvailability]]) {
        self.modules = modules.mapValues { platformAvailabilities -> [DefaultAvailability.ModuleAvailability] in
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let modules = try container.decode([String: [ModuleAvailability]].self)
        self.init(with: modules)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(modules)
    }
}
