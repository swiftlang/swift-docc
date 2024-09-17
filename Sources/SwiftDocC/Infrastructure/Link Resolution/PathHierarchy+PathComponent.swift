/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// All known symbol kind identifiers.
///
/// This is used to identify parsed path components as kind information.
private let knownSymbolKinds: Set<String> = {
    // We don't want to register these extended symbol kinds because that makes them available for decoding from symbol graphs which is unexpected.
    let knownKinds = SymbolGraph.Symbol.KindIdentifier.allCases + [
        .extendedProtocol,
        .extendedStructure,
        .extendedClass,
        .extendedEnumeration,
        .unknownExtendedType,
        .extendedModule
    ]
    return Set(knownKinds.map(\.identifier))
}()

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
        let name: Substring
        /// The parsed disambiguation information, if any.
        var disambiguation: Disambiguation?
        
        enum Disambiguation {
            /// This path component uses a combination of kind and hash disambiguation
            case kindAndHash(kind: Substring?, hash: Substring?)
            /// This path component uses type signature information for disambiguation.
            case typeSignature(parameterTypes: [Substring]?, returnTypes: [Substring]?)
        }
    }
    
    enum PathParser {
        typealias PathComponent = PathHierarchy.PathComponent
    }
}

extension PathHierarchy.PathParser {
    /// Parses a documentation link path (and optional fragment) string into structured path component values.
    ///
    /// For example, a link string like `"/ModuleName/SymbolName-class//=(_:_:)-abc123#HeaderName"` will be parsed into:
    /// ```
    /// (
    ///   components: [
    ///     (name: "ModuleName"),
    ///     (name: "SymbolName", kind: "class"),
    ///     (name: "/=(_:_:)", hash: "abc123"),
    ///     (name: "HeaderName")
    ///   ],
    ///   isAbsolute: true
    /// )
    /// ```
    ///
    /// A few things to note about this behavior:
    ///  - The parser splits components based on both `"/"` and `"#"` (for the last component only)
    ///  - The operator component includes `"/"`, even though that's a separator character.
    ///  - The disambiguation separator character (`-`) isn't included in either of the disambiguated path components.
    ///
    /// - Parameters:
    ///   - path: The documentation link string, containing a path and an optional fragment.
    /// - Returns: A pair of the parsed path components and a flag that indicate if the documentation link is absolute or not.
    static func parse(path: String) -> (components: [PathComponent], isAbsolute: Bool) {
        guard !path.isEmpty else { return ([], true) }
        
        let (components, isAbsolute) = self.split(path)
        return (components.map(Self.parse(pathComponent:)), isAbsolute)
    }
    
