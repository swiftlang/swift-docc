/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// An absolute link to a symbol.
///
/// You can use this model to validate a symbol link and access its different parts.
public struct AbsoluteSymbolLink: CustomStringConvertible {
    /// The identifier for the documentation bundle this link is from.
    public let bundleID: String
    
    /// The name of the module that contains this symbol link.
    /// - Note: This could be a link to the module itself.
    public let module: String
    
    /// The top level symbol in this documentation link.
    ///
    /// If this symbol represents a module (see ``representsModule``), then
    /// this is just the module and can be ignored. Otherwise, it's the top level symbol within
    /// the module.
    public let topLevelSymbol: LinkComponent
    
    /// The ordered path components, excluding the module and top level symbol.
    public let basePathComponents: [LinkComponent]
    
    /// A Boolean value that is true if this is a link to a module.
    public let representsModule: Bool
    
    /// Create a new documentation symbol link from a path.
    ///
    /// Expects an absolute symbol link structured like one of the following:
    /// - doc://org.swift.docc.example/documentation/ModuleName
    /// - doc://org.swift.docc.example/documentation/ModuleName/TypeName
    /// - doc://org.swift.docc.example/documentation/ModuleName/ParentType/Test-swift.class/testFunc()-k2k9d
    /// - doc://org.swift.docc.example/documentation/ModuleName/ClassName/functionName(firstParameter:secondParameter:)
    public init?(string: String) {
        // Begin by constructing a validated URL from the given string.
        // Normally symbol links would be validated with `init(symbolPath:)` but since this is expected
        // to be an absolute URL we parse it with `init(parsing:)` instead.
        guard let validatedURL = ValidatedURL(parsingExact: string)?.requiring(scheme: ResolvedTopicReference.urlScheme) else {
            return nil
        }
        
        // All absolute documentation links include the bundle identifier as their host.
        guard let bundleID = validatedURL.components.host, !bundleID.isEmpty else {
            return nil
        }
        self.bundleID = bundleID
        
        var pathComponents = validatedURL.url.pathComponents
        
        // Swift's URL interprets the following link "doc://org.swift.docc.example/documentation/ModuleName"
        // to have a sole "/" as its first path component. We'll just remove it if it's there.
        if pathComponents.first == "/" {
            pathComponents.removeFirst()
        }
        
        // Swift-DocC requires absolute symbol links to be prepended with "documentation"
        guard pathComponents.first == NodeURLGenerator.Path.documentationFolderName else {
            return nil
        }
        
        // Swift-DocC requires absolute symbol links to be prepended with "documentation"
        // as their first path component but that's not actually part of the symbol's path
        // so we drop it here.
        pathComponents.removeFirst()
        
        // Now that we've cleaned up the link, confirm that it's non-empty
        guard !pathComponents.isEmpty else {
            return nil
        }
        
        // Validate and construct the link component that represents the module
        guard let moduleLinkComponent = LinkComponent(string: pathComponents.removeFirst()) else {
            return nil
        }
        
        // We don't allow modules to have disambiguation suffixes
        guard !moduleLinkComponent.hasDisambiguationSuffix else {
            return nil
        }
        self.module = moduleLinkComponent.name
        
        // Next we'll attempt to construct the link component for the top level symbol
        // within the module.
        if pathComponents.isEmpty {
            // There are no more path components, so this is a link to the module itself
            self.topLevelSymbol = moduleLinkComponent
            self.representsModule = true
        } else if let topLevelSymbol = LinkComponent(string: pathComponents.removeFirst()) {
            // We were able to build a valid link component for the next path component
            // so we'll set the top level symbol value and indicate that this is not a link
            // to the module
            self.topLevelSymbol = topLevelSymbol
            self.representsModule = false
        } else {
            return nil
        }
        
        // Finally we transform the remaining path components into link components
        basePathComponents = pathComponents.compactMap { componentName in
            LinkComponent(string: componentName)
        }
        
        // If any of the path components were invalid, we want to mark the entire link as invalid
        guard basePathComponents.count == pathComponents.count else {
            return nil
        }
    }
    
