/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A style for how to render links to a property list key or an entitlement key.
public enum PropertyListTitleStyle: String, Codable, Equatable {
    /// Render links to the property list key using the raw key, for example "com.apple.enableDataAccess".
    ///
    /// ## See Also
    /// - ``TopicRenderReference/PropertyListKeyNames/rawKey``
    case useRawKey = "symbol"
    /// Render links to the property list key using the display name, for example "Enables Data Access".
    ///
    /// ## See Also
    /// - ``TopicRenderReference/PropertyListKeyNames/displayName``
    case useDisplayName = "title"
}

/// A section that contains details about a property list key.
public struct PropertyListDetailsRenderSection: RenderSection, Equatable {
    public var kind: RenderSectionKind = .plistDetails
    /// A title for the section.
    public var title = "Details"
    
    /// Details for a property list key.
    public struct Details: Codable, Equatable {
        /// The name of the key.
        public let rawKey: String
        /// A list of types acceptable for this key's value.
        public let value: [TypeDetails]
        /// A list of platforms to which this key applies.
        public let platforms: [String]
        /// An optional, human-friendly name of the key.
        public let displayName: String?
        /// A title rendering style.
        public let titleStyle: PropertyListTitleStyle

        enum CodingKeys: String, CodingKey {
            case rawKey = "name"
            case value
            case platforms
            case displayName = "ideTitle"
            case titleStyle
        }

        public init(rawKey: String, value: [TypeDetails], platforms: [String], displayName: String?, titleStyle: PropertyListTitleStyle) {
            self.rawKey = rawKey
            self.value = value
            self.platforms = platforms
            self.displayName = displayName
            self.titleStyle = titleStyle
        }
    }
    
    /// The details of the property key.
    public let details: Details

    public init(title: String = "Details", details: Details) {
        self.title = title
        self.details = details
    }
}

// Diffable conformance
extension PropertyListDetailsRenderSection: RenderJSONDiffable {
    /// Returns the differences between this PropertyListDetailsRenderSection and the given one.
    func difference(from other: PropertyListDetailsRenderSection, at path: CodablePath) -> JSONPatchDifferences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)

        diffBuilder.addDifferences(atKeyPath: \.kind, forKey: CodingKeys.kind)
        diffBuilder.addDifferences(atKeyPath: \.title, forKey: CodingKeys.title)

        return diffBuilder.differences
    }
    
    /// Returns if this PropertyListDetailsRenderSection is similar enough to the given one.
    func isSimilar(to other: PropertyListDetailsRenderSection) -> Bool {
        return self.title == other.title
    }
}