    /// Parses a single path component string into a structured format.
    ///
    /// For example, a path component like `"SymbolName-class"` will be split into `(name: "SymbolName", kind: "class")`
    /// and a path component like `"/=(_:_:)-abc123"` will be split into `(name: "/=(_:_:)", hash: "abc123")`.
    static func parse(pathComponent original: Substring) -> PathComponent {
        let full = String(original)
        // Path components may include a trailing disambiguation, separated by a dash.
        guard let dashIndex = original.lastIndex(of: "-") else {
            return PathComponent(full: full, name: full[...], disambiguation: nil)
        }
        
        let disambiguation = original[dashIndex...].dropFirst()
        let name = original[..<dashIndex]
        
        func isValidHash(_ hash: Substring) -> Bool {
            // Checks if a string looks like a truncated, lowercase FNV-1 hash string.
            var index: UInt8 = 0
            for char in hash.utf8 {
                guard index <= 5, (48...57).contains(char) || (97...122).contains(char) else { return false }
                index += 1
            }
            return index > 0
        }
        
        if knownSymbolKinds.contains(String(disambiguation)) {
            // The parsed hash value is a symbol kind. If the last disambiguation is a kind, then the path component doesn't contain a hash disambiguation.
            return PathComponent(full: full, name: name, disambiguation: .kindAndHash(kind: disambiguation, hash: nil))
        }
        if let languagePrefix = knownLanguagePrefixes.first(where: { disambiguation.starts(with: $0) }) {
            // The hash is actually a symbol kind with a language prefix
            return PathComponent(full: full, name: name, disambiguation: .kindAndHash(kind: disambiguation.dropFirst(languagePrefix.count), hash: nil))
        }
        if isValidHash(disambiguation) {
            if let dashIndex = name.lastIndex(of: "-") {
                let kind = name[dashIndex...].dropFirst()
                let name = name[..<dashIndex]
                if knownSymbolKinds.contains(String(kind)) {
                    return PathComponent(full: full, name: name, disambiguation: .kindAndHash(kind: kind, hash: disambiguation))
                } else if let languagePrefix = knownLanguagePrefixes.first(where: { kind.starts(with: $0) }) {
                    let kindWithoutLanguage = kind.dropFirst(languagePrefix.count)
                    return PathComponent(full: full, name: name, disambiguation: .kindAndHash(kind: kindWithoutLanguage, hash: disambiguation))
                }
            }
            return PathComponent(full: full, name: name, disambiguation: .kindAndHash(kind: nil, hash: disambiguation))
        }
        
        // If the disambiguation wasn't a symbol kind or a FNV-1 hash string, check if it looks like a function signature
        if let parsed = parseTypeSignatureDisambiguation(pathComponent: original) {
            return parsed
        }

        // The parsed hash is neither a symbol not a valid hash. It's probably a hyphen-separated name.
        return PathComponent(full: full, name: full[...], disambiguation: nil)
    }
    
    /// Splits the link string into its component substrings and identifies the the link string is an absolute link.
    ///
    /// For example, a link string like `"/ModuleName/SymbolName-class//=(_:_:)-abc123#HeaderName"` will be split into:
    /// ```
    /// (
    ///   componentSubstrings: [
    ///     "ModuleName",
    ///     "SymbolName-class",
    ///     "/=(_:_:)-abc123",
    ///     "HeaderName"
    ///   ],
    ///   isAbsolute: true
    /// )
    /// ```
    static func split(_ path: String) -> (componentSubstrings: [Substring], isAbsolute: Bool) {
        var components: [Substring] = self.split(path)
        
        // As an implementation detail, the way that the path parser identifies that "/ModuleName/SymbolName" is an absolute link, but that "/=(_:_:)" _isn't_
        // an absolute link is by inspecting the first component substring. In both these cases, that substring starts with a "/".
        // However, because the first component of an absolute link needs to be a module name (or "documentation" or "tutorials" for backwards compatibility),
        // the path parser can identify that "ModuleName" (without the leading slash) is a valid module name, but "=(_:_:)" (without the leading slash) isn't.
        // This tells the parser to remove the leading slash from "/ModuleName" and return that this link string represented an absolute link, whereas it leaves
        // "/=(_:_:)" as-is and returns that that link string represented a relative link.
        let isAbsolute: Bool
        if path.first == PathComponentScanner.separator {
            guard let maybeModuleName = components.first?.dropFirst(), !maybeModuleName.isEmpty else {
                return ([], true)
            }
            isAbsolute = maybeModuleName.isValidModuleName()
            assert(NodeURLGenerator.Path.documentationFolderName.isValidModuleName())
            assert(NodeURLGenerator.Path.tutorialsFolderName.isValidModuleName())
            if isAbsolute {
                _ = components[components.startIndex].removeFirst()
            }
        } else {
            let name = components.first.map(String.init)
            isAbsolute = name == NodeURLGenerator.Path.documentationFolderName
                      || name == NodeURLGenerator.Path.tutorialsFolderName
        }
        
        return (components, isAbsolute)
    }
    
