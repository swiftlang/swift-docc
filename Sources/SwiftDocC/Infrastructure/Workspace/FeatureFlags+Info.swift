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
    /// This is a subset of flags from ``FeatureFlags`` that can influence how a documentation
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
    public struct BundleFeatureFlags: Codable, Equatable {
        /// Whether or not experimental support for combining overloaded symbol pages is enabled.
        ///
        /// This feature flag corresponds to ``FeatureFlags/isExperimentalOverloadedSymbolPresentationEnabled``.
        public var experimentalOverloadedSymbolPresentation: Bool?

        public init(experimentalOverloadedSymbolPresentation: Bool? = nil) {
            self.experimentalOverloadedSymbolPresentation = experimentalOverloadedSymbolPresentation
        }

        enum CodingKeys: String, CodingKey {
            case experimentalOverloadedSymbolPresentation = "ExperimentalOverloadedSymbolPresentation"
        }

        public init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)

            self.experimentalOverloadedSymbolPresentation = try values.decodeIfPresent(Bool.self, forKey: .experimentalOverloadedSymbolPresentation)
            if let overloadsFlag = self.experimentalOverloadedSymbolPresentation {
                FeatureFlags.current.isExperimentalOverloadedSymbolPresentationEnabled = overloadsFlag
            }
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(experimentalOverloadedSymbolPresentation, forKey: .experimentalOverloadedSymbolPresentation)
        }
    }
}
