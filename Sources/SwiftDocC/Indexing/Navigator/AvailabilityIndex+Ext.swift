/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension AvailabilityIndex {
    
    /// A single entry in the index.
    public struct Info: Hashable, Equatable, Codable {
        /// The platform name.
        public let platformName: Platform.Name
        
        /// When an item has been introduced.
        public let introduced: Platform.Version?
        
        /// When an item has been deprecated.
        public let deprecated: Platform.Version?
        
        public init(platformName: Platform.Name, introduced: Platform.Version? = nil, deprecated: Platform.Version? = nil) {
            self.platformName = platformName
            self.introduced = introduced
            self.deprecated = deprecated
        }
        
        public func belongs(to platformName: Platform.Name) -> Bool {
            return self.platformName == platformName
        }
        
        public func isIntroduced(on platform: Platform) -> Bool {
            guard self.platformName == platform.name else { return false }
            if let introduced = introduced {
                return introduced == platform.version
            }
            return false
        }
        
        public func isAvailable(on platform: Platform) -> Bool {
            guard self.platformName == platform.name else { return false }
            if let introduced = introduced {
                return platform.version >= introduced
            }
            return true
        }
        
        public func isDeprecated(on platform: Platform) -> Bool {
            guard self.platformName == platform.name else { return false }
            if let deprecated = deprecated {
                return platform.version > deprecated
            }
            return false
        }
    }
        
}

// MARK: - InterfaceLanguage

/**
 Interface Language identifies a programming language used to index a content of a documentation bundle.
 
 - Note: The name reflects what a render node JSON provides to identify a programming language.
 The name has been decided to avoid confusion with locale languages.
 */
public struct InterfaceLanguage: Hashable, CustomStringConvertible, Codable, Equatable {
    
    public typealias ID = UInt8
    
    /// A user friendly name for the language.
    public let name: String
    
    /// An identifier for the language.
    ///
    /// For example, Swift's identifier is `"swift"` and Objective-C's is "`occ`".
    ///
    /// > Tip: You can initialize an ``InterfaceLanguage`` from a known identifier, with the
    /// > ``from(string:)`` function.
    public let id: String
    
    /// A mask to use to identify the interface language..
    public let mask: ID
    
    
    enum CodingKeys: String, CodingKey {
        case name
        case id
        case mask
    }
    
    /// Initialize an instance of interface language.
    private init(name: String, id: String, mask: ID) {
        self.name = name
        self.mask = mask
        self.id = id
    }
    
    // This would return "Swift" or "Objective-C" for example.
    public var description: String {
        return name
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        let name = try values.decode(String.self, forKey: .name)
        self.name = name
        
        let id = try values.decodeIfPresent(String.self, forKey: .id)
        if let id = id {
            self.id = id
        } else {
            // Default to a lowercased version of the name if an ID isn't provided
            // to allow for backwards compatibility with existing availability indexes
            // that do not include an id.
            self.id = name.lowercased()
        }
        
        self.mask = try values.decode(ID.self, forKey: .mask)
    }
    
    /**
     Initialize a platform with the given display name and id.
     Id is an integer used to shift bits and generate a mask for fast processing.
     
     - Parameters:
        - name: The name of the platform used also for display. Note: case sensitive.
        - id: The ID of the platform.
     */
    @available(*, deprecated, renamed: "init(_:id:mask:)")
    public init(_ name: String, id: Int) {
        self.init(name, id: name, mask: id)
    }
    
    /// Create an interface language with the given display name, id, and integer mask.
    ///
    /// - Parameters:
    ///    - name: The display name of the interface language.
    ///
    ///      For example, this might be `"Swift"`, or `"Objective-C"`.
    ///
    ///    - id: An identifier for the language.
    ///
    ///      For example, Swift's identifier is `"swift"` and Objective-C's is "`occ`".
    ///
    ///    - mask: An integer mask used to uniquely identify the language.
    ///
    ///      > Warning: Only integer values between 3 and 7 are supported.
    public init(_ name: String, id: String, mask: Int) {
        precondition(mask > 2 && mask < 8 , "Only IDs between 3 and 7 are allowed.")
        self.init(name: name, id: id, mask: (1 << mask))
    }
    
