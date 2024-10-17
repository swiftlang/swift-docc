/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension DocumentationNode {
    /**
     The annotated name of a node.
     
     Extend this type to transform the name of a node into various forms,
     such as for display as a title or in a task group, or normalized for
     search indexing.
     */
    public enum Name: Hashable, CustomStringConvertible {
        /// The name of a conceptual document is its title.
        case conceptual(title: String)
        /// The name of the symbol.
        case symbol(name: String)
        
        public var description: String {
            switch self {
            case .conceptual(let title):
                return title
            case .symbol(let name):
                return name
            }
        }
        
        var plainText: String {
            description
        }
        
        @available(*, deprecated, message: "This deprecated API will be removed after 6.1 is released")
        static func symbol(declaration: AttributedCodeListing.Line) -> Name {
            // This static function exists so that `Name.symbol(declaration:)` is available while 
            // still allowing switching over the two "symbol" name cases.
            Name.symbol(name: declaration.tokens.first?.description ?? "")
        }
    }
}
