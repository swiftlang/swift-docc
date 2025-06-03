/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A collection of API for link completion.
///
/// An example link completion workflow could look something like this;
/// Assume that there's already an partial link in progress: `First/Second-enum/`
///
/// - First, parse the link into link components using ``parse(linkString:)``.
/// - Second, narrow down the possible symbols to suggest as completion using ``SymbolInformation/matches(_:)``
/// - Third, determine the minimal unique disambiguation for each completion suggestion using ``suggestedDisambiguation(forCollidingSymbols:)``
///
/// > Tip: You can use ``SymbolInformation/hash(uniqueSymbolID:)`` to compute the hashed symbol identifiers needed for steps 2 and 3 above.
@_spi(LinkCompletion)  // LinkCompletionTools isn't stable API yet
public enum LinkCompletionTools {
    
    // MARK: Parsing
    
    /// Parses link string into link components; each consisting of a base name and a disambiguation suffix.
    ///
    /// - Parameter linkString: The link string to parse.
    /// - Returns: A list of link components, each consisting of a base name and a disambiguation suffix.
    public static func parse(linkString: String) -> [(name: String, disambiguation: ParsedDisambiguation)] {
        PathHierarchy.PathParser.parse(path: linkString).components.map { pathComponent in
            (name: String(pathComponent.name), disambiguation: ParsedDisambiguation(pathComponent.disambiguation) )
        }
    }
    
    /// A disambiguation suffix for a parsed link component.
    public enum ParsedDisambiguation: Equatable {
        /// This link component isn't disambiguated.
        case none
        
        /// This path component uses a combination of kind and hash disambiguation.
        ///
        /// At least one of `kind` and `hash` will be non-`nil`.
        /// It's never _necessary_ to specify both a `kind` and a `hash` to disambiguate a link component, but it's supported for the developer to include both.
        case kindAndOrHash(kind: String?, hash: String?)
        
        /// This path component uses type signature information for disambiguation.
        ///
        /// At least one of `parameterTypes` and `returnTypes` will be non-`nil`.
        case typeSignature(parameterTypes: [String]?, returnTypes: [String]?)
        
        // This empty-marker case is here because non-frozen enums are only available when Library Evolution is enabled,
        // which is not available to Swift Packages without unsafe flags (rdar://78773361).
        // This can be removed once that is available and applied to Swift-DocC (rdar://89033233).
        @available(*, deprecated, message: "this enum is non-frozen and may be expanded in the future; add a `default` case instead of matching this one")
        case _nonFrozenEnum_useDefaultCase
        
        init(_ disambiguation: PathHierarchy.PathComponent.Disambiguation?) {
            // This initializer is intended to be internal-only.
            switch disambiguation {
            case .kindAndHash(let kind, let hash):
                self = .kindAndOrHash(
                    kind: kind.map { String($0) },
                    hash: hash.map { String($0) }
                )
            case .typeSignature(let parameterTypes, let returnTypes):
                self = .typeSignature(
                    parameterTypes: parameterTypes?.map { String($0) },
                    returnTypes: returnTypes?.map { String($0) }
                )
            case nil:
                self = .none
            }
        }
        
        /// A string representation of the disambiguation.
        public var suffix: String {
            typealias Disambiguation = PathHierarchy.DisambiguationContainer.Disambiguation
            
            switch self {
            case .kindAndOrHash(let kind?, nil):
                return Disambiguation.kind(kind).makeSuffix()
            case .kindAndOrHash(nil,       let hash?):
                return Disambiguation.hash(hash).makeSuffix()
            case .kindAndOrHash(let kind?, let hash?): // This is never necessary but a developer could redundantly write it in a parsed link
                return Disambiguation.kind(kind).makeSuffix() + Disambiguation.hash(hash).makeSuffix()
                
            case .typeSignature(let parameterTypes?, nil):
                return Disambiguation.parameterTypes(parameterTypes).makeSuffix()
            case .typeSignature(nil,                 let returnTypes?):
                return Disambiguation.returnTypes(returnTypes).makeSuffix()
            case .typeSignature(let parameterTypes?, let returnTypes?):
                return Disambiguation.mixedTypes(parameterTypes: parameterTypes, returnTypes: returnTypes).makeSuffix()
                
            // Unexpected error cases
            case .kindAndOrHash(kind: nil, hash: nil):
                assertionFailure("Parsed `.kindAndOrHash` disambiguation missing both kind and hash should use `.none` instead. This is a logic bug.")
                return Disambiguation.none.makeSuffix()
            case .typeSignature(parameterTypes: nil, returnTypes: nil):
                assertionFailure("Parsed `.typeSignature` disambiguation missing both parameter types and return types should use `.none` instead. This is a logic bug.")
                return Disambiguation.none.makeSuffix()
                
            // Since this is within DocC we want to have an error if we don't handle new future cases.
            case .none, ._nonFrozenEnum_useDefaultCase:
                return Disambiguation.none.makeSuffix()
            }
        }
    }
    