    private static func split(_ path: String) -> [Substring] {
        var result = [Substring]()
        var scanner = PathComponentScanner(path[...])
        
        let anchorResult = scanner.scanAnchorComponentAtEnd()
        
        while !scanner.isEmpty {
            let component = scanner.scanPathComponent()
            if !component.isEmpty {
                result.append(component)
            }
        }
        
        if let anchorResult{
            result.append(anchorResult)
        }

        return result
    }
    
    static func parseOperatorName(_ component: Substring) -> Substring? {
        var scanner = PathComponentScanner(component)
        return scanner._scanOperatorName()
    }
}

private struct PathComponentScanner {
    private var remaining: Substring
    
    static let separator: Character = "/"
    private static let anchorSeparator: Character = "#"
    
    static let swiftOperatorEnd: Character = ")"
    
    private static let cxxOperatorPrefix = "operator"
    private static let cxxOperatorPrefixLength = cxxOperatorPrefix.count
    
    init(_ original: Substring) {
        remaining = original
    }
    
    var isEmpty: Bool {
        remaining.isEmpty
    }
    
    mutating func scanPathComponent() -> Substring {
        if let operatorName = _scanOperatorName() {
            return operatorName + scanUntilSeparatorAndThenSkipIt()
        }
        
        // To enable the path parser to identify absolute links, include any leading "/" in the scanned component substring.
        // As an implementation detail, the `PathParser`  is responsible for identifying absolute links so that the scanner doesn't need to
        // track the current location in the original link string and so that `scanPathComponent()` can return only the scanned substring.
        if remaining.first == Self.separator {
            return scanUntil(index: remaining.firstIndex(where: { $0 != Self.separator }))
                 + scanPathComponent()
        }
        
        // If the string doesn't contain a slash then the rest of the string is the component
        return scanUntilSeparatorAndThenSkipIt()
    }
    
    mutating func _scanOperatorName() -> Substring? {
        // If the next component is a Swift operator, parse the full operator before splitting on "/" ("/" may appear in the operator name)
        if remaining.unicodeScalars.prefix(3).allSatisfy(\.isValidSwiftOperatorHead) {
            return scanUntil(index: remaining.firstIndex(of: Self.swiftOperatorEnd)) + scan(length: 1)
        }
        
        // If the next component is a C++ operator, parse the full operator before splitting on "/" ("/" may appear in the operator name)
        if remaining.starts(with: Self.cxxOperatorPrefix),
           remaining.unicodeScalars.dropFirst(Self.cxxOperatorPrefixLength).first?.isValidCxxOperatorSymbol == true
        {
            let base = scan(length: Self.cxxOperatorPrefixLength + 1)
            // Because C++ operators don't include the parameters in the name,
            // a trailing "-" could either be part of the name or be the disambiguation separator.
            //
            // The only valid C++ operators that include a "-" do so at the start.
            // However, "-=", "->", and "->*" don't have a trailing "-", so they're unambiguous.
            // Only "-" and "--" need special parsing to address the ambiguity.
            
            if base.last == "-", remaining.first == "-" {
                // In this scope we start with the following state:
                //
                //     operator--???..
                //     ╰───┬───╯╰─┬╌╌╌
                //       base  remaining
                //
                // There are 3 possible cases that we can be in:
                switch remaining.dropFirst().first {
                // The decrement operator with disambiguation.
                //   operator---h1a2s3h
                //   ╰────┬───╯│╰──┬──╯
                //      name   │ disambiguation
                //         separator
                case "-":
                    return base + scan(length: 1)
                    
                // The decrement operator without disambiguation.
                // Either "operator--", "operator--/", or "operator--#"
                case nil, "/", "#":
                    return base + scan(length: 1)
                     
                // The minus operator with disambiguation.
                //   operator--h1a2s3h
                //   ╰───┬───╯│╰──┬──╯
                //      name  │ disambiguation
                //        separator
                default:
                    return base
                }
            } else {
                // In all other cases, scan as long as there are valid C++ operator characters
                return base
                    + scanUntil(index: remaining.unicodeScalars.firstIndex(where: { $0 == "-" || !$0.isValidCxxOperatorSymbol }))
            }
        }
        
        // Not an operator name
        return nil
    }
    
