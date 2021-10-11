/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/**
 The `AvailabilityIndex` class stores the information about availability for SDKs of symbols.
 The information if a symbol is available for a given platform and version is stored inside this index.
 */
public class AvailabilityIndex: Codable {
    
    // Initialize an empty index.
    public init() {
        // Create the any platform ID with index 0.
        identifierToPlatform[Platform.Name.any.mask] = Platform.Name.any
        platformNameToPlatform[Platform.Name.any.name] = Platform.Name.any
        let info = Info(platformName: .any)
        infoToIdentifier[info] = 0
        identifierToInfo[0] = info
    }
    
    /// The set containing all the interface languages in the index.
    public private(set) var interfaceLanguages = Set<InterfaceLanguage>()
    
    /// Maps IDs to a single Availability Information.
    private var identifierToInfo = [Int: Info]()
    
    /// Maps a specific Info to the ID.
    private var infoToIdentifier = [Info: Int]()
    
    /// Maps the platforms available for a given language.
    private var languageToPlatforms = [InterfaceLanguage: Set<Platform.Name>]()
    
    /// Maps the platform ID to a platform name.
    private var identifierToPlatform = [Platform.Name.ID: Platform.Name]()
    
    /// Maps the platform string name to a to a platform name.
    private var platformNameToPlatform = [String: Platform.Name]()
    
    public private(set) var platforms: Set<Platform.Name> = []
    private var platformsToVersions: [Platform.Name: Set<Platform.Version>] = [:]
    
    /// Returns the number of items indexed.
    var indexed: Int {
        guard infoToIdentifier.count == identifierToInfo.count else {
            fatalError("The number of items in the maps doesn't match.")
        }
        return infoToIdentifier.count
    }
    
    public func id(for info: Info, createIfMissing: Bool = false) -> Int? {
        if let id = infoToIdentifier[info] { return id }
        if createIfMissing {
            guard identifierToInfo.count < UInt16.max else {
                fatalError("The max number of entries for indexes is: \(UInt16.max).")
            }
            
            index(info: info)
            
            let newID = identifierToInfo.count
            infoToIdentifier[info] = newID
            identifierToInfo[newID] = info
            return newID
        }
        return nil
    }
    
    public func info(for id: Int) -> Info? {
        return identifierToInfo[id]
    }
    
    /// Returns a set containing the versions for a given platform.
    public func versions(for platform: Platform.Name) -> Set<Platform.Version>? {
        return platformsToVersions[platform]
    }
    
    /// Returns an array containing the versions for a given platform in ascending order.
    public func sortedVersions(for platform: Platform.Name) -> [Platform.Version]? {
        guard let versions = platformsToVersions[platform] else { return nil }
        return Array(versions).sorted()
    }
    
    /// Returns a Platform for a given ID.
    public func platform(for id: Platform.Name.ID) -> Platform.Name? {
        return identifierToPlatform[id]
    }
    
    /// Returns a `Platform.Name` with a given `String`, otherwise return the `undefined` platform.
    /// - Note: The name is case sensitive.
    public func platform(named name: String) -> Platform.Name {
        return platformNameToPlatform[name] ?? .undefined
    }
    
    /// Returns a list of platforms for a given language.
    public func platforms(for interfaceLangauge: InterfaceLanguage) -> [Platform.Name]? {
        guard let values = languageToPlatforms[interfaceLangauge] else { return nil }
        return Array(values)
    }
    
    // MARK: - Indexing
    
    /// Index the information for platform and versions.
    private func index(info: Info) {
        if info.platformName != .any { // Avoid listing the "any" platform.
            platforms.insert(info.platformName)
        }
        identifierToPlatform[info.platformName.mask] = info.platformName
        platformNameToPlatform[info.platformName.name] = info.platformName
        var platformToVersions = platformsToVersions[info.platformName] ?? []
        if let introduced = info.introduced {
            platformToVersions.insert(introduced)
        }
        if let deprecated = info.deprecated {
            platformToVersions.insert(deprecated)
        }
        platformsToVersions[info.platformName] = platformToVersions
    }
    
    /// Insert a language inside the index.
    public func add(language: InterfaceLanguage) {
        interfaceLanguages.insert(language)
    }
    
    /// Insert a language inside the index.
    public func add(platform: Platform.Name, for language: InterfaceLanguage) {
        var values = languageToPlatforms[language] ?? []
        values.insert(platform)
        languageToPlatforms[language] = values
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case data, interfaceLanguages, languageToPlatforms, platforms
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identifierToInfo, forKey: .data)
        try container.encode(platforms, forKey: .platforms)
        try container.encode(interfaceLanguages, forKey: .interfaceLanguages)
        try container.encode(languageToPlatforms, forKey: .languageToPlatforms)
    }
    
    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        identifierToInfo = try values.decode([Int: Info].self, forKey: .data)
        platforms = try values.decode(Set<Platform.Name>.self, forKey: .platforms)
        interfaceLanguages = try values.decode(Set<InterfaceLanguage>.self, forKey: .interfaceLanguages)
        languageToPlatforms = try values.decode([InterfaceLanguage: Set<Platform.Name>].self, forKey: .languageToPlatforms)
        
        for (key, value) in identifierToInfo {
            infoToIdentifier[value] = key
            index(info: value)
        }
        
        for platform in platforms {
            identifierToPlatform[platform.mask] = platform
            platformNameToPlatform[platform.name] = platform
        }
    }

}