    public var description: String {
        """
        {
            bundleID: \(bundleID.singleQuoted),
            module: \(module.singleQuoted),
            topLevelSymbol: \(topLevelSymbol),
            representsModule: \(representsModule),
            basePathComponents: [\(basePathComponents.map(\.description).joined(separator: ", "))]
        }
        """
    }
}

extension AbsoluteSymbolLink {
    /// A component of a symbol link.
    public struct LinkComponent: CustomStringConvertible {
        /// The name of the symbol represented by the link component.
        public let name: String
        
        /// The suffix used to disambiguate this symbol from other symbol's
        /// that share the same name.
        public let disambiguationSuffix: DisambiguationSuffix
        
        var hasDisambiguationSuffix: Bool {
            disambiguationSuffix != .none
        }
        
        init(name: String, disambiguationSuffix: DisambiguationSuffix) {
            self.name = name
            self.disambiguationSuffix = disambiguationSuffix
        }
        
        /// Creates an absolute symbol component from a raw string.
        ///
        /// For example, the input string can be `"foo-swift.var"`.
        public init?(string: String) {
            // Check to see if this component includes a disambiguation suffix
            if string.contains("-") {
                // Split the path component into its name and disambiguation suffix.
                // It's important to limit to a single split since the disambiguation
                // suffix itself could also contain a '-'.
                var splitPathComponent = string.split(separator: "-", maxSplits: 1)
                guard splitPathComponent.count == 2 else {
                    // This catches a trailing '-' in the suffix (which we don't allow)
                    // since a split would then result in a single path component.
                    return nil
                }
                
                // Set the name from the first half of the split
                name = String(splitPathComponent.removeFirst())
                
                // The disambiguation suffix is formed from the second half
                let disambiguationSuffixString = String(splitPathComponent.removeLast())
                
                // Attempt to parse and validate a disambiguation suffix
                guard let disambiguationSuffix = DisambiguationSuffix(
                    string: disambiguationSuffixString
                ) else {
                    // Invalid disambiguation suffix, so we just return nil
                    return nil
                }
                
                guard disambiguationSuffix != .none else {
                    // Since a "-" was included, we expect the disambiguation
                    // suffix to be non-nil.
                    return nil
                }
                
                self.disambiguationSuffix = disambiguationSuffix
            } else {
                // The path component had no "-" so we just set the name
                // as the entire path component
                name = string
                disambiguationSuffix = .none
            }
        }
        
        public var description: String {
            """
            (name: \(name.singleQuoted), suffix: \(disambiguationSuffix))
            """
        }
        
        /// A string representation of this link component.
        public var asLinkComponentString: String {
            "\(name)\(disambiguationSuffix.asLinkSuffixString)"
        }
    }
}

extension AbsoluteSymbolLink.LinkComponent {
    /// A suffix attached to a documentation link to disambiguate it from other symbols
    /// that share the same base name.
    public enum DisambiguationSuffix: Equatable, CustomStringConvertible {
        /// The link is not disambiguated.
        case none
        
        /// The symbol's kind.
        case kindIdentifier(String)
        
        /// A hash of the symbol's precise identifier.
        case preciseIdentifierHash(String)
        
        /// The symbol's kind and precise identifier.
        ///
        /// See ``kindIdentifier(_:)`` and ``preciseIdentifierHash(_:)`` for details.
        case kindAndPreciseIdentifier(
            kindIdentifier: String, preciseIdentifierHash: String
        )

        private static func isKnownSymbolKindIdentifier(identifier: String) -> Bool {
            return SymbolGraph.Symbol.KindIdentifier.isKnownIdentifier(identifier)
        }
        
