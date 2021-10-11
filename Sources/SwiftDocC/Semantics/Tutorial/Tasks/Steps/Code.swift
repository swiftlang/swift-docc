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
A code file to display alongside a ``Step``.
*/
public final class Code: Semantic, DirectiveConvertible {
    public static let directiveName = "Code"
    
    /// The original `BlockDirective` node that was parsed into this semantic code.
    public let originalMarkup: BlockDirective
    
    /// A reference to the file containing the code that should be loaded from the bundle.
    public let fileReference: ResourceReference
    /// The name of the file, for display and identification purposes.
    /// If the ``fileName`` does not change between two consecutive steps (possibly across ``TutorialSection``s),
    /// the changes between the two files may be indicated in the UI.
    public let fileName: String
    /// If specified, should present a diff between this property and ``fileReference``.
    public let previousFileReference: ResourceReference?
    /// Whether a diff should be shown. See ``Code/fileName`` for more information.
    public let shouldResetDiff: Bool
    /// A preview image or video overlay.
    public let preview: Media?
    
    enum Semantics {
        enum File: DirectiveArgument {
            static let argumentName = "file"
        }
        enum PreviousFile: DirectiveArgument {
            static let argumentName = "previousFile"
        }
        enum Name: DirectiveArgument {
            static let argumentName = "name"
        }
        enum ResetDiff: DirectiveArgument {
            typealias ArgumentValue = Bool
            static let argumentName = "reset"
        }
    }
    
    init(originalMarkup: BlockDirective, fileReference: ResourceReference, fileName: String, previousFileReference: ResourceReference?, shouldResetDiff: Bool, preview: Media?) {
        self.originalMarkup = originalMarkup
        self.fileReference = fileReference
        self.fileName = fileName
        self.previousFileReference = previousFileReference
        self.shouldResetDiff = shouldResetDiff
        self.preview = preview
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        precondition(directive.name == Code.directiveName)
        
        let arguments = Semantic.Analyses.HasOnlyKnownArguments<Code>(severityIfFound: .warning, allowedArguments: [Semantics.File.argumentName, Semantics.PreviousFile.argumentName, Semantics.Name.argumentName, Semantics.ResetDiff.argumentName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        Semantic.Analyses.HasOnlyKnownDirectives<Code>(severityIfFound: .warning, allowedDirectives: [ImageMedia.directiveName, VideoMedia.directiveName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        guard let requiredFileReference = Semantic.Analyses.HasArgument<Code, Semantics.File>(severityIfNotFound: .warning).analyze(directive, arguments: arguments, problems: &problems) else { return nil }
        let fileReference = ResourceReference(bundleIdentifier: bundle.identifier, path: requiredFileReference)
        
        guard let requiredFileName = Semantic.Analyses.HasArgument<Code, Semantics.Name>(severityIfNotFound: .warning).analyze(directive, arguments: arguments, problems: &problems) else { return nil }
        
        // ResetDiff is optional and defaults to false. If it exists, however, extract it using analysis so we get
        // diagnostics for type mismatches.
        let shouldResetDiff: Bool
        if arguments.keys.contains(Semantics.ResetDiff.argumentName) {
            shouldResetDiff = Semantic.Analyses.HasArgument<Code, Semantics.ResetDiff>(severityIfNotFound: nil).analyze(directive, arguments: arguments, problems: &problems) ?? false
        } else {
            shouldResetDiff = false
        }
       
        let (optionalPreview, _) = Semantic.Analyses.HasExactlyOneImageOrVideoMedia<Code>(severityIfNotFound: nil).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        let optionalPreviousFileReference = Semantic.Analyses.HasArgument<Code, Semantics.PreviousFile>(severityIfNotFound: nil).analyze(directive, arguments: arguments, problems: &problems).map { argument in
            ResourceReference(bundleIdentifier: bundle.identifier, path: argument)
        }
        
        self.init(originalMarkup: directive, fileReference: fileReference, fileName: requiredFileName, previousFileReference: optionalPreviousFileReference, shouldResetDiff: shouldResetDiff, preview: optionalPreview)
    }
    
    public override func accept<V>(_ visitor: inout V) -> V.Result where V : SemanticVisitor {
        return visitor.visitCode(self)
    }
}
