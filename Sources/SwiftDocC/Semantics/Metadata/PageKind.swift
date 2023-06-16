/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

extension Metadata {
    /// A directive that allows you to set a page's kind, which affects its default title heading and page icon.
    ///
    /// The `@PageKind` directive tells Swift-DocC to treat a documentation page as a particular
    /// "kind". This is used to determine the page's default navigator icon, as well as the default
    /// title heading on the page itself.
    ///
    /// The available page kinds are `article` and `sampleCode`.
    ///
    /// This directive is only valid within a `@Metadata` directive:
    ///
    /// ```markdown
    /// @Metadata {
    ///     @PageKind(sampleCode)
    /// }
    /// ```
    public final class PageKind: Semantic, AutomaticDirectiveConvertible {
        /// The available kinds for use with the `@PageKind` directive.
        public enum Kind: String, CaseIterable, DirectiveArgumentValueConvertible {
            /// An article of free-form text; the default for standalone markdown files.
            case article
            /// A page describing a "sample code" project.
            case sampleCode

            var renderRole: RenderMetadata.Role {
                switch self {
                case .article:
                    return RenderMetadata.Role.article
                case .sampleCode:
                    return RenderMetadata.Role.sampleCode
                }
            }

            var titleHeading: String {
                switch self {
                case .article:
                    return "Article"
                case .sampleCode:
                    return "Sample Code"
                }
            }

            var documentationNodeKind: DocumentationNode.Kind {
                switch self {
                case .article:
                    return .article
                case .sampleCode:
                    return .sampleCode
                }
            }
        }

        /// The page kind to apply to the page.
        @DirectiveArgumentWrapped(name: .unnamed)
        public var kind: Kind

        static var keyPaths: [String : AnyKeyPath] = [
            "kind" : \PageKind._kind
        ]

        public let originalMarkup: Markdown.BlockDirective

        @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
        init(originalMarkup: Markdown.BlockDirective) {
            self.originalMarkup = originalMarkup
        }
    }
}
