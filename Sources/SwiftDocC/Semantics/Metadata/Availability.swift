/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

extension Metadata {
    /// A directive that sets the platform availability information for a documentation page.
    ///
    /// `@Available` is analogous to the `@available` attribute in Swift: It allows you to specify a
    /// platform version that the page relates to. To specify a platform and version, list the platform
    /// name and use the `introduced` argument:
    ///
    /// ```markdown
    /// @Available(macOS, introduced: "12.0")
    /// ```
    ///
    /// Any text can be given to the first argument, and will be displayed in the page's
    /// availability data. The platforms `iOS`, `macOS`, `watchOS`, and `tvOS` will be matched
    /// case-insensitively, but anything else will be printed verbatim.
    ///
    /// To provide a platform name with spaces in it, provide it as a quoted string:
    ///
    /// ```markdown
    /// @Available("My Package", introduced: "1.0")
    /// ```
    ///
    /// Only strings which are valid semantic version numbers may be passed to the second argument. Specifying an incomplete version number is allowed, as long as all components of the version are valid numbers:
    ///
    /// ```markdown
    /// @Available("My Package", introduced: "1.0.0")
    /// @Available("My Package", introduced: "1.0")
    /// @Available("My Package", introduced: "1")
    /// ```
    ///
    /// If an invalid semantic version number is provided, a compiler warning will be issued and the directive will be ignored.
    ///
    /// This directive is available on both articles and documentation extension files. In extension
    /// files, the information overrides any information from the symbol itself.
    ///
    /// This directive is only valid within a ``Metadata`` directive:
    ///
    /// ```markdown
    /// @Metadata {
    ///     @Available(macOS, introduced: "12.0")
    ///     @Available(iOS, introduced: "15.0")
    /// }
    /// ```
    public final class Availability: Semantic, AutomaticDirectiveConvertible {
        public static let directiveName: String = "Available"
        public static let introducedVersion = "5.8"

        public enum Platform: RawRepresentable, Hashable, DirectiveArgumentValueConvertible {
            // FIXME: re-add `case any = "*"` when `isBeta` and `isDeprecated` are implemented
            // cf. https://github.com/apple/swift-docc/issues/441
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
                    // Reserve the `*` platform for when `isBeta` and `isDeprecated` can be implemented
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

        /// The platform that this argument's information applies to.
        @DirectiveArgumentWrapped(name: .unnamed)
        public var platform: Platform

        /// The platform version that this page applies to.
        @DirectiveArgumentWrapped
        public var introduced: VersionTriplet

        // FIXME: `isBeta` and `isDeprecated` properties/arguments
        // cf. https://github.com/apple/swift-docc/issues/441

        static var keyPaths: [String : AnyKeyPath] = [
            "platform"     : \Availability._platform,
            "introduced"   : \Availability._introduced,
        ]

        public let originalMarkup: Markdown.BlockDirective

        @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
        init(originalMarkup: Markdown.BlockDirective) {
            self.originalMarkup = originalMarkup
        }
    }
}

extension VersionTriplet: DirectiveArgumentValueConvertible {
    init?(rawDirectiveArgumentValue: String) {
        // Split the string into major, minor and patch components
        let availabilityComponents = rawDirectiveArgumentValue.split(separator: ".", maxSplits: 2)
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
}
