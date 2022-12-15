/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive that sets the platform availability information for a documentation page.
///
/// `@Available` is analagous to the `@available` attribute in Swift: It allows you to specify a
/// platform version that the page relates to. To specify a platform and version, list the platform
/// name and use the `introduced` argument:
///
/// ```markdown
/// @Available(macOS, introduced: "12.0")
/// ```
///
/// The available platforms are `macOS`, `iOS`, `watchOS`, and `tvOS`.
///
/// This directive is available on both articles and documentation extension files. In extension
/// files, the information overrides any information from the symbol itself.
///
/// This directive is only valid within a ``Metadata`` directive:
///
/// ```markdown
/// @Metadata {
///     @Available(macOS, introduced: "12.0")
/// }
/// ```
public final class MetadataAvailability: Semantic, AutomaticDirectiveConvertible {
    static public let directiveName: String = "Available"

    public enum Platform: String, RawRepresentable, CaseIterable, DirectiveArgumentValueConvertible {
        case any = "*"
        case macOS, iOS, watchOS, tvOS

        public init?(rawValue: String) {
            for platform in Self.allCases {
                if platform.rawValue.lowercased() == rawValue.lowercased() {
                    self = platform
                    return
                }
            }
            return nil
        }
    }

    /// The platform that this argument's information applies to.
    @DirectiveArgumentWrapped(name: .unnamed)
    public var platform: Platform = .any

    /// The platform version that this page applies to.
    @DirectiveArgumentWrapped
    public var introduced: String? = nil

    /// Whether to mark this page as "Deprecated".
    @DirectiveArgumentWrapped
    public var isDeprecated: Bool = false

    /// Whether to mark this page as "Beta".
    @DirectiveArgumentWrapped
    public var isBeta: Bool = false

    static var keyPaths: [String : AnyKeyPath] = [
        "platform"     : \MetadataAvailability._platform,
        "introduced"   : \MetadataAvailability._introduced,
        "isDeprecated" : \MetadataAvailability._isDeprecated,
        "isBeta"       : \MetadataAvailability._isBeta,
    ]

    func validate(
        source: URL?,
        for bundle: DocumentationBundle,
        in context: DocumentationContext,
        problems: inout [Problem]
    ) -> Bool {
        var isValid = true

        if platform == .any && introduced != nil {
            problems.append(.init(diagnostic: .init(
                source: source,
                severity: .warning,
                range: originalMarkup.range,
                identifier: "org.swift.docc.\(MetadataAvailability.self).introducedVersionForAllPlatforms",
                summary: "\(MetadataAvailability.directiveName.singleQuoted) directive requires a platform with the `introduced` argument"
            )))

            isValid = false
        }

        if platform == .any && introduced == nil && isDeprecated == false && isBeta == false {
            problems.append(.init(diagnostic: .init(
                source: source,
                severity: .warning,
                range: originalMarkup.range,
                identifier: "org.swift.docc.\(MetadataAvailability.self).emptyAttribute",
                summary: "\(MetadataAvailability.directiveName.singleQuoted) directive requires a platform and `introduced` argument, or an `isDeprecated` or `isBeta` argument"
            )))

            isValid = false
        }

        if isDeprecated {
            problems.append(.init(diagnostic: .init(
                source: source,
                severity: .information,
                range: originalMarkup.range,
                identifier: "org.swift.docc.\(MetadataAvailability.self).unusedDeprecated",
                summary: "\(MetadataAvailability.directiveName.singleQuoted) `isDeprecated` argument is currently unused"
            )))
        }

        if isBeta {
            problems.append(.init(diagnostic: .init(
                source: source,
                severity: .information,
                range: originalMarkup.range,
                identifier: "org.swift.docc.\(MetadataAvailability.self).unusedBeta",
                summary: "\(MetadataAvailability.directiveName.singleQuoted) `isBeta` argument is currently unused"
            )))
        }

        return isValid
    }

    public let originalMarkup: Markdown.BlockDirective

    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: Markdown.BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}
