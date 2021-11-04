/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A type that resolves values that are appropriate as link titles for documentation nodes.
struct LinkTitleResolver {
    /// The context to use when resolving the title of a given documentation node.
    var context: DocumentationContext
    /// The location of the source file that this documentation node's content originated from.
    ///
    /// This value will be used if the title can only be determined by semantically parsing the documentation node's content.
    var source: URL?
    
    /// Resolves the title that's appropriate for presentation as a link title for a given documentation node.
    ///
    /// Depending on the page type, semantic parsing may be necessary to determine the title of the page.
    ///
    /// - Parameter page: The page for which to resolve the title.
    /// - Returns: The variants of the link title for this page, or `nil` if the page doesn't exist in the context.
    func title(for page: DocumentationNode) -> DocumentationDataVariants<String>? {
        if let bundle = context.bundle(identifier: page.reference.bundleIdentifier),
           let directive = page.markup.child(at: 0) as? BlockDirective {
            
            var problems = [Problem]()
            switch directive.name {
            case Tutorial.directiveName:
                if let tutorial = Tutorial(from: directive, source: source, for: bundle, in: context, problems: &problems) {
                    return .init(defaultVariantValue: tutorial.intro.title)
                }
            case Technology.directiveName:
                if let overview = Technology(from: directive, source: source, for: bundle, in: context, problems: &problems) {
                    return .init(defaultVariantValue: overview.name)
                }
            default: break
            }
        }
        
        if case let .conceptual(name) = page.name {
            return .init(defaultVariantValue: name)
        }
        
        if let symbol = (page.semantic as? Symbol) {
            return symbol.titleVariants
        }
        
        if let symbol = page.symbol {
            return .init(defaultVariantValue: symbol.names.title)
        }
        
        if let article = page.semantic as? Article, let title = article.title?.plainText {
            return .init(defaultVariantValue: title)
        }
        
        return nil
    }
}
