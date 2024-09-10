/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

extension Metadata {
    /// A directive that specifies when a documentation page is available for a given platform.
    ///
    /// Whenever possible, prefer to specify availability information using in-source annotations such as the `@available` attribute in Swift or the `API_AVAILABLE` macro in Objective-C.
    /// Using in-source annotations ensures that your documentation matches the availability of your API.
    /// If you duplicate availability information in the documentation markup, the information from the `@Available` directive overrides the information for the in-source annotations from that platform and risks being inaccurate.
    ///
    /// If your source language doesn't have a mechanism for specifying API availability or if you're writing articles about a newly introduced or deprecated API,
    /// you can use the `@Available` directive to specify when you introduced, and optionally deprecated, an API or documentation page for a given platform.
    ///
    /// Each `@Available` directive specifies the availability information for a single platform.
    /// The directive matches the `iOS`, `macOS`, `watchOS`, and `tvOS` platform names case-insensitively.
    /// Any other platform names are displayed verbatim.
    /// If a platform name contains whitespace, commas, or other special characters you need to surround it with quotation marks (`"`).
    ///
    /// ```markdown
    /// @Metadata {
    ///     @Available(iOS, introduced: "15.0")
    ///     @Available(macOS, introduced: "12.0", deprecated: "14.0")
    ///     @Available("My Package", introduced: "1.2.3")
    /// }
    /// ```
    ///
    /// Both the "introduced" and "deprecated" parameters take string representations of semantic version numbers (major`.`minor`.`patch).
    /// If you omit the "patch" or "minor" components, they are assumed to be `0`.
    /// This means that `"1.0.0"`, `"1.0"`, and `"1"` all specify the same semantic version.
    ///
    /// > Earlier Versions:
    /// > Before Swift-DocC 6.0, the `@Available` directive didn't support the "deprecated" parameter.
    ///
    /// > Tip:
    /// > In addition to specifying the version when you deprecated an API or documentation page,
    /// > you can use the ``DeprecationSummary`` directive to provide the reader with additional information about the deprecation or refer them to a replacement API.
    public final class Availability: Semantic, AutomaticDirectiveConvertible {
        public static let directiveName: String = "Available"
        public static let introducedVersion = "5.8"

        public enum Platform: RawRepresentable, Hashable, DirectiveArgumentValueConvertible {
            case macOS, iOS, watchOS, tvOS

            case other(String)

            static var defaultCases: [Platform] = [.macOS, .iOS, .watchOS, .tvOS]

            public init?(rawValue: String) {
                for platform in Self.defaultCases {
                    if platform.rawValue.lowercased() == rawValue.lowercased() {
                        self = platform
                        return
                    }
                }
                if rawValue == "*" {
                    // Reserve the `*` platform for when we have decided on how `*` availability should be displayed (https://github.com/swiftlang/swift-docc/issues/969)
                    return nil
                } else {
                    self = .other(rawValue)
                }
            }

            public var rawValue: String {
                switch self {
                case .macOS: return "macOS"
                case .iOS: return "iOS"
                case .watchOS: return "watchOS"
                case .tvOS: return "tvOS"
                case .other(let platform): return platform
                }
            }

            static func allowedValues() -> [String]? {
                nil
            }
        }

        /// The platform name that this version information applies to.
        @DirectiveArgumentWrapped(name: .unnamed)
        public var platform: Platform

        /// The semantic version (major`.`minor`.`patch) when you introduced this API or documentation page.
        @DirectiveArgumentWrapped
        public var introduced: SemanticVersion

        /// The semantic version (major`.`minor`.`patch) when you deprecated this API or documentation page.
        @DirectiveArgumentWrapped
        public var deprecated: SemanticVersion? = nil

        static var keyPaths: [String : AnyKeyPath] = [
            "platform"     : \Availability._platform,
            "introduced"   : \Availability._introduced,
            "deprecated"   : \Availability._deprecated,
        ]

        public let originalMarkup: Markdown.BlockDirective

        @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
        init(originalMarkup: Markdown.BlockDirective) {
            self.originalMarkup = originalMarkup
        }
    }
}

extension SemanticVersion: DirectiveArgumentValueConvertible {
    static let separator = "."
    
    init?(rawDirectiveArgumentValue: String) {
        guard !rawDirectiveArgumentValue.hasSuffix(Self.separator),
              !rawDirectiveArgumentValue.hasPrefix(Self.separator) else {
            return nil
        }
        
        // Split the string into major, minor and patch components
        let availabilityComponents = rawDirectiveArgumentValue.split(separator: .init(Self.separator), maxSplits: 2)
        guard !availabilityComponents.isEmpty else {
            return nil
        }
        
        // If any of the components are missing, default to 0
        var intAvailabilityComponents = [0, 0, 0]
        for (index, component) in availabilityComponents.enumerated() {
            // If any of the components isn't a number, the input is not valid
            guard let intComponent = Int(component) else {
                return nil
            }
            
            intAvailabilityComponents[index] = intComponent
        }
        
        self.major = intAvailabilityComponents[0]
        self.minor = intAvailabilityComponents[1]
        self.patch = intAvailabilityComponents[2]
    }

    static func allowedValues() -> [String]? {
        nil
    }
    
    static func expectedFormat() -> String? {
        return "a semantic version number ('[0-9]+(.[0-9]+)?(.[0-9]+)?')"
    }
}
