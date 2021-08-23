/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

extension RenderNodeTranslator {
    
    /// Node translator extension with some exceptions to apply to Swift symbols.
    enum Swift {
        
        /// Applies Swift symbol navigator titles rules to a title.
        /// Will strip the typeIdentifier's precise identifier.
        static func navigatorTitle(for tokens: [DeclarationRenderSection.Token], symbolTitle: String) -> [DeclarationRenderSection.Token] {
            guard tokens.count >= 3 else {
                // Navigator title too short for a type symbol.
                return tokens
            }
            
            // Replace kind "typeIdentifier" with "identifier" if the title matches the pattern:
            // [keyword=class,protocol,enum,typealias,etc.][ ][typeIdentifier=Self]
            
            if tokens[0].kind == DeclarationRenderSection.Token.Kind.keyword
                && tokens[1].text == " "
                && tokens[2].kind == DeclarationRenderSection.Token.Kind.typeIdentifier
                && tokens[2].text == symbolTitle {
                
                // Replace the 2nd token with "identifier" kind.
                return tokens.enumerated().map { pair -> DeclarationRenderSection.Token in
                    if pair.offset == 2 {
                        return DeclarationRenderSection.Token(
                            text: pair.element.text,
                            kind: .identifier
                        )
                    }
                    return pair.element
                }
            }
            return tokens
        }

        private static let initKeyword = DeclarationRenderSection.Token(text: "init", kind: .keyword)
        private static let initIdentifier = DeclarationRenderSection.Token(text: "init", kind: .identifier)
        
        /// Applies Swift symbol subheading rules to a subheading.
        /// Will preserve the typeIdentifier's precise identifier.
        static func subHeading(for tokens: [DeclarationRenderSection.Token], symbolTitle: String, symbolKind: String) -> [DeclarationRenderSection.Token] {
            var tokens = tokens
            
            // 1. Replace kind "typeIdentifier" with "identifier" if the title matches the pattern:
            // [keyword=class,protocol,enum,typealias,etc.][ ][typeIdentifier=Self]
            if tokens.count >= 3 {
                if tokens[0].kind == DeclarationRenderSection.Token.Kind.keyword
                    && tokens[1].text == " "
                    && tokens[2].kind == DeclarationRenderSection.Token.Kind.typeIdentifier
                    && tokens[2].text == symbolTitle {
                    
                    // Replace the 2nd token with "identifier" kind.
                    tokens = tokens.enumerated().map { pair -> DeclarationRenderSection.Token in
                        if pair.offset == 2 {
                            return DeclarationRenderSection.Token(
                                text: pair.element.text,
                                kind: .identifier,
                                preciseIdentifier: pair.element.preciseIdentifier
                            )
                        }
                        return pair.element
                    }
                }
            }
            
            // 2. Map the first found "keyword=init" to an "identifier" kind to enable syntax highlighting.
            let parsedKind = SymbolGraph.Symbol.KindIdentifier(identifier: symbolKind)
            if parsedKind == SymbolGraph.Symbol.KindIdentifier.`init`,
                let initIndex = tokens.firstIndex(of: initKeyword) {
                tokens[initIndex] = initIdentifier
            }
            
            return tokens
        }
    }
}
