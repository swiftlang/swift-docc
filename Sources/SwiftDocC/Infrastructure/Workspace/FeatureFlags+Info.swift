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
    internal struct BundleFeatureFlags: Codable, Equatable {
        // FIXME: Automatically expose all the feature flags from the global FeatureFlags struct

        /// Whether or not experimental support for combining overloaded symbol pages is enabled.
        ///
        /// This feature flag corresponds to ``FeatureFlags/isExperimentalOverloadedSymbolPresentationEnabled``.
        public var experimentalOverloadedSymbolPresentation: Bool?

        public init(experimentalOverloadedSymbolPresentation: Bool? = nil) {
            self.experimentalOverloadedSymbolPresentation = experimentalOverloadedSymbolPresentation
            self.unknownFeatureFlags = []
        }

        /// This feature flag corresponds to ``FeatureFlags/isExperimentalCodeBlockEnabled``.
        public var experimentalCodeBlock: Bool?

        public init(experimentalCodeBlock: Bool? = nil) {
            self.experimentalCodeBlock = experimentalCodeBlock
            self.unknownFeatureFlags = []
        }

        /// A list of decoded feature flag keys that didn't match a known feature flag.
        public let unknownFeatureFlags: [String]

        enum CodingKeys: String, CodingKey, CaseIterable {
            case experimentalOverloadedSymbolPresentation = "ExperimentalOverloadedSymbolPresentation"
            case experimentalCodeBlock = "ExperimentalCodeBlock"
        }

        struct AnyCodingKeys: CodingKey {
            var stringValue: String

            init?(stringValue: String) {
                self.stringValue = stringValue
            }

            var intValue: Int? { nil }
            init?(intValue: Int) {
                return nil
            }
        }

        public init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: AnyCodingKeys.self)
            var unknownFeatureFlags: [String] = []

            for flagName in values.allKeys {
                if let codingKey = CodingKeys(stringValue: flagName.stringValue) {
                    switch codingKey {
                    case .experimentalOverloadedSymbolPresentation:
                        self.experimentalOverloadedSymbolPresentation = try values.decode(Bool.self, forKey: flagName)

                    case .experimentalCodeBlock:
                        self.experimentalCodeBlock = try values.decode(Bool.self, forKey: flagName)
                    }
                } else {
                    unknownFeatureFlags.append(flagName.stringValue)
                }
            }

            self.unknownFeatureFlags = unknownFeatureFlags
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(experimentalOverloadedSymbolPresentation, forKey: .experimentalOverloadedSymbolPresentation)
            try container.encode(experimentalCodeBlock, forKey: .experimentalCodeBlock)
        }
    }
}
