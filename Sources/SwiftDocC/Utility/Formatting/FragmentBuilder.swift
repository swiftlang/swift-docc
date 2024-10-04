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

final class FragmentBuilder: SyntaxVisitor {
    typealias Fragment = SymbolGraph.Symbol.DeclarationFragments.Fragment

    private var fragments: [Fragment]

    init() {
        fragments = []
        super.init(viewMode: .sourceAccurate)
    }

    func buildFragments(from source: String) -> [Fragment] {
        let syntax = Parser.parse(source: source)
        return buildFragments(from: syntax)
    }

    func buildFragments(from syntax: some SyntaxProtocol) -> [Fragment] {
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
        // TODO: consider joining multiple fragments of the same kind as an
        // optimization to reduce the number of array items in the JSON output
        fragments.append(fragment)
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