    // String to Language
    public static func from(string: String) -> InterfaceLanguage {
        switch string.lowercased() {
        case "swift":
            return .swift
        case "objective-c", "objc", "occ":
            return .objc
        case "data":
            return .data
        default:
            return .undefined
        }
    }
    
    // A list of pre-defined Apple platforms
    public static let swift = InterfaceLanguage(name: "Swift", id: "swift", mask: 1 << 0)
    public static let objc  = InterfaceLanguage(name: "Objective-C", id: "occ", mask: 1 << 1)
    public static let data  = InterfaceLanguage(name: "Data", id: "data", mask: 1 << 2)
    
    // A mask indicating an undefined language
    public static let undefined = InterfaceLanguage(name: "Other", id: "other", mask: 0)
    
    // A mask including all the languages
    public static let any = InterfaceLanguage(name: "any", id: "any", mask: ID.max)
    
    // A set containing all the Apple's pre-defined interface languages
    public static let apple = Set([InterfaceLanguage.swift, InterfaceLanguage.objc, InterfaceLanguage.data])
    
    // A set containing all the default interface languages
    public static let all = Set([InterfaceLanguage.undefined] + InterfaceLanguage.apple)
    
    // Equatable
    public static func == (lhs: InterfaceLanguage, rhs: InterfaceLanguage) -> Bool {
        // We only account for the mask in terms of equality.
        return lhs.mask == rhs.mask
    }
}

// MARK: - Platform

public struct Platform: Hashable, CustomStringConvertible, Codable, Equatable {

    /// The name of the platform such as `macOS`, `iOS` or `linux`.
    public let name: Name
    
    /// The version of the platform, such as `10.15`, `6.2.1` or `12.2.5`.
    public let version: Version
    
    // This would return "macOS 10.15" or "iOS 12.0" for example.
    public var description: String {
        return name.description + " " + version.description
    }
    
    /**
     Initialize a `Platform` with the given name and version.
     */
    public init(name: Name, version: Version) {
        self.name = name
        self.version = version
    }
    
    // MARK: - PlatformVersion
    
    public struct Version {
        public var majorVersion: Int
        public var minorVersion: Int
        public var patchVersion: Int
    }
    
    // MARK: - PlatformName
    
    public struct Name: Hashable, CustomStringConvertible, Codable, Equatable {
        
        public typealias ID = UInt64
        
        /// The name of the platform, suitable for display.
        public let name: String
        
        /// The assigned mask suitable to be used for filtering content.
        public let mask: ID
        
        /**
         Initialize a platform with the given display name and id.
         Id is an integer used to shift bits and generate a mask for fast processing.
         
         - Parameters:
            - name: The name of the platform used also for display. Note: case sensitive.
            - id: The ID of the platform.
         */
        public init(_ name: String, id: Int) {
            precondition(id > 5 && id < 63 , "Only IDs between 6 and 62 are allowed.")
            self.init(name: name, mask: (1 << id))
        }

        private init(name: String, mask: ID) {
            self.name = name
            self.mask = mask
        }

        public var description: String {
            return name
        }
        
        /// Returns a boolean indicating if the platform is an Apple defined one.
        public var isApplePlatform: Bool {
            return Platform.Name.apple.contains(self)
        }
        
        // A list of pre-defined Apple platforms
        public static let undefined = Platform.Name(name: "undefined", mask: 0)
        public static let xcode = Platform.Name(name: "Xcode", mask: 1 << 0)
        public static let macOS = Platform.Name(name: "macOS", mask: 1 << 1)
        public static let iOS = Platform.Name(name: "iOS", mask: 1 << 2)
        public static let watchOS = Platform.Name(name: "watchOS", mask: 1 << 3)
        public static let tvOS = Platform.Name(name: "tvOS", mask: 1 << 4)
        public static let macCatalyst = Platform.Name(name: "Mac Catalyst", mask: 1 << 5)
        
        // A mask including all the platforms
        public static let any = Platform.Name(name: "all", mask: ID.max)
        
        // A set containing all the Apple's pre-defined platforms
        public static let apple = Set([Platform.Name.xcode, Platform.Name.macOS, Platform.Name.iOS, Platform.Name.watchOS, Platform.Name.watchOS, Platform.Name.tvOS, Platform.Name.macCatalyst])
        
