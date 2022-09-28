/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

extension Semantic.Analyses {
    /**
     Checks a parent directive for the presence of exactly one child directive to be converted to a type ``SemanticAnalysis/Result``. If so, return that child and the remainder.
     */
    public struct HasExactlyOne<Parent: Semantic & DirectiveConvertible, Child: Semantic & DirectiveConvertible>: SemanticAnalysis {
        let severityIfNotFound: DiagnosticSeverity?
        public init(severityIfNotFound: DiagnosticSeverity?) {
            self.severityIfNotFound = severityIfNotFound
        }
        
        public func analyze<Children: Sequence>(_ directive: BlockDirective, children: Children, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) -> (Child?, remainder: MarkupContainer) where Children.Element == Markup {
            return Semantic.Analyses.extractExactlyOne(
                childType: Child.self,
                parentDirective: directive,
                children: children,
                source: source,
                for: bundle,
                in: context,
                severityIfNotFound: severityIfNotFound,
                problems: &problems
            ) as! (Child?, MarkupContainer)
        }
    }
    
    static func extractExactlyOne<Children: Sequence>(
        childType: DirectiveConvertible.Type,
        parentDirective: BlockDirective,
        children: Children,
        source: URL?,
        for bundle: DocumentationBundle,
        in context: DocumentationContext,
        severityIfNotFound: DiagnosticSeverity? = .warning,
        problems: inout [Problem]
    ) -> (DirectiveConvertible?, remainder: MarkupContainer) where Children.Element == Markup {
        let (candidates, remainder) = children.categorize { child -> BlockDirective? in
            guard let childDirective = child as? BlockDirective,
                childType.canConvertDirective(childDirective) else {
                    return nil
            }
            return childDirective
        }
        
        guard let candidate = candidates.first else {
            if let severityIfNotFound = severityIfNotFound {
                let diagnostic = Diagnostic(
                    source: source,
                    severity: severityIfNotFound,
                    range: parentDirective.range,
                    identifier: "org.swift.docc.HasExactlyOne<\(parentDirective.name), \(childType)>.Missing",
                    summary: "Missing \(childType.directiveName.singleQuoted) child directive",
                    explanation: """
                    The \(parentDirective.name.singleQuoted) directive must have exactly \
                    one \(childType.directiveName.singleQuoted) child directive
                    """
                )
                problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
            }
            return (nil, MarkupContainer(remainder))
        }
        
        // Even if a single child is optional, having duplicates is thus far always a warning
        // because it would become ambiguous which child to choose as the one.
        
        if let severityIfNotFound = severityIfNotFound {
            for candidate in candidates.suffix(from: 1) {
                let diagnostic = Diagnostic(
                    source: source,
                    severity: severityIfNotFound,
                    range: candidate.range,
                    identifier: "org.swift.docc.HasExactlyOne<\(parentDirective.name), \(childType)>.DuplicateChildren",
                    summary: "Duplicate \(childType.directiveName.singleQuoted) child directive",
                    explanation: """
                    The \(parentDirective.name.singleQuoted) directive must have exactly \
                    one \(childType.directiveName.singleQuoted) child directive
                    """
                )
                problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
            }
        }
        
        return (childType.init(from: candidate, source: source, for: bundle, in: context, problems: &problems), MarkupContainer(remainder))
    }
    
    /**
     Checks a parent directive for the presence of exactly one of two child directives—but not both—to be converted to a type ``SemanticAnalysis/Result``. If so, return that child and the remainder.
     */
    public struct HasExactlyOneOf<Parent: Semantic & DirectiveConvertible, Child1: Semantic & DirectiveConvertible, Child2: Semantic & DirectiveConvertible>: SemanticAnalysis {
        let severityIfNotFound: DiagnosticSeverity?
        public init(severityIfNotFound: DiagnosticSeverity?) {
            self.severityIfNotFound = severityIfNotFound
        }
        
