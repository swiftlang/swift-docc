/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension DocumentationBundle.Info {
    
    /// A collection of options that customaise the default availability behaviour.
    ///
    /// Default availability options are applied to all the modules contained in the documentation bundle.
    ///
    /// This information can be authored in the bundle's Info.plist file, as a dictionary of option name and boolean pairs.
    ///
    /// ```
    /// <key>CDDefaultAvailabilityOptions</key>
    /// <dict>
    ///     <key>OptionName</key>
    ///     <bool/>
    /// </dict>
    /// ```
    public struct DefaultAvailabilityOptions: Codable, Equatable {
        
        /// A set of non-standard behaviors that apply to this node.
        fileprivate(set) var options: Options
        
        /// Options that specify behaviors of the default availability logic.
        struct Options: OptionSet {

            let rawValue: Int
            
            /// Enable or disable symbol availability version inference from the module default availability.
            static let inheritVersionNumber = Options(rawValue: 1 << 0)
        }
        
        /// String representation of the default availability options.
        private enum CodingKeys: String, CodingKey {
            case inheritVersionNumber = "InheritVersionNumber"
        }

        public init(from decoder: any Decoder) throws {
            self.init()
            let values = try decoder.container(keyedBy: CodingKeys.self)
            if try values.decodeIfPresent(Bool.self, forKey: .inheritVersionNumber) == false {
                options.remove(.inheritVersionNumber)
            }
        }
        
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            if !options.contains(.inheritVersionNumber) {
                try container.encode(false, forKey: .inheritVersionNumber)
            }
            
        }
        
        public init() {
            self.options = .inheritVersionNumber
        }

    }
}

