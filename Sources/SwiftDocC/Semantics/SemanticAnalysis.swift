/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/**
 A focused semantic analysis of a `BlockDirective`, recording problems and producing a result.
 
 A semantic analysis should check focus on the smallest meaningful aspect of the incoming `BlockDirective`.
 This eases testing and helps prevent a tangle of dependencies and side effects. For every analysis, there
 should be some number of tests for its robustness.
 
 For example, if an argument is required and is expected to be an integer, a semantic analysis
 would check only that argument, attempt to convert it to an integer, and return it as the result.
 
 > Important: A ``SemanticAnalysis`` should not mutate outside state or directly depend on the results
 of another analysis. This prevents runaway performance problems and strange bugs.
 > It also makes it more amenable to parallelization should the need arise.
 */
public protocol SemanticAnalysis {
    /**
     The result of the analysis.
     
     > Note: This result may be `Void` as some analyses merely validate aspects of a `BlockDirective`.
     */
    associatedtype Result
    
    /**
     Perform the analysis on a directive, collect problems, and attempt to return a ``SemanticAnalysis/Result`` if required.
     
     - parameter directive: The `BlockDirective` that allegedly represents a ``Semantic`` object
     - parameter children: The subset of `directive`'s children to analyze
     - parameter source: A `URL` to the source file from which the `directive` came, if there was one. This is used for printing the location of a diagnostic.
     - parameter bundle: The ``DocumentationBundle`` that owns the incoming `BlockDirective`
     - parameter context: The ``DocumentationContext`` in which the bundle resides
     - parameter problems: A container to append ``Problem``s encountered during the analysis
     - returns: A result of the analysis if required, such as a validated parameter or subsection.
     */
    func analyze<Children: Sequence>(_ directive: BlockDirective, children: Children, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) -> Result where Children.Element == Markup
}
