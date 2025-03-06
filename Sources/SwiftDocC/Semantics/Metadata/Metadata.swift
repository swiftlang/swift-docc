/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive that contains various metadata about a page.
///
/// This directive acts as a container for metadata and configuration without any arguments of its own.
///
/// ## Topics
/// 
/// ### Child Directives
///
/// - ``AlternateRepresentation``
/// - ``DocumentationExtension``
/// - ``TechnologyRoot``
/// - ``DisplayName``
/// - ``PageImage``
/// - ``PageColor``
/// - ``CallToAction``
/// - ``Availability``
/// - ``PageKind``
/// - ``SupportedLanguage``
/// - ``TitleHeading``
public final class Metadata: Semantic, AutomaticDirectiveConvertible {
    public static let introducedVersion = "5.5"
    public let originalMarkup: BlockDirective
    
    /// Configuration that describes how this documentation extension file merges or overrides the in-source documentation.
    @ChildDirective
    var documentationOptions: DocumentationExtension? = nil
    
    /// Configuration to make this page root-level documentation.
    @ChildDirective
    var technologyRoot: TechnologyRoot? = nil
    
    /// Configuration to customize this page's symbol's display name.
    @ChildDirective
    var displayName: DisplayName? = nil
    
    /// The optional, custom image used to represent this page.
    @ChildDirective(requirements: .zeroOrMore)
    var pageImages: [PageImage]
    
    @ChildDirective(requirements: .zeroOrMore)
    var customMetadata: [CustomMetadata]

    @ChildDirective
    var callToAction: CallToAction? = nil

    @ChildDirective(requirements: .zeroOrMore)
    var availability: [Availability]

    @ChildDirective
    var pageKind: PageKind? = nil
    
    @ChildDirective(requirements: .zeroOrMore)
    var supportedLanguages: [SupportedLanguage]
    
    @ChildDirective
    var _pageColor: PageColor? = nil
    
    /// The optional, context-dependent color used to represent this page.
    var pageColor: PageColor.Color? {
        _pageColor?.color
    }

    @ChildDirective
    var titleHeading: TitleHeading? = nil

    @ChildDirective
    var redirects: [Redirect]? = nil
    
    @ChildDirective(requirements: .zeroOrMore)
    var alternateRepresentations: [AlternateRepresentation]

    static var keyPaths: [String : AnyKeyPath] = [
        "documentationOptions"  : \Metadata._documentationOptions,
        "technologyRoot"        : \Metadata._technologyRoot,
        "displayName"           : \Metadata._displayName,
        "pageImages"            : \Metadata._pageImages,
        "customMetadata"        : \Metadata._customMetadata,
        "callToAction"          : \Metadata._callToAction,
        "availability"          : \Metadata._availability,
        "pageKind"              : \Metadata._pageKind,
        "supportedLanguages"    : \Metadata._supportedLanguages,
        "_pageColor"            : \Metadata.__pageColor,
        "titleHeading"          : \Metadata._titleHeading,
        "redirects"             : \Metadata._redirects,
        "alternateRepresentations"  : \Metadata._alternateRepresentations,
    ]
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
    
