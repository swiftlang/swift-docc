/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A supported platform's name representation.
public struct PlatformName: Codable, Hashable, Equatable {
    public var rawValue: String
    
    /// Compares platform names independently of any known aliases differences or possible incomplete display names.
    public static func == (lhs: PlatformName, rhs: PlatformName) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
    
    /// Creates a new platform name value.
    /// - Parameters:
    ///   - rawValue: The raw source string.
    ///   - aliases: Any aliases for the platform.
    ///   - displayName: An optional name for presentation purposes.
    public init(rawValue: String, aliases: [String] = [], displayName: String? = nil) {
        self.rawValue = rawValue
        self.aliases = aliases
        self.displayName = displayName ?? rawValue
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(displayName)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let name = try container.decode(String.self)
        self.init(operatingSystemName: name)
    }
    
    /// Other known identifiers for the same platform (aka "macosx" for "macOS").
    public var aliases: [String] = []
    
    /// The name to use in render JSON. If `nil` returns `rawValue`.
    public var displayName: String
    
    /// Apple's macOS operating system.
    public static let macOS = PlatformName(rawValue: "macOS", aliases: ["macosx"])
    public static let macOSAppExtension = PlatformName(rawValue: "macOSAppExtension", displayName: "macOS App Extension")
    /// Apple's iOS operating system.
    public static let iOS = PlatformName(rawValue: "iOS")
    public static let iOSAppExtension = PlatformName(rawValue: "iOSAppExtension", displayName: "iOS App Extension")
    /// Apple's watchOS operating system.
    public static let watchOS = PlatformName(rawValue: "watchOS")
    public static let watchOSAppExtension = PlatformName(rawValue: "watchOSAppExtension", displayName: "watchOS App Extension")
    /// Apple's tvOS operating system.
    public static let tvOS = PlatformName(rawValue: "tvOS")
    public static let tvOSAppExtension = PlatformName(rawValue: "tvOSAppExtension", displayName: "tvOS App Extension")
    /// A Linux-based operating system, but not a specific distribution.
    public static let linux = PlatformName(rawValue: "linux")
    /// The Catalyst platform.
    public static let catalyst = PlatformName(rawValue: "macCatalyst", displayName: "Mac Catalyst")
    public static let catalystOSAppExtension = PlatformName(rawValue: "macCatalystAppExtension", displayName: "Mac Catalyst App Extension")
    /// The Swift toolchain platform.
    public static let swift = PlatformName(rawValue: "swift", displayName: "Swift")
    /// The iPad platform.
    public static let iPadOS = PlatformName(rawValue: "iPadOS")
    /// Apple's visionOS operating system.
    public static let visionOS = PlatformName(rawValue: "visionOS")
    
    /// All supported platforms sorted for presentation.
    public static let sortedPlatforms: [PlatformName] = [
        .iOS, .iOSAppExtension,
        .iPadOS,
        .catalyst, .catalystOSAppExtension,
        .macOS, .macOSAppExtension,
        .tvOS, .tvOSAppExtension,
        .visionOS,
        .watchOS, .watchOSAppExtension,
        .swift
    ]
    
    /// A common platform names fast lookup index.
    ///
    /// A static, lazily created platform name index for fast lookups by name.
    private static let platformNamesIndex: [String: PlatformName] = {
        var result = [String: PlatformName]()
        for name in sortedPlatforms {
            result[name.rawValue.lowercased()] = name
            result[name.displayName.lowercased()] = name
            for alias in name.aliases {
                result[alias.lowercased()] = name
            }
        }
        return result
    }()

    /// Creates a new platform name with the given OS name.
    /// - Parameter operatingSystemName: An OS name like 'linux'.
    init(operatingSystemName: String) {
        guard let knowDomain = Self.platformNamesIndex[operatingSystemName.lowercased()] else {
            self.init(rawValue: operatingSystemName, aliases: [])
            return
        }
        self = knowDomain
    }

    /// Creates a new platform name from the given metadata availability attribute platform.
    ///
    /// Returns `nil` if the given platform was ``Metadata/Availability/Platform/any``.
    init?(metadataPlatform platform: Metadata.Availability.Platform) {
        // Note: This is still an optional initializer to prevent source breakage when
        // `Availability.Platform` re-introduces the `.any` case
        // cf. https://github.com/swiftlang/swift-docc/issues/441
        if let knowDomain = Self.platformNamesIndex[platform.rawValue.lowercased()] {
            self = knowDomain
        } else {
            let identifier = platform.rawValue.lowercased().replacingOccurrences(of: " ", with: "")
            self.init(rawValue: identifier, displayName: platform.rawValue)
        }
    }
}
