import SymbolKit

extension DeclarationsSectionTranslator {
    typealias DeclarationFragments = SymbolGraph.Symbol.DeclarationFragments
    typealias Fragment = DeclarationFragments.Fragment

    func formatted(declarations: [[PlatformName?]:DeclarationFragments])
        -> [[PlatformName?]:DeclarationFragments] {
        declarations.mapValues { formatted(declaration: $0) }
    }

    func formatted(declaration: DeclarationFragments) -> DeclarationFragments {
        let formattedFragments = formatted(fragments: declaration.declarationFragments)
        return DeclarationFragments(declarationFragments: formattedFragments)
    }

    func formatted(fragments: [Fragment]) -> [Fragment] {
        fragments // TODO
    }
}
