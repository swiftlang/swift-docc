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
      Checks for any direct heading children that do not meet the minimum heading level (`startingFromLevel`) or that exceed the level of a previous _valid_ heading by more than one.
         
      For example, when `startingFromLevel` is `2`:
      
      ```markdown
      # H1 <- invalid, too low
      ## H2 <- valid, meets minimum
      ## H2 <- valid, equal to previous valid
      ### H3 <- valid, one more than previous
      #### H4 <- valid, one more than previous
      ## H2 <- valid, exceeds minimum heading level
      #### H4 <- invalid, skips H3 heading level
      ```
     */
    public struct HasOnlySequentialHeadings<Parent: Semantic & DirectiveConvertible>: SemanticAnalysis {
        let severityIfFound: DiagnosticSeverity?
        let startingFromLevel: Int
        public init(severityIfFound: DiagnosticSeverity?, startingFromLevel: Int) {
            self.severityIfFound = severityIfFound
            self.startingFromLevel = startingFromLevel
        }
        
        /**
         - returns: All valid headings.
         */
        @discardableResult public func analyze<Children: Sequence>(_ directive: BlockDirective, children: Children, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) -> [Heading] where Children.Element == Markup {
            var currentHeadingLevel = startingFromLevel
            var headings: [Heading] = []
            for case let child as Heading in children {
                // A heading level can never be higher than one greater than the previous heading level.
                // For example, H1 -> H2 and H4 -> H1 are ok but H1 -> H3 is not.
                let maximumAllowedHeadingLevel = currentHeadingLevel + 1
                if startingFromLevel...maximumAllowedHeadingLevel ~= child.level {
                    currentHeadingLevel = child.level
                    headings.append(child)
                } else if let severity = severityIfFound {
                    let diagnosticMessageDetail: String
                    if child.level < startingFromLevel {
                        diagnosticMessageDetail = "meet or exceed the minimum allowed heading level (\(startingFromLevel))"
                    } else {
                        diagnosticMessageDetail = "sequentially follow the previous heading"
                    }
                    let diagnostic = Diagnostic(source: source, severity: severity, range: child.range, identifier: "org.swift.docc.HasOnlySequentialHeadings<\(Parent.self)>", summary: "This heading doesn't \(diagnosticMessageDetail)", explanation: "Make the heading level greater than or equal to \(startingFromLevel) and less than or equal to \(maximumAllowedHeadingLevel)")
                    problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
                }
            }
            
            return headings
        }
    }
}