    mutating func scanAnchorComponentAtEnd() -> Substring? {
        guard let index = remaining.firstIndex(of: Self.anchorSeparator) else {
            return nil
        }
        
        defer { remaining = remaining[..<index] }
        return remaining[index...].dropFirst() // drop the anchor separator
    }
    
    private mutating func scan(length: Int) -> Substring {
        defer { remaining = remaining.dropFirst(length) }
        return remaining.prefix(length)
    }
    
    private mutating func scanUntil(index: Substring.Index?) -> Substring {
        guard let index = index else {
            defer { remaining.removeAll() }
            return remaining
        }
        
        defer { remaining = remaining[index...] }
        return remaining[..<index]
    }
    
    private mutating func scanUntilSeparatorAndThenSkipIt() -> Substring {
        guard let index = remaining.firstIndex(of: Self.separator) else {
            defer { remaining.removeAll() }
            return remaining
        }
        
        defer {
            remaining = remaining[index...].dropFirst() // drop the slash
        }
        return remaining[..<index]
    }
}

private extension StringProtocol {
    /// Checks if a this string is a valid module name.
    ///
    /// Both Swift and Clang require module names to be a valid C99 Extended Identifier.
    func isValidModuleName() -> Bool {
        unicodeScalars.allSatisfy {
            // "-" isn't allowed in module names themselves but it's allowed in link components to separate the disambiguation.
            $0 == "-" || $0.isValidC99ExtendedIdentifier
        }
    }
}

