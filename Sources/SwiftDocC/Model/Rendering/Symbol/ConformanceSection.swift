/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

typealias Constraint = SymbolGraph.Symbol.Swift.GenericConstraint

extension Constraint.Kind {
    /// The spelling to use when rendering this kind of constraint.
    var spelling: String {
        switch self {
        case .conformance: return "conforms to"
        case .sameType: return "is"
        case .superclass: return "inherits"
        }
    }
}

/// A section that contains a list of generic constraints for a symbol.
///
/// The section contains a list of generic constraints that describe the conditions
/// when a symbol is available or conforms to a protocol. For example:
/// "Available when `Element` conforms to `Equatable` and `S` conforms to `StringLiteral`."
public struct ConformanceSection: Codable, Equatable {
    /// A prefix with which to prepend availability constraints.
    var availabilityPrefix: [RenderInlineContent] = [.text("Available when")]
    /// A prefix with which to prepend conformance constraints.
    var conformancePrefix: [RenderInlineContent] = [.text("Conforms when")]
    
    /// The section constraints rendered as inline content.
    let constraints: [RenderInlineContent]
    
    /// Additional parameters to consider when rendering conformance constraints.
    struct ConstraintRenderOptions {
        /// Whether the symbol is a leaf symbol, such as a function or a property.
        let isLeaf: Bool
        
        /// The name of the parent symbol.
        let parentName: String?
        
        /// The symbol name of `Self`.
        let selfName: String
    }
    
    /// Creates a new conformance section.
    /// - Parameter constraints: The list of constraints to render.
    /// - Parameter options: The list of options to apply while rendering.
    ///
    /// Returns `nil` if the given constraints list is empty.
    init?(constraints: [Constraint], options: ConstraintRenderOptions) {
        // Groom somewhat a constraint list coming from the Swift compiler.
        let constraints = ConformanceSection.filterConstraints(constraints, options: options)

        // If no valid constraints are left return `nil`.
        guard !constraints.isEmpty else { return nil }
        
        // Checks if all requirements are on the same type & relation.
        let areRequirementsSameTypeAndRelation = constraints.allSatisfy { constraint in
            return (constraints[0].leftTypeName == constraint.leftTypeName)
                && (constraints[0].kind == constraint.kind)
        }
        
        // If all constraints are on the same type, fold the sentence and return
        if areRequirementsSameTypeAndRelation {
            self.constraints = ConformanceSection.groupRequirements(constraints) + [RenderInlineContent.text(".")]
            return
        }

        // Render all constraints as a sentence.
        let separators = NativeLanguage.english.listSeparators(itemsCount: constraints.count, listType: .union)
            .map { RenderInlineContent.text($0) }

        let rendered = constraints.map { constraint -> [RenderInlineContent] in
            return [
                RenderInlineContent.codeVoice(code: ConformanceSection.displayNameForConformingType(constraint.leftTypeName)),
                RenderInlineContent.text(constraint.kind.spelling.spaceDelimited),
                RenderInlineContent.codeVoice(code: constraint.rightTypeName)
            ]
        }
        
        // Adds "," or ", and" to the requirements wherever necessary.
        let merged = zip(rendered, separators).flatMap({ $0 + [$1] })
            + rendered[separators.count...].flatMap({ $0 })
        
        self.constraints = merged + [RenderInlineContent.text(".")]
    }
    
    private static let selfPrefix = "Self."
    
    /// Returns, modified if necessary, a conforming type's name for rendering.
    static func displayNameForConformingType(_ typeName: String) -> String {
        if typeName.hasPrefix(selfPrefix) {
            return String(typeName.dropFirst(selfPrefix.count))
        }
        return typeName
    }
    
    /// Filters the list of constraints to a the significant constraints only.
    ///
    /// This method removes symbol graph constraints on `Self` that are always fulfilled.
    static func filterConstraints(_ constraints: [Constraint], options: ConstraintRenderOptions) -> [Constraint] {
        return constraints
            .filter { constraint -> Bool in
                if options.isLeaf {
                    // Leaf symbol.
                    if constraint.leftTypeName == "Self" && constraint.rightTypeName == options.parentName {
                        // The Swift compiler will sometimes incldue a constraint's to `Self`'s type,
                        // filter those generic constraints out.
                        return false
                    }
                    return true
                } else {
                    // Non-leaf symbol.
                    if constraint.leftTypeName == "Self" && constraint.rightTypeName == options.selfName {
                        // The Swift compiler will sometimes incldue a constraint's to `Self`'s type,
                        // filter those generic constraints out.
                        return false
                    }
                    return true
                }
            }
    }
    
    /// Groups all input requirements into a single multipart requirement.
    ///
    /// For example, converts the following repetitive constraints:
    /// ```
    /// Key conforms to Hashable, Key conforms to Equatable, Key conforms to Codable
    /// ```
    /// to the shorter version of:
    /// ```
    /// Key conforms to Hashable, Equatable, and Codable
    /// ```
    /// All requirements must be on the same type and with the same
    /// relation kind, for example, "is a" or "conforms to". The `conformances` parameter
    /// contains at least one requirement.
    static func groupRequirements(_ constraints: [Constraint]) -> [RenderInlineContent] {
        precondition(!constraints.isEmpty)
        
        let constraintTypeNames = constraints.map { constraint in
            return RenderInlineContent.codeVoice(code: constraint.rightTypeName)
        }
        let separators = NativeLanguage.english.listSeparators(itemsCount: constraints.count, listType: .union)
            .map { return RenderInlineContent.text($0) }
        
        let constraintCompoundName = zip(constraintTypeNames, separators).flatMap { [$0, $1] }
            + constraintTypeNames[separators.count...]
        
        return [
            RenderInlineContent.codeVoice(code: ConformanceSection.displayNameForConformingType(constraints[0].leftTypeName)),
            RenderInlineContent.text(constraints[0].kind.spelling.spaceDelimited)
        ] + constraintCompoundName
    }
}

private extension String {
    /// Returns the string surrounded by spaces.
    var spaceDelimited: String { return " \(self) "}
}
