/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive that adds a prominent button or link to a page's header.
///
/// A "Call to Action" has two main components: a link or file path, and the link text to display.
///
/// The link path can be specified in one of two ways:
/// - The `url` parameter specifies a URL that will be used verbatim. Use this when you're linking
///   to an external page or externally-hosted file.
/// - The `path` parameter specifies the path to a file hosted within your documentation catalog.
///   Use this if you're linking to a downloadable file that you're managing alongside your
///   articles and tutorials.
///
/// The link text can also be specified in one of two ways:
/// - The `purpose` parameter can be used to use a default button label. There are two valid values:
///   - `download` indicates that the link is to a downloadable file. The button will be labeled "Download".
///   - `link` indicates that the link is to an external webpage.
///
///      The button will be labeled "Visit" when used on article pages and "View Source" when used on sample code pages.
/// - The `label` parameter specifies the literal text to use as the button label.
///
/// `@CallToAction` requires one of `url` or `path`, and one of `purpose` or `label`. Specifying both
/// `purpose` and `label` is allowed, but the `label` will override the default label provided by
/// `purpose`.
///
/// This directive is only valid within a ``Metadata`` directive:
///
/// ```markdown
/// @Metadata {
///     @CallToAction(url: "https://example.com/sample.zip", purpose: download)
/// }
/// ```
public final class CallToAction: Semantic, AutomaticDirectiveConvertible {
    /// The kind of action the link is referencing.
    public enum Purpose: String, CaseIterable, DirectiveArgumentValueConvertible {
        /// References a link to download an associated asset, like a sample project.
        case download

        /// References a link to view external content, like a source code repository.
        case link
    }

    /// The location of the associated link, as a fixed URL.
    @DirectiveArgumentWrapped
    public var url: URL? = nil

    /// The location of the associated link, as a reference to a file in this documentation bundle.
    @DirectiveArgumentWrapped(
        parseArgument: { bundle, argumentValue in
            ResourceReference(bundleIdentifier: bundle.identifier, path: argumentValue)
        }
    )
    public var file: ResourceReference? = nil

    /// The purpose of this Call to Action, which provides a default button label.
    @DirectiveArgumentWrapped
    public var purpose: Purpose? = nil

    /// Text to use as the button label, which may override the default provided by a
    /// given `purpose`.
    @DirectiveArgumentWrapped
    public var label: String? = nil

    static var keyPaths: [String : AnyKeyPath] = [
        "url"      : \CallToAction._url,
        "file"     : \CallToAction._file,
        "purpose"  : \CallToAction._purpose,
        "label"    : \CallToAction._label,
    ]

    /// The computed label for this Call to Action, whether provided directly via ``label`` or
    /// indirectly via ``purpose``.
    @available(*, deprecated, renamed: "buttonLabel(for:)")
    public var buttonLabel: String {
        return buttonLabel(for: nil)
    }
    
    /// The label that should be used when rendering the user-interface for this call to action button.
    ///
    /// This can be provided directly via the ``label`` parameter or indirectly via the given ``purpose`` and
    /// associated page kind.
    public func buttonLabel(for pageKind: Metadata.PageKind.Kind?) -> String {
        if let label = label {
            return label
        } else if let purpose = purpose {
            return purpose.defaultLabel(for: pageKind)
        } else {
            // The `validate()` method ensures that this type should never be constructed without
            // one of the above.
            fatalError("A valid CallToAction should have either a purpose or label")
        }
    }

    func validate(
        source: URL?,
        for bundle: DocumentationBundle,
        in context: DocumentationContext,
        problems: inout [Problem]
    ) -> Bool {
        var isValid = true

        if self.url == nil && self.file == nil {
            problems.append(.init(diagnostic: .init(
                source: source,
                severity: .warning,
                range: originalMarkup.range,
                identifier: "org.swift.docc.\(CallToAction.self).missingLink",
                summary: "\(CallToAction.directiveName.singleQuoted) directive requires `url` or `file` argument",
                explanation: "The Call to Action requires a link to direct the user to."
            )))

            isValid = false
        } else if self.url != nil && self.file != nil {
            problems.append(.init(diagnostic: .init(
                source: source,
                severity: .warning,
                range: originalMarkup.range,
                identifier: "org.swift.docc.\(CallToAction.self).tooManyLinks",
                summary: "\(CallToAction.directiveName.singleQuoted) directive requires only one of `url` or `file`",
                explanation: "Both the `url` and `file` arguments specify the link in the heading; specifying both of them creates ambiguity in where the call should link."
            )))

            isValid = false
        }

        if self.purpose == nil && self.label == nil {
            problems.append(.init(diagnostic: .init(
                source: source,
                severity: .warning,
                range: originalMarkup.range,
                identifier: "org.swift.docc.\(CallToAction.self).missingLabel",
                summary: "\(CallToAction.directiveName.singleQuoted) directive requires `purpose` or `label` argument",
                explanation: "Without a `purpose` or `label`, the Call to Action has no label to apply to the link."
            )))

            isValid = false
        }

        return isValid
    }

    public let originalMarkup: Markdown.BlockDirective

    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: Markdown.BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}

extension CallToAction {
    func resolveFile(
        for bundle: DocumentationBundle,
        in context: DocumentationContext,
        problems: inout [Problem]) -> ResourceReference?
    {
        if let file = self.file {
            if context.resolveAsset(named: file.url.lastPathComponent, in: bundle.rootReference) == nil {
                problems.append(.init(
                    diagnostic: Diagnostic(
                        source: url,
                        severity: .warning,
                        range: originalMarkup.range,
                        identifier: "org.swift.docc.Project.ProjectFilesNotFound",
                        summary: "\(file.path) file reference not found in \(CallToAction.directiveName.singleQuoted) directive"),
                    possibleSolutions: [
                        Solution(summary: "Copy the referenced file into the documentation bundle directory", replacements: [])
                    ]
                ))
            } else {
                self.file = ResourceReference(bundleIdentifier: file.bundleIdentifier, path: file.url.lastPathComponent)
            }
        }

        return self.file
    }
}

extension CallToAction.Purpose {
    /// The label that will be applied to a Call to Action with this purpose if it doesn't provide
    /// a separate label.
    @available(*, deprecated, message: "Replaced with 'CallToAction.buttonLabel(for:)'.")
    public var defaultLabel: String {
        return defaultLabel(for: nil)
    }
    
    fileprivate func defaultLabel(for pageKind: Metadata.PageKind.Kind?) -> String {
        switch self {
        case .download:
            return "Download"
        case .link:
            switch pageKind {
            case .article, .none:
                return "Visit"
            case .sampleCode:
                return "View Source"
            }
        }
    }
}
