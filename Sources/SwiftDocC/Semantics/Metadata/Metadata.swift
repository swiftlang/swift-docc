/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
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
    
    // MARK: Private API for OutOfProcessReferenceResolver
    
    /// Don't use this outside of ``OutOfProcessReferenceResolver/entity(with:)`` .
    ///
    /// Directives aren't meant to be created from non-markup but the out-of-process resolver needs to create a ``Metadata`` to hold the ``PageImage``
    /// values that it creates to associate topic images with external pages. This is because DocC renders external content in the local context. (rdar://78718811)
    /// https://github.com/apple/swift-docc/issues/468
    ///
    /// This is intentionally defined as an underscore prefixed static function instead of an initializer to make it less likely that it's used in other places.
    static func _make(
        originalMarkup: BlockDirective,
        documentationOptions: DocumentationExtension? = nil,
        technologyRoot: TechnologyRoot? = nil,
        displayName: DisplayName? = nil,
        pageImages: [PageImage] = [],
        customMetadata: [CustomMetadata] = [],
        callToAction: CallToAction? = nil,
        availability: [Metadata.Availability] = [],
        pageKind: Metadata.PageKind? = nil,
        supportedLanguages: [SupportedLanguage] = [],
        _pageColor: PageColor? = nil,
        titleHeading: TitleHeading? = nil
    ) -> Metadata {
        // FIXME: https://github.com/apple/swift-docc/issues/468
        return Metadata(
            originalMarkup: originalMarkup,
            documentationOptions: documentationOptions,
            technologyRoot: technologyRoot,
            displayName: displayName,
            pageImages: pageImages,
            customMetadata: customMetadata,
            callToAction: callToAction,
            availability: availability,
            pageKind: pageKind,
            supportedLanguages: supportedLanguages,
            _pageColor: _pageColor,
            titleHeading: titleHeading
        )
    }
    
    // This initializer only exists to be called by `_make` above.
    private init(
        originalMarkup: BlockDirective,
        documentationOptions: DocumentationExtension?,
        technologyRoot: TechnologyRoot?,
        displayName: DisplayName?,
        pageImages: [PageImage],
        customMetadata: [CustomMetadata],
        callToAction: CallToAction?,
        availability: [Metadata.Availability],
        pageKind: Metadata.PageKind?,
        supportedLanguages: [SupportedLanguage],
        _pageColor: PageColor?,
        titleHeading: TitleHeading?
    ) {
        self.originalMarkup = originalMarkup
        self.documentationOptions = documentationOptions
        self.technologyRoot = technologyRoot
        self.displayName = displayName
        self.callToAction = callToAction
        self._pageColor = _pageColor
        self.pageKind = pageKind
        self.titleHeading = titleHeading
        // Non-optional child directives need to be set after `super.init()`.
        super.init()
        self.customMetadata = customMetadata
        self.pageImages = pageImages
        self.availability = availability
        self.supportedLanguages = supportedLanguages
    }
}

