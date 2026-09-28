/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension DocumentationContext.Inputs.Info {
    /// A collection of feature flags that can be enabled from a catalog's Info.plist.
    ///
    /// This is a subset of flags from ``FeatureFlags`` that can influence how a documentation
    /// catalog is written, and so can be considered a property of the documentation itself, rather
    /// than as an experimental behavior that can be enabled for one-off builds.
    ///
    /// ```xml
    /// <key>CDExperimentalFeatureFlags</key>
    /// <dict>
    ///     <key>ExperimentalOverloadedSymbolPresentation</key>
    ///     <true/>
    /// </dict>
    /// ```
    struct CatalogFeatureFlags: Codable, Equatable {
        // FIXME: Automatically expose all the feature flags from the global FeatureFlags struct

        /// Whether or not experimental support for combining overloaded symbol pages is enabled.
        ///
        /// This feature flag corresponds to ``FeatureFlags/isExperimentalOverloadedSymbolPresentationEnabled``.
        public var experimentalOverloadedSymbolPresentation: Bool?

        public init(experimentalOverloadedSymbolPresentation: Bool? = nil) {
            self.experimentalOverloadedSymbolPresentation = experimentalOverloadedSymbolPresentation
            self.unknownFeatureFlags = []
        }

        /// Whether or not annotation of code blocks is enabled.
        ///
        /// This feature flag corresponds to ``FeatureFlags/isCodeBlockAnnotationsEnabled``.
        public var codeBlockAnnotations: Bool?

        public init(codeBlockAnnotations: Bool? = nil) {
            self.codeBlockAnnotations = codeBlockAnnotations
            self.unknownFeatureFlags = []
        }

        @available(*, deprecated, renamed: "codeBlockAnnotations", message: "Use 'codeBlockAnnotations' instead. This deprecated API will be removed after 6.5 is released.")
        public var experimentalCodeBlockAnnotations: Bool? {
            get { codeBlockAnnotations }
            set { codeBlockAnnotations = newValue }
        }

        @available(*, deprecated, renamed: "init(codeBlockAnnotations:)", message: "Use 'init(codeBlockAnnotations:)' instead. This deprecated API will be removed after 6.5 is released.")
        public init(experimentalCodeBlockAnnotations: Bool? = nil) {
            self.codeBlockAnnotations = experimentalCodeBlockAnnotations
            self.unknownFeatureFlags = []
        }

        /// A list of decoded feature flag keys that didn't match a known feature flag.
        public let unknownFeatureFlags: [String]

        enum CodingKeys: String, CodingKey, CaseIterable {
            case experimentalOverloadedSymbolPresentation = "ExperimentalOverloadedSymbolPresentation"
            case codeBlockAnnotations = "CodeBlockAnnotations"
            case experimentalCodeBlockAnnotations = "ExperimentalCodeBlockAnnotations"
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

                    case .codeBlockAnnotations, .experimentalCodeBlockAnnotations:
                        self.codeBlockAnnotations = try values.decode(Bool.self, forKey: flagName)
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
            try container.encode(codeBlockAnnotations, forKey: .codeBlockAnnotations)
        }
    }
}
