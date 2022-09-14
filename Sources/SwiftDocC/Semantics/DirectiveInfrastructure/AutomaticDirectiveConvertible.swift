/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive convertible semantic object that uses property wrappers
/// to support automatic parsing with diagnostics.
///
/// Conform to this protocol to create a directive that can be automatically
/// converted from a given block directive markup object.
protocol AutomaticDirectiveConvertible: DirectiveConvertible, Semantic {
    init(originalMarkup: BlockDirective)
    
    /// Returns false if the directive is invalid and should not be initialized.
    ///
    /// Implement this method to perform additional validation after
    /// a directive has been parsed.
    ///
    /// Return false if a serious enough error is encountered such that the directive
    /// should not be initialized.
    func validate(
        source: URL?,
        for bundle: DocumentationBundle,
        in context: DocumentationContext,
        problems: inout [Problem]
    ) -> Bool
    
    /// The key paths to any property wrapped directive arguments, child directives,
    /// or child markup properties.
    ///
    /// This allows the automatic directive conversion to set these values based on the
    /// property names that Swift's mirror provides. This should no longer be necessary
    /// with future improvements to introspection in Swift.
    ///
    /// > Important: Provide the key paths to the underscored property wrappers, not the
    /// > non-underscored projected values of the property wrappers.
    ///
    ///     class Intro: Semantic, AutomaticDirectiveConvertible {
    ///         let originalMarkup: BlockDirective
    ///
    ///         @DirectiveArgumentWrapped
    ///         private(set) var title: String
    ///
    ///         @ChildDirective
    ///         private(set) var video: VideoMedia? = nil
    ///
    ///         @ChildDirective
    ///         private(set) var image: ImageMedia? = nil
    ///
    ///         @ChildMarkup(numberOfParagraphs: .zeroOrMore)
    ///         private(set) var content: MarkupContainer
    ///
    ///         static var keyPaths: [String : AnyKeyPath] = [
    ///             "title"     : \Intro._title,
    ///             "video"     : \Intro._video,
    ///             "image"     : \Intro._image,
    ///             "content"   : \Intro._content,
    ///         ]
    ///
    ///         init(originalMarkup: BlockDirective) {
    ///             self.originalMarkup = originalMarkup
    ///         }
    ///     }
    static var keyPaths: [String : AnyKeyPath] { get }
}

extension AutomaticDirectiveConvertible {
    public static var directiveName: String {
        String(describing: self)
    }
    
    func validate(
        source: URL?,
        for bundle: DocumentationBundle,
        in context: DocumentationContext,
        problems: inout [Problem]
    ) -> Bool {
        return true
    }
}

extension AutomaticDirectiveConvertible {
    /// Creates a directive from a given piece of block directive markup.
    ///
    /// Performs some semantic analyses to determine whether a valid directive can be created
    /// and returns nils upon failure.
    ///
    /// > Tip: ``DirectiveConvertible/init(from:source:for:in:problems:)`` performs
    /// the same function but supports collecting an array of problems for diagnostics.
    ///
    /// - Parameters:
    ///     - directive: The block directive that will be parsed
    ///     - source: An optional URL for the source location where this directive is written.
    ///     - bundle: The documentation bundle that owns the directive.
    ///     - context: The documentation context in which the bundle resides.
    public init?(
        from directive: BlockDirective,
        source: URL? = nil,
        for bundle: DocumentationBundle,
        in context: DocumentationContext
    ) {
        var problems = [Problem]()
        
        self.init(
            from: directive,
            source: source,
            for: bundle,
            in: context,
            problems: &problems
        )
    }
    
