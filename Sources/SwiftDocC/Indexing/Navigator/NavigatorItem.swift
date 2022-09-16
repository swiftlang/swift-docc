/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Unpacks data as a `T` value
/// - Note: To save space and avoid padding the data, we unpack data without requiring alignment.
@inline(__always) func unpackedValueFromData<T>(_ data: Data) -> T {
    return data.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: T.self).pointee }
}

/// Packs a `T` value as data
@inline(__always) func packedDataFromValue<T>(_ value: T) -> Data {
    return withUnsafeBytes(of: value) { Data($0) }
}

/**
 The `NavigatorItem` class describes a single entry in a navigator, providing the necessary information to display and process (such as filtering) a single item.
 */
public final class NavigatorItem: Serializable, Codable, Equatable, CustomStringConvertible, Hashable {
    
    /// The page type of the item.
    public let pageType: UInt8
    
    /// The language identifier of the item.
    public let languageID: UInt8
    
    /// The title of the entry.
    public let title: String
    
    /// The platform information of the item.
    public let platformMask: UInt64
    
    /// The availability information of the item.
    public let availabilityID: UInt64
    
    /// The path information of the item (might be a URL as well).
    internal var path: String = ""
    
    /// If available, a hashed USR of this entry and its language information.
    internal var usrIdentifier: String? = nil
    
    var icon: RenderReferenceIdentifier? = nil
    
    /**
     Initialize a `NavigatorItem` with the given data.
     
     - Parameters:
        - pageType: The type of the page, such as "article", "tutorial", "struct", etc...
        - languageID:  The numerical identifier of the language.
        - title: The user facing page title.
        - platformMask: The mask indicating for which platform the page is available.
        - availabilityID:  The identifier of the availability information of the page.
        - path: The path to load the content.
     */
    init(pageType: UInt8, languageID: UInt8, title: String, platformMask: UInt64, availabilityID: UInt64, path: String, icon: RenderReferenceIdentifier? = nil) {
        self.pageType = pageType
        self.languageID = languageID
        self.title = title
        self.platformMask = platformMask
        self.availabilityID = availabilityID
        self.path = path
        self.icon = icon
    }
    
    /**
     Initialize a `NavigatorItem` with the given data.
     
     - Parameters:
        - pageType: The type of the page, such as "article", "tutorial", "struct", etc...
        - languageID:  The numerical identifier of the language.
        - title: The user facing page title.
        - platformMask: The mask indicating for which platform the page is available.
        - availabilityID:  The identifier of the availability information of the page.
     */
    public init(pageType: UInt8, languageID: UInt8, title: String, platformMask: UInt64, availabilityID: UInt64, icon: RenderReferenceIdentifier? = nil) {
        self.pageType = pageType
        self.languageID = languageID
        self.title = title
        self.platformMask = platformMask
        self.availabilityID = availabilityID
        self.icon = icon
    }
    
    // MARK: - Serialization and Deserialization
    
    /**
     Initialize a `NavigatorItem` using raw data.
     
     - Parameters rawValue: The `Data` from which the instance should be deserialized from.
     */
    required public init?(rawValue: Data) {
        let data = rawValue
        
        var cursor: Int = 0
        var length: Int = 0
        
        length = MemoryLayout<UInt8>.stride
        self.pageType = unpackedValueFromData(data[cursor..<cursor + length])
        cursor += length
        
        self.languageID = unpackedValueFromData(data[cursor..<cursor + length])
        cursor += length
        
        length = MemoryLayout<UInt64>.stride
        self.platformMask = unpackedValueFromData(data[cursor..<cursor + length])
        cursor += length
            
        self.availabilityID = unpackedValueFromData(data[cursor..<cursor + length])
        cursor += length
        
        let titleLength: UInt64 = unpackedValueFromData(data[cursor..<cursor + length])
        cursor += length
        
        let pathLength: UInt64 = unpackedValueFromData(data[cursor..<cursor + length])
        cursor += length
        
        let titleData = data[cursor..<cursor + Int(titleLength)]
        cursor += Int(titleLength)
        self.title = String(data: titleData, encoding: .utf8)!
        
        let pathData = data[cursor..<cursor + Int(pathLength)]
        self.path = String(data: pathData, encoding: .utf8)!
        
        assert(cursor+Int(pathLength) == data.count)
    }

    /// Returns the `Data` representation of the current `NavigatorItem` instance.
    public var rawValue: Data {
        var data = Data()
        
        data.append(packedDataFromValue(pageType))
        data.append(packedDataFromValue(languageID))
        data.append(packedDataFromValue(platformMask))
        data.append(packedDataFromValue(availabilityID))
        data.append(packedDataFromValue(UInt64(title.utf8.count)))
        data.append(packedDataFromValue(UInt64(path.utf8.count)))
        
        data.append(Data(title.utf8))
        data.append(Data(path.utf8))
        
        return data
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: NavigatorItem, rhs: NavigatorItem) -> Bool {
        return lhs.pageType == rhs.pageType &&
            lhs.languageID == rhs.languageID &&
            lhs.title == rhs.title &&
            lhs.platformMask == rhs.platformMask &&
            lhs.availabilityID == rhs.availabilityID
    }
    
    // MARK: - Hasher
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(pageType)
        hasher.combine(languageID)
        hasher.combine(title)
        hasher.combine(platformMask)
        hasher.combine(availabilityID)
    }
    
    // MARK: - Description
    
    public var description: String {
        return """
        {
            pageType: \(pageType),
            languageID: \(languageID),
            title: \(title),
            platformMask: \(platformMask),
            availabilityID: \(availabilityID)
        }
        """
    }
}
