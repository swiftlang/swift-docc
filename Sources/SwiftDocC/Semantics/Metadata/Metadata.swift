/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
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
/// - ``DocumentationExtension``
/// - ``TechnologyRoot``
/// - ``DisplayName``
/// - ``PageImage``
/// - ``CallToAction``
/// - ``Availability``
/// - ``PageKind``
/// - ``SupportedLanguage``
/// - ``TitleHeading``
public final class Metadata: Semantic, AutomaticDirectiveConvertible {
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
    ]
    
    /// Creates a metadata object with a given markup, documentation extension, and technology root.
    /// - Parameters:
    ///   - originalMarkup: The original markup for this metadata directive.
    ///   - documentationExtension: Optional configuration that describes how this documentation extension file merges or overrides the in-source documentation.
    ///   - technologyRoot: Optional configuration to make this page root-level documentation.
    ///   - displayName: Optional configuration to customize this page's symbol's display name.
    ///   - titleHeading: Optional configuration to customize the text of this page's title heading.
    init(originalMarkup: BlockDirective, documentationExtension: DocumentationExtension?, technologyRoot: TechnologyRoot?, displayName: DisplayName?, titleHeading: TitleHeading?) {
        self.originalMarkup = originalMarkup
        self.documentationOptions = documentationExtension
        self.technologyRoot = technologyRoot
        self.displayName = displayName
        self.titleHeading = titleHeading
    }
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
    
    func validate(source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) -> Bool {
        // Check that something is configured in the metadata block
        if documentationOptions == nil && technologyRoot == nil && displayName == nil && pageImages.isEmpty && customMetadata.isEmpty && callToAction == nil && availability.isEmpty && pageKind == nil && pageColor == nil && titleHeading == nil {
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
}