    func validate(source: URL?, problems: inout [Problem]) -> Bool {
        // Check that something is configured in the metadata block
        if documentationOptions == nil && technologyRoot == nil && displayName == nil && pageImages.isEmpty && customMetadata.isEmpty && callToAction == nil && availability.isEmpty && pageKind == nil && pageColor == nil && titleHeading == nil && redirects == nil && alternateRepresentations.isEmpty {
            let diagnostic = Diagnostic(
                source: source,
                severity: .information,
                range: originalMarkup.range,
                identifier: "org.swift.docc.\(Metadata.directiveName).NoConfiguration",
                summary: "\(Metadata.directiveName.singleQuoted) doesn't configure anything and has no effect"
            )
            
            let solutions = originalMarkup.range.map {
                [Solution(summary: "Remove this \(Metadata.directiveName.singleQuoted) directive.", replacements: [Replacement(range: $0, replacement: "")])]
            } ?? []
            problems.append(Problem(diagnostic: diagnostic, possibleSolutions: solutions))
        }
        
        // Check that there is only a single `@PageImage` directive for each supported purpose
        var categorizedPageImages = [PageImage.Purpose : [PageImage]]()
        for pageImage in pageImages {
            categorizedPageImages[pageImage.purpose, default: []].append(pageImage)
        }
        
        for pageImages in categorizedPageImages.values {
            guard pageImages.count > 1 else {
                continue
            }
            
            for extraPageImage in pageImages {
                let diagnostic = Diagnostic(
                    source: extraPageImage.originalMarkup.nameLocation?.source,
                    severity: .warning,
                    range: extraPageImage.originalMarkup.range,
                    identifier: "org.swift.docc.DuplicatePageImage",
                    summary: "Duplicate \(PageImage.directiveName.singleQuoted) directive with \(extraPageImage.purpose.rawValue.singleQuoted) purpose",
                    explanation: """
                    A documentation page can only contain a single \(PageImage.directiveName.singleQuoted) \
                    directive for each purpose.
                    """
                )
                
                guard let range = extraPageImage.originalMarkup.range else {
                    problems.append(Problem(diagnostic: diagnostic))
                    continue
                }
                
                let solution = Solution(
                    summary: "Remove extraneous \(extraPageImage.purpose.rawValue.singleQuoted) \(PageImage.directiveName.singleQuoted) directive",
                    replacements: [
                        Replacement(range: range, replacement: "")
                    ]
                )
                
                problems.append(Problem(diagnostic: diagnostic, possibleSolutions: [solution]))
            }
        }

        let categorizedAvailability = Dictionary(grouping: availability, by: \.platform)

        for duplicateIntroduced in categorizedAvailability.values {
            guard duplicateIntroduced.count > 1 else {
                continue
            }
            
            for availability in duplicateIntroduced {
                let diagnostic = Diagnostic(
                    source: availability.originalMarkup.nameLocation?.source,
                    severity: .warning,
                    range: availability.originalMarkup.range,
                    identifier: "org.swift.docc.\(Metadata.Availability.self).DuplicateIntroduced",
                    summary: "Duplicate \(Metadata.Availability.directiveName.singleQuoted) directive with 'introduced' argument",
                    explanation: """
                    A documentation page can only contain a single 'introduced' version for each platform.
                    """
                )

                guard let range = availability.originalMarkup.range else {
                    problems.append(Problem(diagnostic: diagnostic))
                    continue
                }

                let solution = Solution(
                    summary: "Remove extraneous \(Metadata.Availability.directiveName.singleQuoted) directive",
                    replacements: [
                        Replacement(range: range, replacement: "")
                    ]
                )

                problems.append(Problem(diagnostic: diagnostic, possibleSolutions: [solution]))
            }
        }
        
        return true
    }
    
    /// Validates the use of this Metadata directive in a documentation comment.
    ///
    /// Some configuration options of Metadata are invalid in documentation comments. This function
    /// emits warnings for illegal uses and sets their values to `nil`.
    func validateForUseInDocumentationComment(
        symbolSource: URL?,
        problems: inout [Problem]
    ) {
        let invalidDirectives: [(any AutomaticDirectiveConvertible)?] = [
            documentationOptions,
            technologyRoot,
            displayName,
            callToAction,
            pageKind,
            _pageColor,
            titleHeading,
        ] + (redirects ?? [])
          + supportedLanguages
          + pageImages
        
        let namesAndRanges = invalidDirectives
            .compactMap { $0 }
            .map { (type(of: $0).directiveName, $0.originalMarkup.range) }
        
        problems.append(
            contentsOf: namesAndRanges.map { (name, range) in
                Problem(
                    diagnostic: Diagnostic(
                        source: symbolSource,
                        severity: .warning,
                        range: range,
                        identifier: "org.swift.docc.\(Metadata.directiveName).Invalid\(name)InDocumentationComment",
                        summary: "Invalid use of \(name.singleQuoted) directive in documentation comment; configuration will be ignored",
                        explanation: "Specify this configuration in a documentation extension file"
                        
                        // TODO: It would be nice to offer a solution here that removes the directive for you (#1111, rdar://140846407)
                    )
                )
            }
        )
        
        documentationOptions = nil
        technologyRoot = nil
        displayName = nil
        pageKind = nil
        _pageColor = nil
    }
}
