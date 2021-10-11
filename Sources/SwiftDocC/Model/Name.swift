/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
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
        /// The name of the symbol is derived from its declaration.
        case symbol(declaration: AttributedCodeListing.Line)
        
        public func hash(into hasher: inout Hasher) {
            switch self {
            case .conceptual(let text):
                hasher.combine(text)
            case .symbol(let declaration):
                hasher.combine(declaration)
            }
        }
        
        public var description: String {
            switch self {
            case .conceptual(let title):
                return title
            case .symbol(let declaration):
                return declaration.tokens.map { $0.description }.joined(separator: " ")
            }
        }
    }
}
