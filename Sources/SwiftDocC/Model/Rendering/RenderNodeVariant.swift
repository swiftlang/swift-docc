/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/
import Foundation

extension RenderNode {
    /// A render node variant based on a collection of pre-defined traits.
    ///
    /// A variant features a collection of traits and a path where the variant can be found.
    /// When rendered as JSON, the data looks like this:
    /// ```json
    /// {
    ///   "traits" : [
    ///     { "interfaceLanguge": "swift" }
    ///   ],
    ///   "paths" : ["/path/to/variant"]
    /// }
    /// ```
    public struct Variant: Codable, Equatable {
        
        /// A trait describing an aspect of the render variant.
        public enum Trait: Codable, Hashable {
            /// Presentation language (e.g. Swift or Obj-C).
            case interfaceLanguage(String)
            
            enum CodingKeys: String, CodingKey, CaseIterable {
                case interfaceLanguage
            }
            
            public enum Error: DescribedError {
                case invalidTrait
                public var errorDescription: String {
                    switch self {
                    case .invalidTrait: return "None of expected trait keys \(CodingKeys.allCases) was found."
                    }
                }
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)

                if let language = try container.decodeIfPresent(String.self, forKey: .interfaceLanguage) {
                    self = .interfaceLanguage(language)
                    return
                }
                
                throw Error.invalidTrait
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                switch self {
                case .interfaceLanguage(let language):
                    try container.encode(language, forKey: .interfaceLanguage)
                }
            }
        }
        
        /// Collection of traits identifying the variant.
        public var traits: [Trait]
        
        /// The paths to the variant.
        public var paths: [String]
        
        enum CodingKeys: String, CodingKey {
            case traits, paths
        }
        
        public init(traits: [Trait], paths: [String]) {
            self.traits = traits
            self.paths = paths
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            traits = try container.decode([Trait].self, forKey: .traits)
            paths = try container.decode([String].self, forKey: .paths)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(traits, forKey: .traits)
            try container.encode(paths, forKey: .paths)
        }
    }
}