        public func analyze<Children: Sequence>(_ directive: BlockDirective, children: Children, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) -> (Child1?, Child2?, remainder: MarkupContainer) where Children.Element == Markup {
            let (candidates, remainder) = children.categorize { child -> BlockDirective? in
                guard let childDirective = child as? BlockDirective else {
                    return nil
                }
                switch childDirective.name {
                case Child1.directiveName, Child2.directiveName:
                    return childDirective
                default:
                    return nil
                }
            }
            
            guard let candidate = candidates.first else {
                if let severity = severityIfNotFound {
                    let diagnostic = Diagnostic(source: source, severity: severity, range: directive.range, identifier: "org.swift.docc.HasExactlyOneOf<\(Parent.self), \(Child1.self), \(Child2.self)>.Missing", summary: "The \(Parent.directiveName.singleQuoted) directive requires a child directive of type \(Child1.directiveName.singleQuoted) or \(Child2.directiveName.singleQuoted)")
                    problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
                }
                return (nil, nil, MarkupContainer(remainder))
            }
            
            for candidate in candidates.suffix(from: 1) {
                let diagnostic = Diagnostic(source: source, severity: .warning, range: candidate.range, identifier: "org.swift.docc.HasExactlyOneOf<\(Parent.self), \(Child1.self), \(Child2.self)>.Duplicate", summary: "The \(Parent.directiveName.singleQuoted) directive must have exactly one \(Child1.directiveName.singleQuoted) or \(Child2.directiveName.singleQuoted) child directive but not both")
                problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
            }
            
            switch candidate.name {
            case Child1.directiveName:
                guard let first = Child1(from: candidate, source: source, for: bundle, in: context, problems: &problems) else {
                    return (nil, nil, remainder: MarkupContainer(remainder))
                }
                return (first, nil, remainder: MarkupContainer(remainder))
            case Child2.directiveName:
                guard let second = Child2(from: candidate, source: source, for: bundle, in: context, problems: &problems) else {
                    return (nil, nil, remainder: MarkupContainer(remainder))
                }
                return (nil, second, remainder: MarkupContainer(remainder))
                
            default:
                return (nil, nil, remainder: MarkupContainer(remainder))
            }
        }
    }
    
    public struct HasExactlyOneImageOrVideoMedia<Parent: Semantic & DirectiveConvertible>: SemanticAnalysis {
        let severityIfNotFound: DiagnosticSeverity?
        public init(severityIfNotFound: DiagnosticSeverity?) {
            self.severityIfNotFound = severityIfNotFound
        }

        public func analyze<Children: Sequence>(_ directive: BlockDirective, children: Children, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) -> (Media?, remainder: MarkupContainer) where Children.Element == Markup {
            let (foundImage, foundVideo, remainder) = HasExactlyOneOf<Parent, ImageMedia, VideoMedia>(severityIfNotFound: severityIfNotFound).analyze(directive, children: children, source: source, for: bundle, in: context, problems: &problems)
            return (foundImage ?? foundVideo, remainder)
        }
    }
        
    public struct HasExactlyOneMedia<Parent: Semantic & DirectiveConvertible>: SemanticAnalysis {
        let severityIfNotFound: DiagnosticSeverity?
        
        init(severityIfNotFound: DiagnosticSeverity?) {
            self.severityIfNotFound = severityIfNotFound
        }
        
        public func analyze<Children: Sequence>(_ directive: BlockDirective, children: Children, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) -> (Media?, remainder: MarkupContainer) where Children.Element == Markup {
            let (mediaDirectives, remainder) = children.categorize { child -> BlockDirective? in
                guard let childDirective = child as? BlockDirective else {
                    return nil
                }
                switch childDirective.name {
                case ImageMedia.directiveName, VideoMedia.directiveName:
                    return childDirective
                default:
                    return nil
                }
            }
            
            if mediaDirectives.count > 1 {
                for duplicate in mediaDirectives.suffix(from: 1) {
                    let diagnostic = Diagnostic(source: source, severity: .warning, range: duplicate.range, identifier: "org.swift.docc.HasExactlyOneMedia<\(Parent.self)>.Duplicate", summary: "The \(Parent.directiveName.singleQuoted) directive can only have one Media element")
                    
                    if let range = duplicate.range {
                        let replacement = Replacement(range: range, replacement: "")
                        let solution = Solution(summary: "Remove duplicate media element", replacements: [replacement])
                        problems.append(Problem(diagnostic: diagnostic, possibleSolutions: [solution]))
                    } else {
                        problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
                    }
                }
            }
            
            guard let firstMedia = mediaDirectives.first else {
                if let severity = severityIfNotFound {
                    let diagnostic = Diagnostic(source: source, severity: severity, range: directive.range, identifier: "org.swift.docc.HasExactlyOneMedia<\(Parent.self)>.Missing", summary: "The \(Parent.directiveName.singleQuoted) directive requires one Media element")
                    problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
                }
                return (nil, remainder: MarkupContainer(remainder))
            }
            
            switch firstMedia.name {
            case ImageMedia.directiveName:
                guard let image = ImageMedia(from: firstMedia, source: source, for: bundle, in: context, problems: &problems) else {
                    return (nil, remainder: MarkupContainer(remainder))
                }
                return (image, remainder: MarkupContainer(remainder))
            case VideoMedia.directiveName:
                guard let video = VideoMedia(from: firstMedia, source: source, for: bundle, in: context, problems: &problems) else {
                    return (nil, remainder: MarkupContainer(remainder))
                }
                return (video, remainder: MarkupContainer(remainder))

            default:
                return (nil, remainder: MarkupContainer(remainder))
            }
        }
    }

