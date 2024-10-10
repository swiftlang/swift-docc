/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SwiftParser
import SwiftSyntax
import SymbolKit

extension SymbolGraph.Symbol.DeclarationFragments.Fragment {
    init(
        spelling: String,
        kind: Kind = .text,
        preciseIdentifier: String? = nil
    ) {
        self.init(
            kind: kind,
            spelling: spelling,
            preciseIdentifier: preciseIdentifier
        )
    }
}

extension Trivia {
    var text: String? {
        guard pieces.count > 0 else {
            return nil
        }

        var string: String = ""
        write(to: &string)
        return string
    }
}

extension TokenSyntax {
    var leadingText: String? {
        leadingTrivia.text
    }

    var trailingText: String? {
        trailingTrivia.text
    }
}

/// A subclass of `SwiftSyntax.SyntaxVisitor` which can traverse a syntax tree
/// and build up a simpler, flat `Fragment` array representing it.
///
/// The main job of this class is to help convert a formatted string for a Swift
/// symbol declaration back into a list of fragments that closely resemble how
/// the same code would be presented in a `SymbolKit` symbol graph.
final class FragmentBuilder: SyntaxVisitor {
    typealias Fragment = SymbolGraph.Symbol.DeclarationFragments.Fragment

    private var identifiers: [String:String]
    private var fragments: [Fragment]

    init() {
        identifiers = [:]
        fragments = []
        super.init(viewMode: .sourceAccurate)
    }

    /// Returns an array of `Fragment` elements that represents the given String
    /// of Swift source code.
    ///
    /// - Parameter source: A string of Swift source code.
    /// - Parameter identifiers: A lookup table of symbol names and precise
    ///      identifiers to map them to.
    ///
    /// - Returns: An array of `Fragment` elements.
    func buildFragments(
        from source: String,
        identifiers: [String:String] = [:]
    ) -> [Fragment] {
        let syntax = Parser.parse(source: source)
        return buildFragments(from: syntax, identifiers: identifiers)
    }

    func buildFragments(
        from syntax: some SyntaxProtocol,
        identifiers: [String:String] = [:]
    ) -> [Fragment] {
        self.identifiers = identifiers
        fragments = []

        walk(syntax)

        return fragments
    }

    override func visit(_ node: AttributeSyntax) -> SyntaxVisitorContinueKind {
        walk(node.atSign)

        let name = node.attributeName.as(TypeSyntaxEnum.self)
        switch name {
        case .identifierType(let idType):
            emitFragments(for: idType.name, as: .attribute)
            if let genericArgumentClause = idType.genericArgumentClause {
                walk(genericArgumentClause)
            }
        default:
            walk(node.attributeName)
        }

        if let leftParen = node.leftParen {
            walk(leftParen)
        }
        if let args = node.arguments {
            walk(args)
        }
        if let rightParen = node.rightParen {
            walk(rightParen)
        }

        return .skipChildren
    }

    override func visit(_ node: FunctionParameterSyntax) -> SyntaxVisitorContinueKind {
        walk(node.attributes)
        walk(node.modifiers)

        emitFragments(for: node.firstName, as: .externalParameter)
        if let secondName = node.secondName {
            emitFragments(for: secondName, as: .internalParameter)
        }

        walk(node.colon)
        walk(node.type)
        if let ellipsis = node.ellipsis {
            walk(ellipsis)
        }
        if let defaultValue = node.defaultValue {
            walk(defaultValue)
        }
        if let trailingComma = node.trailingComma {
            walk(trailingComma)
        }

        return .skipChildren
    }

    override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
        emitFragments(for: node.name, as: .typeIdentifier)

        if let genericArgumentClause = node.genericArgumentClause {
            walk(genericArgumentClause)
        }

        return .skipChildren
    }

    override func visit(_ node: MemberTypeSyntax) -> SyntaxVisitorContinueKind {
        walk(node.baseType)
        walk(node.period)

        emitFragments(for: node.name, as: .typeIdentifier)

        if let genericArgumentClause = node.genericArgumentClause {
            walk(genericArgumentClause)
        }

        return .skipChildren
    }

    override func visit(_ token: TokenSyntax) -> SyntaxVisitorContinueKind {
        let kind: Fragment.Kind = switch token.tokenKind {
            case .integerLiteral: .numberLiteral
            case .atSign, .keyword: .keyword
            case .stringQuote, .stringSegment: .stringLiteral
            default: .text
        }
        emitFragments(for: token, as: kind)

        return .skipChildren
    }

    private func emit(fragment: Fragment) {
        if let lastFragment = fragments.last,
            lastFragment.preciseIdentifier == nil,
            fragment.preciseIdentifier == nil,
            lastFragment.kind == fragment.kind {
            // if we're going to emit the same fragment kind as the last one,
            // go ahead and just combine them together into a single fragment
            // (unless this is an identifier type)
            fragments = fragments.dropLast()
            fragments.append(Fragment(
                spelling: lastFragment.spelling + fragment.spelling,
                kind: lastFragment.kind
            ))
        } else {
            // add a new fragment that has a distinct kind from the last one
            var newFragment = fragment
            newFragment.preciseIdentifier = identifiers[fragment.spelling]
            fragments.append(newFragment)
        }
    }

    private func emitFragments(for token: TokenSyntax, as kind: Fragment.Kind) {
        if let leadingText = token.leadingText {
            emit(fragment: Fragment(spelling: leadingText))
        }

        emit(fragment: Fragment(spelling: token.text, kind: kind))

        if let trailingText = token.trailingText {
            emit(fragment: Fragment(spelling: trailingText))
        }
    }
}