    /// Suggests the minimal most readable disambiguation string for each symbol with the same name.
    /// - Parameters:
    ///   - collidingSymbols: A list of symbols that all have the same name.
    /// - Returns: A collection of disambiguation strings in the same order as the provided symbol information.
    ///
    /// - Important: It's the callers responsibility to create symbol information that matches what the compilers emit in symbol graph files.
    ///   If there are mismatches, DocC may suggest disambiguation that won't resolve with the real compiler emitted symbol data.
    public static func suggestedDisambiguation(forCollidingSymbols collidingSymbols: [SymbolInformation]) -> [String] {
        // Track the order of the symbols so that the disambiguations can be ordered to align with their respective symbols.
        var identifiersInOrder: [ResolvedIdentifier] = []
        identifiersInOrder.reserveCapacity(collidingSymbols.count)
        
        // Construct a disambiguation container with all the symbol's information.
        var disambiguationContainer = PathHierarchy.DisambiguationContainer()
        for symbol in collidingSymbols {
            let (node, identifier) = Self._makeNodeAndIdentifier(name: "unused")
            identifiersInOrder.append(identifier)
            
            disambiguationContainer.add(
                node,
                kind: symbol.kind,
                hash: symbol.symbolIDHash,
                parameterTypes: symbol.parameterTypes?.map { $0.withoutWhitespace() },
                returnTypes: symbol.returnTypes?.map { $0.withoutWhitespace() }
            )
        }
        
        let disambiguatedValues = disambiguationContainer.disambiguatedValues()
        // Compute the minimal suggested disambiguation for each symbol and return their string suffixes in the original symbol's order.
        return identifiersInOrder.map { identifier in
            guard let (_, disambiguation) =  disambiguatedValues.first(where: { $0.value.identifier == identifier }) else {
                fatalError("Each node in the `DisambiguationContainer` should always have a entry in the `disambiguatedValues`")
            }
            return disambiguation.makeSuffix()
        }
    }
    
    /// Information about a symbol for link completion purposes.
    ///
    /// > Note:
    /// > This symbol information doesn't include the name.
    /// > It's the callers responsibility to group symbols by their name.
    ///
    /// > Important:
    /// > It's the callers responsibility to create symbol information that matches what the compilers emit in symbol graph files.
    /// > If there are mismatches, DocC may suggest disambiguation that won't resolve with the real compiler emitted symbol data.
    public struct SymbolInformation {
        /// The kind of symbol, for example `"class"` or `"func.op`.
        ///
        /// ## See Also
        /// - ``/SymbolKit/SymbolGraph/Symbol/KindIdentifier``
        public var kind: String
        /// A hash of the symbol's unique identifier.
        ///
        /// ## See Also
        /// - ``hash(uniqueSymbolID:)``
        public var symbolIDHash: String
        /// The type names of this symbol's parameters, or `nil` if this symbol has no function signature information.
        ///
        /// A function without parameters represents i
        public var parameterTypes: [String]?
        /// The type names of this symbol's return value, or `nil` if this symbol has no function signature information.
        public var returnTypes: [String]?
        
        public init(
            kind: String,
            symbolIDHash: String,
            parameterTypes: [String]? = nil,
            returnTypes: [String]? = nil
        ) {
            self.kind = kind
            self.symbolIDHash = symbolIDHash
            self.parameterTypes = parameterTypes
            self.returnTypes = returnTypes
        }
        
        /// Creates a hashed representation of a symbol's unique identifier.
        ///
        /// # See Also
        /// - ``symbolIDHash``
        public static func hash(uniqueSymbolID: String) -> String {
            uniqueSymbolID.stableHashString
        }
        
        // MARK: Filtering
        
        /// Returns a Boolean value that indicates whether this symbol information matches the parsed disambiguation from one of the link components of a parsed link string.
        public func matches(_ parsedDisambiguation: LinkCompletionTools.ParsedDisambiguation) -> Bool {
            guard let disambiguation = PathHierarchy.PathComponent.Disambiguation(parsedDisambiguation) else {
                return true // No disambiguation to match against.
            }
            
            var disambiguationContainer = PathHierarchy.DisambiguationContainer()
            let (node, _) = LinkCompletionTools._makeNodeAndIdentifier(name: "unused")
            
            disambiguationContainer.add(
                node,
                kind: self.kind,
                hash: self.symbolIDHash,
                parameterTypes: self.parameterTypes,
                returnTypes: self.returnTypes
            )
            
            do {
                return try disambiguationContainer.find(disambiguation) != nil
            } catch {
                return false
            }
        }
    }
}

private extension PathHierarchy.PathComponent.Disambiguation {
    init?(_ parsedDisambiguation: LinkCompletionTools.ParsedDisambiguation) {
        switch parsedDisambiguation {
        case .kindAndOrHash(let kind, let hash):
            self = .kindAndHash(kind: kind.map { $0[...] }, hash: hash.map { $0[...] })
            
        case .typeSignature(let parameterTypes, let returnTypes):
            self = .typeSignature(parameterTypes: parameterTypes?.map { $0[...] }, returnTypes: returnTypes?.map { $0[...] })
            
        // Since this is within DocC we want to have an error if we don't handle new future cases.
        case .none, ._nonFrozenEnum_useDefaultCase:
            return nil
        }
    }
}

private extension String {
    func withoutWhitespace() -> String {
        filter { !$0.isWhitespace }
    }
}