    public struct HasExactlyOneUnorderedList<Parent: Semantic & DirectiveConvertible, ListElement>: SemanticAnalysis {
        let severityIfNotFound: DiagnosticSeverity?

        init(severityIfNotFound: DiagnosticSeverity?) {
            self.severityIfNotFound = severityIfNotFound
        }

        public func analyze<Children: Sequence>(_ directive: BlockDirective, children: Children, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) -> [ListElement]? where Children.Element == Markup {
            var validElements: [ListElement] = []

            var (lists, notLists) = directive.children.categorize { $0 as? UnorderedList }

            if !lists.isEmpty {
                let list = lists.removeFirst()

                let invalidElements: [Markup]
                (validElements, invalidElements) = list.children.categorize { firstChildElement(in: $0) }

                // Diagnose invalid list content.
                problems.append(contentsOf:
                    invalidElements.map { invalidElement in
                        Problem(diagnostic: listElementIsInvalidDiagnostic(source: source, range: invalidElement.range), possibleSolutions: [])
                    }
                )

                // Diagnose extra lists.
                problems.append(contentsOf:
                    lists.map { extraList in
                        Problem(diagnostic: extraneousContentDiagnostic(source: source, range: extraList.range), possibleSolutions: [])
                    }
                )
            } else {
                // Diagnose missing list.
                problems.append(Problem(diagnostic: missingListDiagnostic(source: source, range: directive.range), possibleSolutions: []))
            }

            // Diagnose extreanous children.
            problems.append(contentsOf:
                notLists.map { notList in Problem(diagnostic: extraneousContentDiagnostic(source: source, range: notList.range), possibleSolutions: []) }
            )

            return validElements
        }

        func firstChildElement(in markup: Markup) -> ListElement? {
            return markup // ListItem
                .child(at: 0)? // Paragraph
                .child(at: 0) as? ListElement
        }

        func extraneousContentDiagnostic(source: URL?, range: SourceRange?) -> Diagnostic {
            return Diagnostic(
                source: source,
                severity: .warning,
                range: range,
                identifier: "org.swift.docc.HasExactlyOneUnorderedList<\(Parent.self), \(ListElement.self)>.ExtraneousContent",
                summary: "Extraneous content in \(Parent.directiveName.singleQuoted)",
                explanation: "The \(Parent.directiveName.singleQuoted) directive must contain a single unordered list of links"
            )
        }

        func missingListDiagnostic(source: URL?, range: SourceRange?) -> Diagnostic {
            return Diagnostic(
                source: source,
                severity: .warning,
                range: range,
                identifier: "org.swift.docc.HasExactlyOneUnorderedList<\(Parent.self), \(ListElement.self)>.InvalidContent",
                summary: "Missing unordered list",
                explanation: "The \(Parent.directiveName.singleQuoted) directive must contain a single unordered list of links"
            )
        }

        func listElementIsInvalidDiagnostic(source: URL?, range: SourceRange?) -> Diagnostic {
            return Diagnostic(
                source: source,
                severity: .warning,
                range: range,
                identifier: "org.swift.docc.HasExactlyOneUnorderedList<\(Parent.self), \(ListElement.self)>.InvalidListContent",
                summary: "Invalid content in list item",
                explanation: "The list in \(Parent.directiveName.singleQuoted) must only contain links"
            )
        }
    }
}