private extension Unicode.Scalar {
    /// Checks if this unicode scalar is a valid C99 Extended Identifier.
    var isValidC99ExtendedIdentifier: Bool {
        // These is based on "swift-tools-support-core/Sources/TSCUtility/StringMangling.swift"
        // but that repo is deprecated and not recommended as a dependency.
        switch value {
        case
            // A-Z
            0x0041...0x005A,
            // a-z
            0x0061...0x007A,
            // 0-9
            0x0030...0x0039,
            // _
            0x005F,
            // Latin (1)
            0x00AA...0x00AA,
            // Special characters (1)
            0x00B5...0x00B5, 0x00B7...0x00B7,
            // Latin (2)
            0x00BA...0x00BA, 0x00C0...0x00D6, 0x00D8...0x00F6,
            0x00F8...0x01F5, 0x01FA...0x0217, 0x0250...0x02A8,
            // Special characters (2)
            0x02B0...0x02B8, 0x02BB...0x02BB, 0x02BD...0x02C1,
            0x02D0...0x02D1, 0x02E0...0x02E4, 0x037A...0x037A,
            // Greek (1)
            0x0386...0x0386, 0x0388...0x038A, 0x038C...0x038C,
            0x038E...0x03A1, 0x03A3...0x03CE, 0x03D0...0x03D6,
            0x03DA...0x03DA, 0x03DC...0x03DC, 0x03DE...0x03DE,
            0x03E0...0x03E0, 0x03E2...0x03F3,
            // Cyrillic
            0x0401...0x040C, 0x040E...0x044F, 0x0451...0x045C,
            0x045E...0x0481, 0x0490...0x04C4, 0x04C7...0x04C8,
            0x04CB...0x04CC, 0x04D0...0x04EB, 0x04EE...0x04F5,
            0x04F8...0x04F9,
            // Armenian (1)
            0x0531...0x0556,
            // Special characters (3)
            0x0559...0x0559,
            // Armenian (2)
            0x0561...0x0587,
            // Hebrew
            0x05B0...0x05B9, 0x05BB...0x05BD, 0x05BF...0x05BF,
            0x05C1...0x05C2, 0x05D0...0x05EA, 0x05F0...0x05F2,
            // Arabic (1)
            0x0621...0x063A, 0x0640...0x0652,
            // Digits (1)
            0x0660...0x0669,
            // Arabic (2)
            0x0670...0x06B7, 0x06BA...0x06BE, 0x06C0...0x06CE,
            0x06D0...0x06DC, 0x06E5...0x06E8, 0x06EA...0x06ED,
            // Digits (2)
            0x06F0...0x06F9,
            // Devanagari and Special character 0x093D.
            0x0901...0x0903, 0x0905...0x0939, 0x093D...0x094D,
            0x0950...0x0952, 0x0958...0x0963,
            // Digits (3)
            0x0966...0x096F,
            // Bengali (1)
            0x0981...0x0983, 0x0985...0x098C, 0x098F...0x0990,
            0x0993...0x09A8, 0x09AA...0x09B0, 0x09B2...0x09B2,
            0x09B6...0x09B9, 0x09BE...0x09C4, 0x09C7...0x09C8,
            0x09CB...0x09CD, 0x09DC...0x09DD, 0x09DF...0x09E3,
            // Digits (4)
            0x09E6...0x09EF,
            // Bengali (2)
            0x09F0...0x09F1,
            // Gurmukhi (1)
            0x0A02...0x0A02, 0x0A05...0x0A0A, 0x0A0F...0x0A10,
            0x0A13...0x0A28, 0x0A2A...0x0A30, 0x0A32...0x0A33,
            0x0A35...0x0A36, 0x0A38...0x0A39, 0x0A3E...0x0A42,
            0x0A47...0x0A48, 0x0A4B...0x0A4D, 0x0A59...0x0A5C,
            0x0A5E...0x0A5E,
            // Digits (5)
            0x0A66...0x0A6F,
            // Gurmukhi (2)
            0x0A74...0x0A74,
            // Gujarti
            0x0A81...0x0A83, 0x0A85...0x0A8B, 0x0A8D...0x0A8D,
            0x0A8F...0x0A91, 0x0A93...0x0AA8, 0x0AAA...0x0AB0,
            0x0AB2...0x0AB3, 0x0AB5...0x0AB9, 0x0ABD...0x0AC5,
            0x0AC7...0x0AC9, 0x0ACB...0x0ACD, 0x0AD0...0x0AD0,
            0x0AE0...0x0AE0,
            // Digits (6)
            0x0AE6...0x0AEF,
            // Oriya and Special character 0x0B3D
            0x0B01...0x0B03, 0x0B05...0x0B0C, 0x0B0F...0x0B10,
            0x0B13...0x0B28, 0x0B2A...0x0B30, 0x0B32...0x0B33,
            0x0B36...0x0B39, 0x0B3D...0x0B43, 0x0B47...0x0B48,
            0x0B4B...0x0B4D, 0x0B5C...0x0B5D, 0x0B5F...0x0B61,
            // Digits (7)
            0x0B66...0x0B6F,
            // Tamil
            0x0B82...0x0B83, 0x0B85...0x0B8A, 0x0B8E...0x0B90,
            0x0B92...0x0B95, 0x0B99...0x0B9A, 0x0B9C...0x0B9C,
            0x0B9E...0x0B9F, 0x0BA3...0x0BA4, 0x0BA8...0x0BAA,
            0x0BAE...0x0BB5, 0x0BB7...0x0BB9, 0x0BBE...0x0BC2,
            0x0BC6...0x0BC8, 0x0BCA...0x0BCD,
            // Digits (8)
            0x0BE7...0x0BEF,
            // Telugu
            0x0C01...0x0C03, 0x0C05...0x0C0C, 0x0C0E...0x0C10,
            0x0C12...0x0C28, 0x0C2A...0x0C33, 0x0C35...0x0C39,
            0x0C3E...0x0C44, 0x0C46...0x0C48, 0x0C4A...0x0C4D,
            0x0C60...0x0C61,
            // Digits (9)
            0x0C66...0x0C6F,
            // Kannada
            0x0C82...0x0C83, 0x0C85...0x0C8C, 0x0C8E...0x0C90,
            0x0C92...0x0CA8, 0x0CAA...0x0CB3, 0x0CB5...0x0CB9,
            0x0CBE...0x0CC4, 0x0CC6...0x0CC8, 0x0CCA...0x0CCD,
            0x0CDE...0x0CDE, 0x0CE0...0x0CE1,
            // Digits (10)
            0x0CE6...0x0CEF,
            // Malayam
            0x0D02...0x0D03, 0x0D05...0x0D0C, 0x0D0E...0x0D10,
            0x0D12...0x0D28, 0x0D2A...0x0D39, 0x0D3E...0x0D43,
            0x0D46...0x0D48, 0x0D4A...0x0D4D, 0x0D60...0x0D61,
            // Digits (11)
            0x0D66...0x0D6F,
            // Thai...including Digits 0x0E50...0x0E59 }
            0x0E01...0x0E3A, 0x0E40...0x0E5B,
            // Lao (1)
            0x0E81...0x0E82, 0x0E84...0x0E84, 0x0E87...0x0E88,
            0x0E8A...0x0E8A, 0x0E8D...0x0E8D, 0x0E94...0x0E97,
            0x0E99...0x0E9F, 0x0EA1...0x0EA3, 0x0EA5...0x0EA5,
            0x0EA7...0x0EA7, 0x0EAA...0x0EAB, 0x0EAD...0x0EAE,
            0x0EB0...0x0EB9, 0x0EBB...0x0EBD, 0x0EC0...0x0EC4,
            0x0EC6...0x0EC6, 0x0EC8...0x0ECD,
            // Digits (12)
            0x0ED0...0x0ED9,
            // Lao (2)
            0x0EDC...0x0EDD,
            // Tibetan (1)
            0x0F00...0x0F00, 0x0F18...0x0F19,
            // Digits (13)
            0x0F20...0x0F33,
            // Tibetan (2)
            0x0F35...0x0F35, 0x0F37...0x0F37, 0x0F39...0x0F39,
            0x0F3E...0x0F47, 0x0F49...0x0F69, 0x0F71...0x0F84,
            0x0F86...0x0F8B, 0x0F90...0x0F95, 0x0F97...0x0F97,
            0x0F99...0x0FAD, 0x0FB1...0x0FB7, 0x0FB9...0x0FB9,
            // Georgian
            0x10A0...0x10C5, 0x10D0...0x10F6,
            // Latin (3)
            0x1E00...0x1E9B, 0x1EA0...0x1EF9,
            // Greek (2)
            0x1F00...0x1F15, 0x1F18...0x1F1D, 0x1F20...0x1F45,
            0x1F48...0x1F4D, 0x1F50...0x1F57, 0x1F59...0x1F59,
            0x1F5B...0x1F5B, 0x1F5D...0x1F5D, 0x1F5F...0x1F7D,
            0x1F80...0x1FB4, 0x1FB6...0x1FBC,
            // Special characters (4)
            0x1FBE...0x1FBE,
            // Greek (3)
            0x1FC2...0x1FC4, 0x1FC6...0x1FCC, 0x1FD0...0x1FD3,
            0x1FD6...0x1FDB, 0x1FE0...0x1FEC, 0x1FF2...0x1FF4,
            0x1FF6...0x1FFC,
            // Special characters (5)
            0x203F...0x2040,
            // Latin (4)
            0x207F...0x207F,
            // Special characters (6)
            0x2102...0x2102, 0x2107...0x2107, 0x210A...0x2113,
            0x2115...0x2115, 0x2118...0x211D, 0x2124...0x2124,
            0x2126...0x2126, 0x2128...0x2128, 0x212A...0x2131,
            0x2133...0x2138, 0x2160...0x2182, 0x3005...0x3007,
            0x3021...0x3029,
            // Hiragana
            0x3041...0x3093, 0x309B...0x309C,
            // Katakana
            0x30A1...0x30F6, 0x30FB...0x30FC,
            // Bopmofo [sic]
            0x3105...0x312C,
            // CJK Unified Ideographs
            0x4E00...0x9FA5,
            // Hangul,
            0xAC00...0xD7A3:
            return true
        default:
            return false
        }
    }
       
