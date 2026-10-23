/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A collection of default platform availability.
///
/// Default availability is used as a fallback value for symbols without explicit availability information.
///
/// This information can be authored in the catalog's Info.plist file, as an array of platform "name" and "version" pairs,
/// or in the case where the platform in unconditionally unavailable, "name" and "unavailable" pairs:
///
/// ```
/// <key>CDAppleDefaultAvailability</key>
/// <array>
///     <dict>
///         <key>name</key>
///         <string>Platform Name</string>
///         <key>version</key>
///         <string>Version Number</string>
///     </dict>
///     <dict>
///         <key>name</key>
///         <string>Platform Name</string>
///     </dict>
///     <dict>
///         <key>name</key>
///         <string>Other Platform Name</string>
///         <key>unavailable</key>
///         <true/>
///     </dict>
/// </array>
/// ```
public struct DefaultAvailability: Codable, Equatable {

    /// A platform name and version number pair.
    public struct ModuleAvailability: Codable, Hashable {
        enum CodingKeys: String, CodingKey {
            case platformName = "name"
            case platformVersion = "version"
            case unavailable
        }
        
        /// The different availability states that can be declared.
        /// Unavailable or Available with a potential introduced version.
        enum VersionInformation: Hashable {
            case unavailable
            case available(version: String?)
        }

        /// The name of the platform, e.g. "macOS".
        public var platformName: PlatformName
        
        /// The availability version state information, e.g unavailable
        var versionInformation: VersionInformation

        /// A string representation of the version for this platform
        /// or nil if it's unavailable.
        public var introducedVersion: String? {
            switch versionInformation {
                case .available(let introduced): introduced
                case .unavailable:               nil
            }
        }

        /// Creates a new module availability with a given platform name and platform version.
        ///
        /// - Parameters:
        ///   - platformName: A platform name, such as "iOS" or "macOS"; see ``PlatformName``.
        ///   - platformVersion: A 2- or 3-component version string, such as `"13.0"` or `"13.1.2"`.
        public init(platformName: PlatformName, platformVersion: String?) {
            self.platformName = platformName
            self.versionInformation = .available(version: platformVersion)
        }
        
        /// Creates a new module availability with a given platform name and platform availability set as unavailable.
        ///
        /// - Parameters:
        ///   - unavailablePlatformName: A platform name, such as "iOS" or "macOS"; see ``PlatformName``.
        public init(unavailablePlatformName: PlatformName) {
            self.platformName = unavailablePlatformName
            self.versionInformation = .unavailable
        }

        public init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            platformName = try values.decode(PlatformName.self, forKey: .platformName)
            if let unavailable = try values.decodeIfPresent(Bool.self, forKey: .unavailable), unavailable == true {
                versionInformation = .unavailable
                return
            }
            let introducedVersion = try values.decodeIfPresent(String.self, forKey: .platformVersion)
            versionInformation = .available(version: introducedVersion)
            // If the default availability contains a version, validate it's a
            // semantic version.
            if let introducedVersion {
                guard let version = Version(versionString: introducedVersion), (2...3).contains(version.count) else {
                    throw DocumentationContext.Inputs.PropertyListError.invalidVersionString(introducedVersion)
                }
            }
        }
        
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(platformName, forKey: .platformName)
            switch versionInformation {
            case .available(let introducedVersion):
                try container.encode(introducedVersion, forKey: .platformVersion)
            case .unavailable:
                try container.encode(true, forKey: .unavailable)
            }
        }
    }

    /// The internal storage of the default availability information.
    ///
    /// We should remove this type, and only store the array, after 6.6 is released.
    enum Info: Equatable {
        case current([ModuleAvailability])
        // It's not supported to mix different modules in one catalog. The default availability shouldn't support this either.
        // We should remove this case, and the surrounding Info type, after 6.6 is released.
        case deprecated([String: [ModuleAvailability]])
    }
    
    /// The default platform availability for symbols.
    var info: Info
    
    /// Fallback availability information for platforms we either don't emit SGFs for
    /// or have the same availability information as another platform.
    package static let fallbackPlatforms: [PlatformName: PlatformName] = [
        .catalyst: .iOS,
        .iPadOS: .iOS,
    ]

    @available(*, deprecated, message: "Pass  'init(with:)' instead. This deprecated API will be removed after 6.6 is released.")
    public init(with deprecatedAvailabilityByModuleName: [String: [ModuleAvailability]]) {
        info = .deprecated(deprecatedAvailabilityByModuleName)
    }
    
    /// Creates a default availability container..
    /// - Parameter availability: The default platform availability.
    public init(with availability: [ModuleAvailability]) {
        info = .current(availability)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            info = .current(try container.decode([ModuleAvailability].self))
            return
        } catch DecodingError.typeMismatch {
            info = .deprecated(try container.decode([String: [ModuleAvailability]].self))
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch info {
            case.current(let modules):
                try container.encode(modules)
            case .deprecated(let modulesByName):
                try container.encode(modulesByName)
        }
    }
}