        /// Creates a disambiguation suffix based on the given kind and precise
        /// identifiers.
        init(kindIdentifier: String?, preciseIdentifier: String?) {
            if let kindIdentifier = kindIdentifier, let preciseIdentifier = preciseIdentifier {
                self = .kindAndPreciseIdentifier(
                    kindIdentifier: kindIdentifier,
                    preciseIdentifierHash: preciseIdentifier.stableHashString
                )
            } else if let kindIdentifier = kindIdentifier {
                self = .kindIdentifier(kindIdentifier)
            } else if let preciseIdentifier = preciseIdentifier {
                self = .preciseIdentifierHash(preciseIdentifier.stableHashString)
            } else {
                self = .none
            }
        }
        
        /// Creates a symbol path component disambiguation suffix from the given string.
        init?(string: String) {
            guard !string.isEmpty else {
                self = .none
                return
            }
            
            // We begin by splitting the given string in
            // case this disambiguation suffix includes both an id hash
            // and a kind identifier.
            let splitSuffix = string.split(separator: "-")
            
            if splitSuffix.count == 1 && splitSuffix[0] == string {
                // The string didn't contain a "-" so now we check
                // to see if the hash is a known symbol kind identifier.
                if Self.isKnownSymbolKindIdentifier(identifier: string) {
                    self = .kindIdentifier(string)
                } else {
                    // Since we've confirmed that it's not a symbol kind identifier
                    // we now assume its a hash of the symbol's precise identifier.
                    self = .preciseIdentifierHash(string)
                }
            } else if splitSuffix.count == 2 {
                // The string did contain a "-" so we now know the exact format
                // it should be in.
                //
                // We expect the symbol kind identifier to come first, followed
                // by a hash of the symbol's precise identifier.
                if Self.isKnownSymbolKindIdentifier(identifier: String(splitSuffix[0])) {
                    self = .kindAndPreciseIdentifier(
                        kindIdentifier: String(splitSuffix[0]),
                        preciseIdentifierHash: String(splitSuffix[1])
                    )
                } else {
                    // We were unable to validate the given symbol kind identifier
                    // so this is an invalid format for a disambiguation suffix.
                    return nil
                }
            } else {
                // Unexpected number or configuration of "-" in the given string
                // so we just return nil.
                return nil
            }
        }
        
        public var description: String {
            switch self {
            case .none:
                return "(none)"
            case .kindIdentifier(let kindIdentifier):
                return "(kind: \(kindIdentifier.singleQuoted))"
            case .preciseIdentifierHash(let preciseIdentifierHash):
                return "(idHash: \(preciseIdentifierHash.singleQuoted))"
            case .kindAndPreciseIdentifier(
                kindIdentifier: let kindIdentifier,
                preciseIdentifierHash: let preciseIdentifierHash
            ):
                return "(kind: \(kindIdentifier.singleQuoted), idHash: \(preciseIdentifierHash.singleQuoted))"
            }
        }
        
        /// A string representation of the given disambiguation suffix.
        ///
        /// This value will include the preceding "-" character if necessary.
        /// For example, if this is a ``kindAndPreciseIdentifier(kindIdentifier:preciseIdentifierHash:)`` value,
        /// the following might be returned:
        ///
        /// ```
        /// -swift.var-h73kj
        /// ```
        ///
        /// However, if this is a ``none``, an empty string will be returned.
        public var asLinkSuffixString: String {
            switch self {
            case .none:
                return ""
            case .kindIdentifier(let kindIdentifier):
                return "-\(kindIdentifier)"
            case .preciseIdentifierHash(let preciseIdentifierHash):
                return "-\(preciseIdentifierHash)"
            case .kindAndPreciseIdentifier(
                kindIdentifier: let kindIdentifier,
                preciseIdentifierHash: let preciseIdentifierHash
            ):
                return "-\(kindIdentifier)-\(preciseIdentifierHash)"
            }
        }
    }
}
