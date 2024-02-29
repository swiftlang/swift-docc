/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A collection of modules and the default platform availability for symbols in that module.
///
/// Default availability is used as a fallback value for symbols without explicit availability information.
///
/// This information can be authored in the bundle's Info.plist file, as a dictionary of module names to arrays of platform "name" and "version" pairs,
/// or in the case where the platform in uncodinionally unavailable, "name" and "unavailable" pairs:
///
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
///         <dict>
///             <key>name</key>
///             <string>Other Platform Name</string>
///             <key>unavailable</key>
///             <true/>
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
            case unavailable
        }
        
        /// The diferent availability states that can be declared.
        /// Unavailable or Available with an introduced version.
        internal enum State: Hashable {
            case unavailable
            case available(version: String)
        }

        /// The name of the platform, e.g. "macOS".
        public var platformName: PlatformName
        
        /// The availability state, e.g unavailable
        internal var state: State

        /// A string representation of the version for this platform.
        @available(*, deprecated, message: "Use `introducedVersion` instead.  This deprecated API will be removed after 5.11 is released", renamed: "introducedVersion")
        public var platformVersion: String {
            return introducedVersion ?? "0.0"
        }
        
        /// A string representation of the version for this platform
        /// or nil if it's unavailable.
        public var introducedVersion: String? {
            switch state {
            case .available(let introduced):
                return introduced.description
            case .unavailable:
                return nil
            }
        }

        /// Creates a new module availability with a given platform name and platform version.
        ///
        /// - Parameters:
        ///   - platformName: A platform name, such as "iOS" or "macOS"; see ``PlatformName``.
        ///   - platformVersion: A 2- or 3-component version string, such as `"13.0"` or `"13.1.2"`.
        public init(platformName: PlatformName, platformVersion: String) {
            self.platformName = platformName
            self.state = .available(version: platformVersion)
        }
        
        /// Creates a new module availability with a given platform name and platform availability set as unavailable.
        ///
        /// - Parameters:
        ///   - platformName: A platform name, such as "iOS" or "macOS"; see ``PlatformName``.
        public init(unavailablePlatformName: PlatformName) {
            self.platformName = unavailablePlatformName
            self.state = .unavailable
        }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            platformName = try values.decode(PlatformName.self, forKey: .platformName)
            if let unavailable = try values.decodeIfPresent(Bool.self, forKey: .unavailable), unavailable == true {
                state = .unavailable
                return
            }
            let introducedVersion = try values.decode(String.self, forKey: .platformVersion)
            state = .available(version: introducedVersion)
            guard let version = Version(versionString: introducedVersion), (2...3).contains(version.count) else {
                throw DocumentationBundle.PropertyListError.invalidVersionString(introducedVersion)
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(platformName, forKey: .platformName)
            guard let introducedVersion = introducedVersion else {
                try container.encode(true, forKey: .unavailable)
                return
            }
            try container.encode(introducedVersion, forKey: .platformVersion)
        }
    }

    /// A map of modules and the default platform availability for symbols in that module.
    ///
    /// For example: "ModuleName" -> ["macOS 10.15", "iOS 13.0"]
    var modules: [String: [ModuleAvailability]]
    
    /// Fallback availability information for platforms we either don't emit SGFs for
    /// or have the same availability information as another platform.
    static let fallbackPlatforms: [PlatformName : PlatformName] = [
        .catalyst:.iOS,
        PlatformName(operatingSystemName: "iPadOS"):.iOS
    ]

    /// Creates a default availability module.
    /// - Parameter modules: A map of modules and the default platform availability for symbols in that module.
    public init(with modules: [String: [ModuleAvailability]]) {
            self.modules = modules.mapValues { platformAvailabilities -> [DefaultAvailability.ModuleAvailability] in
            // If a module doesn't contain default availability information for any of the fallback platforms,
            // infer it from the corresponding mapped value.
            platformAvailabilities + DefaultAvailability.fallbackPlatforms.compactMap { (platform, fallbackPlatform) in
                if !platformAvailabilities.contains(where: { $0.platformName == platform }),
                   let fallbackAvailability = platformAvailabilities.first(where: { $0.platformName == fallbackPlatform }),
                   let fallbackIntroducedVersion = fallbackAvailability.introducedVersion
                {
                    return DefaultAvailability.ModuleAvailability(
                        platformName: platform,
                        platformVersion: fallbackIntroducedVersion
                    )
                }
                return nil
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