        // A set containing all the default platforms
        public static let all = Set([Platform.Name.undefined] + Platform.Name.apple)
        
        // String to Platform
        public static func from(string: String) -> Platform.Name {
            switch string.lowercased() {
            case "xcode":
                return .xcode
            case "macos":
                return .macOS
            case "ios":
                return .iOS
            case "watchos":
                return .watchOS
            case "tvos":
                return .tvOS
            case "mac catalyst":
                return .macCatalyst
            default:
                return .undefined
            }
        }
        
        // Equatable
        public static func == (lhs: Platform.Name, rhs: Platform.Name) -> Bool {
            // We only account for the mask in terms of equality.
            return lhs.mask == rhs.mask
        }
    }
}


// MARK: - Utility Extensions

extension Platform.Version: CustomStringConvertible, Equatable, Comparable, Codable, Hashable {
    
    /**
     Initialize a `PlatformVersion` using a given string.
     Ex: "10.15.1" or "9.3.1".
     
     - Parameter string: The string to parse to initialize the `PlatformVersion`.
     */
    public init?(string: String) {
        let stringComponents = string.components(separatedBy: ".")
        guard stringComponents.count <= 3 else { return nil }
        let intComponents = stringComponents.compactMap { Int($0) }
        guard intComponents.count == stringComponents.count, intComponents.count > 0 else {
            return nil
        }
        self.init(majorVersion: intComponents[0],
                  minorVersion: (intComponents.count > 1) ? intComponents[1] : 0,
                  patchVersion: (intComponents.count > 2) ? intComponents[2] : 0)
    }
    
    public var description: String {
        if patchVersion > 0 { return "\(majorVersion).\(minorVersion).\(patchVersion)" }
        return "\(majorVersion).\(minorVersion)"
    }
    
    // MARK: - Equatable and Comparable
    
    public static func == (lhs: Platform.Version, rhs: Platform.Version) -> Bool {
        return lhs.majorVersion == rhs.majorVersion && lhs.minorVersion == rhs.minorVersion && lhs.patchVersion == rhs.patchVersion
    }
    
    public static func < (lhs: Platform.Version, rhs: Platform.Version) -> Bool {
        if lhs.majorVersion != rhs.majorVersion { return lhs.majorVersion < rhs.majorVersion }
        if lhs.minorVersion != rhs.minorVersion { return lhs.minorVersion < rhs.minorVersion }
        if lhs.patchVersion != rhs.patchVersion { return lhs.patchVersion < rhs.patchVersion }
        return false // Equals, so return false.
    }
    
    // MARK: Hashable
    
    public func hash(into hasher: inout Hasher) {
      hasher.combine(majorVersion)
      hasher.combine(minorVersion)
      hasher.combine(patchVersion)
    }
    
    // MARK: Codable
    
    enum CodingKeys: String, CodingKey {
        case majorVersion
        case minorVersion
        case patchVersion
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let majorVersion = try values.decode(Int.self, forKey: .majorVersion)
        let minorVersion = try values.decode(Int.self, forKey: .minorVersion)
        let patchVersion = try values.decode(Int.self, forKey: .patchVersion)
        self.init(majorVersion: majorVersion, minorVersion: minorVersion, patchVersion: patchVersion)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(majorVersion, forKey: .majorVersion)
        try container.encode(minorVersion, forKey: .minorVersion)
        try container.encode(patchVersion, forKey: .patchVersion)
    }
    
    // MARK: UInt32 version encoding
    public init(uint32: UInt32) {
        var representation = uint32
        let patch = representation & UInt32(UInt8.max)
        representation = representation >> 8
        let minor = representation & UInt32(UInt8.max)
        representation = representation >> 8
        let major = representation
        self.init(majorVersion: Int(major), minorVersion: Int(minor), patchVersion: Int(patch))
    }
    
    public var uint32: UInt32 {
        var result = UInt32(0)
        result = result | UInt32(majorVersion)
        result = result << 8
        result = result | UInt32(minorVersion)
        result = result << 8
        return result | UInt32(patchVersion)
    }
}
