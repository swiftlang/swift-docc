/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension DocumentationBundle.Info {
    /// A collection of feature flags that can be enabled from a bundle's Info.plist.
    ///
    /// This is a subset of flags from ``/SwiftDocC/FeatureFlags`` that can influence how a documentation
    /// bundle is written, and so can be considered a property of the documentation itself, rather
    /// than as an experimental behavior that can be enabled for one-off builds.
    ///
    /// ```xml
    /// <key>CDExperimentalFeatureFlags</key>
    /// <dict>
    ///     <key>ExperimentalOverloadedSymbolPresentation</key>
    ///     <true/>
    /// </dict>
    /// ```
    public struct FeatureFlags: Codable, Equatable {
        /// Whether or not experimental support for combining overloaded symbol pages is enabled.
        ///
        /// This feature flag corresponds to ``FeatureFlags/isExperimentalOverloadedSymbolPresentationEnabled``.
        public var experimentalOverloadedSymbolPresentationEnabled: Bool {
            get {
                return _overloadsEnabled ?? SwiftDocC.FeatureFlags.current.isExperimentalOverloadedSymbolPresentationEnabled
            }
            set {
                _overloadsEnabled = newValue
            }
        }

        private var _overloadsEnabled: Bool?

        public init(experimentalOverloadedSymbolPresentationEnabled: Bool? = nil) {
            // IMPORTANT: If you add more fields to this struct, ensure that this initializer sets
            // them to nil or another suitable default value, since it's called to set
            // `computedFeatureFlags` on the parent Info struct.
            self._overloadsEnabled = experimentalOverloadedSymbolPresentationEnabled
        }

        enum CodingKeys: String, CodingKey {
            case experimentalOverloadedSymbolPresentationEnabled = "ExperimentalOverloadedSymbolPresentation"
        }

        public init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)

            self._overloadsEnabled = try values.decodeIfPresent(Bool.self, forKey: .experimentalOverloadedSymbolPresentationEnabled)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(_overloadsEnabled, forKey: .experimentalOverloadedSymbolPresentationEnabled)
        }
    }
}
