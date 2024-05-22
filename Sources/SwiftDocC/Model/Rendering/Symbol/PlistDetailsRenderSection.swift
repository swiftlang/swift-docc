/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A style for how to render links to a property list key or an entitlement key.
public enum PropertyListTitleStyle: String, Codable, Equatable {
    /// Render links to the symbol using the raw key, for example, "com.apple.enableDataAccess".
    ///
    /// ## See Also
    /// - ``TopicRenderReference/PropertyListKeyNames/rawKey``
    case useRawKey = "symbol"
    /// Render links to the symbol using a special "IDE title" name, for example, "Enables Data Access".
    ///
    /// ## See Also
    /// - ``TopicRenderReference/PropertyListKeyNames/displayName``
    case useDisplayName = "title"
}

@available(*, deprecated, renamed: "PropertyListTitleStyle", message: "Use 'PropertyListTitleStyle' instead. This deprecated API will be removed after 6.1 is released")
public enum TitleStyle: String, Codable, Equatable {
    @available(*, deprecated, renamed: "PropertyListTitleStyle.useRawKey", message: "Use 'PropertyListTitleStyle.useRawKey' instead. This deprecated API will be removed after 6.1 is released")
    case symbol
    @available(*, deprecated, renamed: "PropertyListTitleStyle.useDisplayName", message: "Use 'PropertyListTitleStyle.useDisplayName' instead. This deprecated API will be removed after 6.1 is released")
    case title
}

/// A section that contains details about a property list key.
struct PlistDetailsRenderSection: RenderSection, Equatable {
    var kind: RenderSectionKind = .plistDetails
    /// A title for the section.
    var title = "Details"
    
    /// Details for a property list key.
    struct Details: Codable, Equatable {
        /// The name of the key.
        let rawKey: String
        /// A list of types acceptable for this key's value.
        let value: [TypeDetails]
        /// A list of platforms to which this key applies.
        let platforms: [String]
        /// An optional, human-friendly name of the key.
        let displayName: String?
        /// A title rendering style.
        let titleStyle: PropertyListTitleStyle
        
        enum CodingKeys: String, CodingKey {
            case rawKey = "name"
            case value
            case platforms
            case displayName = "ideTitle"
            case titleStyle
        }
    }
    
    /// The details of the property key.
    let details: Details
}

// Diffable conformance
extension PlistDetailsRenderSection: RenderJSONDiffable {
    /// Returns the differences between this PlistDetailsRenderSection and the given one.
    func difference(from other: PlistDetailsRenderSection, at path: CodablePath) -> JSONPatchDifferences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)

        diffBuilder.addDifferences(atKeyPath: \.kind, forKey: CodingKeys.kind)
        diffBuilder.addDifferences(atKeyPath: \.title, forKey: CodingKeys.title)

        return diffBuilder.differences
    }
    
    /// Returns if this PlistDetailsRenderSection is similar enough to the given one.
    func isSimilar(to other: PlistDetailsRenderSection) -> Bool {
        return self.title == other.title
    }
}