    public init?(
        from directive: BlockDirective,
        source: URL?,
        for bundle: DocumentationBundle,
        in context: DocumentationContext,
        problems: inout [Problem]
    ) {
        precondition(directive.name == Self.directiveName)
        self.init(originalMarkup: directive)
        
        let reflectedDirective = DirectiveIndex.shared.reflection(of: type(of: self))
        
        let arguments = Semantic.Analyses.HasOnlyKnownArguments<Self>(
            severityIfFound: .warning,
            allowedArguments: reflectedDirective.arguments.map(\.name)
        )
        .analyze(
            directive,
            children: directive.children,
            source: source,
            for: bundle,
            in: context,
            problems: &problems
        )
        
        // If we encounter an unrecoverable error while parsing directives,
        // set this value to true.
        var unableToCreateParentDirective = false
        
        for reflectedArgument in reflectedDirective.arguments {
            let parsedValue = Semantic.Analyses.ArgumentValueParser<Self>(
                severityIfNotFound: reflectedArgument.required ? .warning : nil,
                argumentName: reflectedArgument.name,
                allowedValues: reflectedArgument.allowedValues,
                convert: { argumentValue in
                    return reflectedArgument.parseArgument(bundle, argumentValue)
                },
                valueTypeDiagnosticName: reflectedArgument.typeDisplayName
            )
            .analyze(directive, arguments: arguments, problems: &problems)
            
            if let parsedValue = parsedValue {
                reflectedArgument.setValue(on: self, to: parsedValue)
            } else if !reflectedArgument.storedAsOptional {
                unableToCreateParentDirective = true
            }
        }
        
        Semantic.Analyses.HasOnlyKnownDirectives<Self>(
            severityIfFound: .warning,
            allowedDirectives: reflectedDirective.childDirectives.map(\.name),
            allowsStructuredMarkup: reflectedDirective.allowsStructuredMarkup
        )
        .analyze(
            directive,
            children: directive.children,
            source: source,
            for: bundle,
            in: context,
            problems: &problems
        )
        
        var remainder = MarkupContainer(directive.children)
        
        // Comments are always allowed so extract them from the
        // directive's children.
        (_, remainder) = Semantic.Analyses.extractAll(
            childType: Comment.self,
            children: remainder,
            source: source,
            for: bundle,
            in: context,
            problems: &problems
        )
        
        for childDirective in reflectedDirective.childDirectives {
            switch childDirective.requirements {
            case .one:
                let parsedDirective: DirectiveConvertible?
                (parsedDirective, remainder) = Semantic.Analyses.extractExactlyOne(
                    childType: childDirective.type,
                    parentDirective: directive,
                    children: remainder,
                    source: source,
                    for: bundle,
                    in: context,
                    problems: &problems
                )
                
                guard let parsedDirective = parsedDirective else {
                    if !childDirective.storedAsArray && !childDirective.storedAsOptional {
                        unableToCreateParentDirective = true
                    }
                    
                    continue
                }
                
                if childDirective.storedAsArray {
                    childDirective.setValue(on: self, to: [parsedDirective])
                } else {
                    childDirective.setValue(on: self, to: parsedDirective)
                }
            case .zeroOrOne:
                let parsedDirective: DirectiveConvertible?
                (parsedDirective, remainder) = Semantic.Analyses.extractAtMostOne(
                    childType: childDirective.type,
                    parentDirective: directive,
                    children: remainder,
                    source: source,
                    for: bundle,
                    in: context,
                    problems: &problems
                )
                
                guard let parsedDirective = parsedDirective else {
                    if childDirective.storedAsArray && !childDirective.storedAsOptional {
                        childDirective.setValue(on: self, to: [])
                    }
                    
                    continue
                }
                
                if childDirective.storedAsArray {
                    childDirective.setValue(on: self, to: [parsedDirective])
                } else {
                    childDirective.setValue(on: self, to: parsedDirective)
                }
            case .zeroOrMore:
                let parsedDirectives: [DirectiveConvertible]
                (parsedDirectives, remainder) = Semantic.Analyses.extractAll(
                    childType: childDirective.type,
                    children: remainder,
                    source: source,
                    for: bundle,
                    in: context,
                    problems: &problems
                )
                
                if !parsedDirectives.isEmpty || !childDirective.storedAsOptional {
                    childDirective.setValue(on: self, to: parsedDirectives)
                }
            case .oneOrMore:
                let parsedDirectives: [DirectiveConvertible]
                (parsedDirectives, remainder) = Semantic.Analyses.extractAtLeastOne(
                    childType: childDirective.type,
                    parentDirective: directive,
                    children: remainder,
                    source: source,
                    for: bundle,
                    in: context,
                    problems: &problems
                )
                
                if !parsedDirectives.isEmpty || !childDirective.storedAsOptional {
                    childDirective.setValue(on: self, to: parsedDirectives)
                }
            }
        }
        
        let supportsChildMarkup: Bool
        if case let .supportsMarkup(markupRequirements) = reflectedDirective.childMarkupSupport,
            let firstChildMarkup = markupRequirements.first
        {
            guard markupRequirements.count < 2 else {
                fatalError("""
                    Automatic directive conversion is not supported for directives \
                    with multiple '@ChildMarkup' properties.
                    """
                )
            }
            
            let content: MarkupContainer
            if firstChildMarkup.required {
                content = Semantic.Analyses.HasContent<Self>().analyze(
                    directive,
                    children: remainder,
                    source: source,
                    for: bundle,
                    in: context,
                    problems: &problems
                )
            } else if !remainder.isEmpty {
                content = MarkupContainer(remainder)
            } else {
                content = MarkupContainer()
            }
            
            firstChildMarkup.setValue(on: self, to: content)
            
            supportsChildMarkup = true
        } else  {
            supportsChildMarkup = false
        }
        
        if !remainder.isEmpty && reflectedDirective.childDirectives.isEmpty && !supportsChildMarkup {
            let removeInnerContentReplacement: [Solution] = directive.children.range.map {
                [
                    Solution(
                        summary: "Remove inner content",
                        replacements: [
                            Replacement(range: $0, replacement: "")
                        ]
                    )
                ]
            } ?? []
            
            let noInnerContentDiagnostic = Diagnostic(
                source: source,
                severity: .warning,
                range: directive.range,
                identifier: "org.swift.docc.\(Self.directiveName).NoInnerContentAllowed",
                summary: "The \(Self.directiveName.singleQuoted) directive does not support inner content",
                explanation: "Elements inside this directive will be ignored"
            )
            
            problems.append(
                Problem(
                    diagnostic: noInnerContentDiagnostic,
                    possibleSolutions: removeInnerContentReplacement
                )
            )
        } else if !remainder.isEmpty && !supportsChildMarkup {
            let diagnostic = Diagnostic(
                source: source,
                severity: .warning,
                range: directive.range,
                identifier: "org.swift.docc.\(Self.directiveName).UnexpectedContent",
                summary: """
                    \(Self.directiveName.singleQuoted) contains unexpected content
                    """,
                explanation: """
                    Arbitrary markup content is not allowed as a child of the \
                    \(Self.directiveName.singleQuoted) directive.
                    """
            )
            
            problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
        }
        
        guard !unableToCreateParentDirective else {
            return nil
        }
        
        guard validate(source: source, for: bundle, in: context, problems: &problems) else {
            return nil
        }
    }
}
