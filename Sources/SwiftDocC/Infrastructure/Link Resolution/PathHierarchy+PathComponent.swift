/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SymbolKit

/// All known symbol kind identifiers.
///
/// This is used to identify parsed path components as kind information.
private let knownSymbolKinds = Set<String>(
    (SymbolGraph.Symbol.KindIdentifier.allCases + [
        .extendedProtocol,
        .extendedStructure,
        .extendedClass,
        .extendedEnumeration,
        .unknownExtendedType,
        .extendedModule,
    ]).map(\.identifier)
)
/// All known source language identifiers.
///
/// This is used to skip language prefixes from kind disambiguation information.
private let knownLanguagePrefixes = SourceLanguage.knownLanguages.flatMap { [$0.id] + $0.idAliases }.map { $0 + "." }

extension PathHierarchy {
    /// The parsed information for a documentation URI path component.
    struct PathComponent {
        /// The full original path component
        let full: String
        /// The parsed entity name
        let name: String
        /// The parsed entity kind, if any.
        var kind: String?
        /// The parsed entity hash, if any.
        var hash: String?
    }
    
    /// Parsed a documentation link path (and optional fragment) string into structured path component values.
    /// - Parameters:
    ///   - path: The documentation link string, containing a path and an optional fragment.
    ///   - omittingEmptyComponents: If empty path components should be omitted from the parsed path. By default the are omitted.
    /// - Returns: A pair of the parsed path components and a flag that indicate if the documentation link is absolute or not.
    static func parse(path: String, omittingEmptyComponents: Bool = true) -> (components: [PathComponent], isAbsolute: Bool) {
        guard !path.isEmpty else { return ([], true) }
        var components = path.split(separator: "/", omittingEmptySubsequences: omittingEmptyComponents)
        let isAbsolute = path.first == "/"
            || String(components.first ?? "") == NodeURLGenerator.Path.documentationFolderName
            || String(components.first ?? "") == NodeURLGenerator.Path.tutorialsFolderName

        // If there is a # character in the last component, split that into two components
        if let hashIndex = components.last?.firstIndex(of: "#") {
            let last = components.removeLast()
            // Allow anrhor-only links where there's nothing before #.
            // In case the pre-# part is empty, and we're omitting empty components, don't add it in.
            let pathName = last[..<hashIndex]
            if !pathName.isEmpty || !omittingEmptyComponents {
                components.append(pathName)
            }
            
            let fragment = String(last[hashIndex...].dropFirst())
            return (components.map(Self.parse(pathComponent:)) + [PathComponent(full: fragment, name: fragment, kind: nil, hash: nil)], isAbsolute)
        }
        
        return (components.map(Self.parse(pathComponent:)), isAbsolute)
    }
    
    /// Parses a single path component string into a structured format.
     static func parse(pathComponent original: Substring) -> PathComponent {
        let full = String(original)
        guard let dashIndex = original.lastIndex(of: "-") else {
            return PathComponent(full: full, name: full, kind: nil, hash: nil)
        }
        
        let hash = String(original[dashIndex...].dropFirst())
        let name = String(original[..<dashIndex])
        
        func isValidHash(_ hash: String) -> Bool {
            var index: UInt8 = 0
            for char in hash.utf8 {
                guard index <= 5, (48...57).contains(char) || (97...122).contains(char) else { return false }
                index += 1
            }
            return true
        }
        
        if knownSymbolKinds.contains(hash) {
            // The parsed hash value is a symbol kind
            return PathComponent(full: full, name: name, kind: hash, hash: nil)
        }
        if let languagePrefix = knownLanguagePrefixes.first(where: { hash.starts(with: $0) }) {
            // The hash is actually a symbol kind with a language prefix
            return PathComponent(full: full, name: name, kind: String(hash.dropFirst(languagePrefix.count)), hash: nil)
        }
        if !isValidHash(hash) {
            // The parsed hash is neither a symbol not a valid hash. It's probably a hyphen-separated name.
            return PathComponent(full: full, name: full, kind: nil, hash: nil)
        }
        
        if let dashIndex = name.lastIndex(of: "-") {
            let kind = String(name[dashIndex...].dropFirst())
            let name = String(name[..<dashIndex])
            if let languagePrefix = knownLanguagePrefixes.first(where: { kind.starts(with: $0) }) {
                return PathComponent(full: full, name: name, kind: String(kind.dropFirst(languagePrefix.count)), hash: hash)
            } else {
                return PathComponent(full: full, name: name, kind: kind, hash: hash)
            }
        }
        return PathComponent(full: full, name: name, kind: nil, hash: hash)
    }
    
    static func joined<PathComponents>(_ pathComponents: PathComponents) -> String where PathComponents: Sequence, PathComponents.Element == PathComponent {
        return pathComponents.map(\.full).joined(separator: "/")
    }
}
