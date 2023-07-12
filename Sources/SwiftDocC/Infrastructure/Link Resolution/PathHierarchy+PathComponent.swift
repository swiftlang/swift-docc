/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

// The path hierarchy implementation is divided into different files for different responsibilities.
// This file defines the functionality for parsing an authored documentation link into components.

/// All known symbol kind identifiers.
///
/// This is used to identify parsed path components as kind information.
private let knownSymbolKinds = Set(SymbolGraph.Symbol.KindIdentifier.allCases.map { $0.identifier })
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
        /// The parsed disambiguation information.
        var disambiguation: Disambiguation?
        
        enum Disambiguation {
            /// This path component uses a combination of kind and hash disambiguation
            case kindAndHash(kind: String?, hash: String?)
            /// This path component uses type signature information for disambiguation.
            case typeSignature(parameterTypes: [String]?, returnTypes: [String]?)
        }
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
            return (components.map(Self.parse(pathComponent:)) + [PathComponent(full: fragment, name: fragment, disambiguation: nil)], isAbsolute)
        }
        
        return (components.map(Self.parse(pathComponent:)), isAbsolute)
    }
    
    /// Parses a single path component string into a structured format.
    static func parse(pathComponent original: Substring) -> PathComponent {
        let full = String(original)
        // Path components may include a trailing disambiguation, separated by a dash.
        guard let dashIndex = original.lastIndex(of: "-") else {
            return PathComponent(full: full, name: full, disambiguation: nil)
        }
        
        let disambiguation = String(original[dashIndex...].dropFirst())
        let name = String(original[..<dashIndex])
        
        func isValidHash(_ hash: String) -> Bool {
            // Checks if a string looks like a truncated, lowercase FNV-1 hash string.
            var index: UInt8 = 0
            for char in hash.utf8 {
                guard index <= 5, (48...57).contains(char) || (97...122).contains(char) else { return false }
                index += 1
            }
            return true
        }
        
        if knownSymbolKinds.contains(disambiguation) {
            // The parsed hash value is a symbol kind. If the last disambiguation is a kind, then the path component doesn't contain a hash disambiguation.
            return PathComponent(full: full, name: name, disambiguation: .kindAndHash(kind: disambiguation, hash: nil))
        }
        if let languagePrefix = knownLanguagePrefixes.first(where: { disambiguation.starts(with: $0) }) {
            // The hash is actually a symbol kind with a language prefix
            return PathComponent(full: full, name: name, disambiguation: .kindAndHash(kind: String(disambiguation.dropFirst(languagePrefix.count)), hash: nil))
        }
        if isValidHash(disambiguation) {
            if let dashIndex = name.lastIndex(of: "-") {
                let kind = String(name[dashIndex...].dropFirst())
                let name = String(name[..<dashIndex])
                if let languagePrefix = knownLanguagePrefixes.first(where: { kind.starts(with: $0) }) {
                    return PathComponent(full: full, name: name, disambiguation: .kindAndHash(kind: String(kind.dropFirst(languagePrefix.count)), hash: disambiguation))
                } else {
                    return PathComponent(full: full, name: name, disambiguation: .kindAndHash(kind: kind, hash: disambiguation))
                }
            }
            return PathComponent(full: full, name: name, disambiguation: .kindAndHash(kind: nil, hash: disambiguation))
        }
        
        // If the disambiguation wasn't a symbol kind or a FNV-1 hash string, check if it looks like a function signature
        if let parsed = parseTypeSignatureDisambiguation(pathComponent: original) {
            return parsed
        }

        // The parsed hash is neither a symbol not a valid hash. It's probably a hyphen-separated name.
        return PathComponent(full: full, name: full, disambiguation: nil)
    }
    
    static func joined<PathComponents>(_ pathComponents: PathComponents) -> String where PathComponents: Sequence, PathComponents.Element == PathComponent {
        return pathComponents.map(\.full).joined(separator: "/")
    }
}