    var isValidCxxOperatorSymbol: Bool {
        switch value {
        // ! % & ( ) * + , - / < = > [ ] ^ | ~
        case 0x21, 0x25, 0x26, 0x28...0x2D, 0x2F, 0x3C...0x3E, 0x5B, 0x5D, 0x5E, 0x7C, 0x7E:
            return true
        default:
            return false
        }
    }
    
    var isValidSwiftOperatorHead: Bool {
        // See https://docs.swift.org/swift-book/documentation/the-swift-programming-language/lexicalstructure#Operators
        switch value {
        case 
            // ! % & * + - . / < = > ? ^| ~
            0x21, 0x25, 0x26, 0x2A, 0x2B, 0x2D...0x2F, 0x3C, 0x3D...0x3F, 0x5E, 0x7C, 0x7E,
            // ¡ ¢ £ ¤ ¥ ¦ §
            0xA1 ... 0xA7,
            // © «
            0xA9, 0xAB ,
            // ¬ ®
            0xAC, 0xAE ,
            // ° ±
            0xB0 ... 0xB1,
            // ¶ » ¿ × ÷
            0xB6, 0xBB, 0xBF, 0xD7, 0xF7 ,
            // ‖ ‗
            0x2016 ... 0x2017,
            // † ‡ • ‣ ․ ‥ … ‧
            0x2020 ... 0x2027,
            // ‰ ‱ ′ ″ ‴ ‵ ‶ ‷ ‸ ‹ › ※ ‼ ‽ ‾
            0x2030 ... 0x203E,
            // ⁁ ⁂ ⁃ ⁄ ⁅ ⁆ ⁇ ⁈ ⁉ ⁊ ⁋ ⁌ ⁍ ⁎ ⁏ ⁐ ⁑ ⁒ ⁓
            0x2041 ... 0x2053,
            // ⁕ ⁖ ⁗ ⁘ ⁙ ⁚ ⁛ ⁜ ⁝ ⁞
            0x2055 ... 0x205E,
            // Box Drawing
            0x2500 ... 0x257F,
            // Block Elements
            0x2580 ... 0x259F,
            // Geometric Shapes,
            0x25A0 ... 0x25FF,
            // Miscellaneous Symbols
            0x2600 ... 0x26FF,
            // Dingbats
            0x2700 ... 0x27BF,
            // Miscellaneous Mathematical Symbols-A
            0x27C0 ... 0x27EF,
            // Supplemental Arrows-A
            0x27F0 ... 0x27FF,
            // Braille Patterns
            0x2800 ... 0x28FF,
            // Supplemental Arrows-B
            0x2900 ... 0x297F,
            // Miscellaneous Mathematical Symbols-B
            0x2980 ... 0x29FF,
            // Supplemental Mathematical Operators
            0x2A00 ... 0x2AFF,
            // Miscellaneous Symbols and Arrows
            0x2B00 ... 0x2BFF,
            // Supplemental Punctuation
            0x2E00 ... 0x2E7F,
            // 、 。 〃
            0x3001 ... 0x3003,
            //〈 〉 《 》 「 」 『 』 【 】 〒 〓 〔 〕 〖 〗 〘 〙 〚 〛 〜 〝 〞 〟 〠
            0x3008 ... 0x3020,
            // 〰
            0x3030:
            return true
        default:
            return false
        }
    }
}
