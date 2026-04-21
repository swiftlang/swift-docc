/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
public import Markdown

/**
 A general purpose comment directive. All contents inside are stripped from
 
 > Warning: Content inside a comment should be considered absolutely confidential to the author. Never emit comments in anything that an end-user can receive. As an example, comments should not be emitted in ``RenderNode`` JSON.
 */
public final class Comment: Semantic, DirectiveConvertible {
    public static let directiveName = "Comment"
    public static let introducedVersion = "5.5"
    public let originalMarkup: BlockDirective
    
    /// The comment content.
    public let content: MarkupContainer
    
    override var children: [Semantic] {
        return [content]
    }
    
    init(originalMarkup: BlockDirective, content: MarkupContainer) {
        self.originalMarkup = originalMarkup
        self.content = content
    }
    
    @available(*, deprecated, renamed: "init(from:source:for:featureFlags:diagnostics:)", message: "Use 'init(from:source:for:featureFlags:diagnostics:)' instead. This deprecated API will be removed after 6.5 is released.")
    public convenience init?(from directive: BlockDirective, source: URL?, for unusedBundle: DocumentationBundle, featureFlags unusedFeatures: FeatureFlags, problems: inout [Problem]) {
        var diagnostics = [Diagnostic]()
        defer {
            problems.append(contentsOf: diagnostics.map { .init(diagnostic: $0) })
        }
        self.init(from: directive, source: source, for: unusedBundle, featureFlags: unusedFeatures, diagnostics: &diagnostics)
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for _: DocumentationBundle, featureFlags _: FeatureFlags, diagnostics: inout [Diagnostic]) {
        precondition(directive.name == Comment.directiveName)
        self.init(originalMarkup: directive, content: MarkupContainer(directive.children))
    }
}
