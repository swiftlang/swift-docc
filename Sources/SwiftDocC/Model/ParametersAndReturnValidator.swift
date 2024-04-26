/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit
import Markdown

/// A type that validates and filters a symbol's parameter and return value documentation based on the symbol's function signature.
///
/// To understand this file it helps to know the different between a parameter's "name" and its "external name".
///
///  - term name: The variable name that the parameter is bound in the implementation.
///  - term external name: An optional "argument label" that appear instead of the parameter name at the call site.
///
/// ```swift
/// func doSomething(with someValue: Int) {}
/// //               │    ╰─ name
/// //               ╰─ externalName (also known as "argument label")
/// ```
///
/// Parameter names are unique within one symbol but external names may be repeated within the same symbol.
///
/// ```swift
/// func doSomething(with first: Int, and second: Int, and third: Int) {}
/// //               │    ╰─ name     │   ╰─ name      │   ╰─ name
/// //               ╰─ externalName  ╰─ externalName  ╰─ externalName
/// ```
///
/// Parameters are always referred to using their non-external name in documentation comments.
///
/// ```swift
/// /// - Parameter someValue: Description for this parameter
/// func doSomething(with someValue: Int) {}
/// ```
struct ParametersAndReturnValidator {
    /// The engine that collects problems encountered while validating the parameter and return value documentation.
    var diagnosticEngine: DiagnosticEngine
    /// The list of sources for this symbol's documentation.
    let docChunkSources: [DocumentationNode.DocumentationChunk.Source]
    
    /// Creates validated parameter section variants and returns section variants for the symbol.
    ///
    /// The validator processes the parameter and return value documentation in 3 ways:
    ///  - Any parameter or return value that's not applicable to one language representation's function signature is skipped in that variant.
    ///  - Objective-C error parameters or return values that are not documented are synthesized if any other parameters are documented.
    ///  - Problems are emitted for parameters that are misspelled, not found, or repeated and for return values for symbols that return void in all language representations.
    ///
    /// > Note:
    /// > If the symbol doesn't document any of its parameters or return values, the validator doesn't check for undocumented parameters.
    ///
    /// - Parameters:
    ///   - parameters: The symbol's documented parameters.
    ///   - returns: The symbol's return value documentation.
    ///   - unifiedSymbol: The unified symbol to validate parameters and returns sections for.
    /// - Returns: Parameter section variants and returns section variants containing only the values that exist in each language representation's function signature.
    func makeParametersAndReturnsSections(
        _ parameters: [Parameter]?,
        _ returns: [Return]?,
        _ unifiedSymbol: UnifiedSymbolGraph.Symbol?
    ) -> (
        parameterSection: DocumentationDataVariants<ParametersSection>,
        returnsSection: DocumentationDataVariants<ReturnsSection>
    ) {
        guard FeatureFlags.current.isParametersAndReturnsValidationEnabled,
              let symbol = unifiedSymbol,
              !hasInheritedDocumentationComment(symbol: symbol),
              let signatures = Self.traitSpecificSignatures(symbol)
        else {
            return (
                DocumentationDataVariants(defaultVariantValue: parameters.map { ParametersSection(parameters: $0) }),
                DocumentationDataVariants(defaultVariantValue: returns?.first.map { ReturnsSection(content: $0.contents) })
            )
        }
        
        var parameterVariants = makeParametersSectionVariants(parameters, signatures, symbol.documentedSymbol?.kind, hasDocumentedReturnValues: returns != nil)
        if parameterVariants.allValues.allSatisfy({ _, section in section.parameters.isEmpty }) {
            // If all source languages have empty parameter sections, return `nil` instead of individually empty sections.
            parameterVariants = DocumentationDataVariants(defaultVariantValue: nil)
        }
        var returnVariants = makeReturnsSectionVariants(returns?.first, signatures, symbol.documentedSymbol?.kind, hasDocumentedParameters: parameters != nil)
        if returnVariants.allValues.allSatisfy({ _, section in section.content.isEmpty }) {
            // If all source languages have empty return value sections, return `nil` instead of individually empty sections.
            returnVariants = DocumentationDataVariants(defaultVariantValue: nil)
        }
        return (parameterVariants, returnVariants)
    }
    
    /// Creates a validated parameter section containing only the parameters that exist in each language representation's function signature.
    ///
    /// - Parameters:
    ///   - parameters: The symbol's documented parameters.
    ///   - signatures: The symbol's containing only the values that exist in that language representation's function signature.
    ///   - symbolKind: The documented symbol's kind, for use in diagnostics.
    ///   - hasDocumentedReturnValues: `true` if the symbol has documented its return values; otherwise `false`.
    /// - Returns: A parameter section variant containing only the parameters that exist in each language representation's function signature.
    private func makeParametersSectionVariants(
        _ parameters: [Parameter]?,
        _ signatures: Signatures,
        _ symbolKind: SymbolGraph.Symbol.Kind?,
        hasDocumentedReturnValues: Bool
    ) -> DocumentationDataVariants<ParametersSection> {
        guard let parameters, !parameters.isEmpty else {
            guard hasDocumentedReturnValues, Self.shouldAddObjectiveCErrorParameter(signatures, parameters) else {
                // The symbol has no parameter documentation or return value documentation and none should be synthesized.
                return DocumentationDataVariants(defaultVariantValue: nil)
            }
            // Since the symbol documented its return value synthesize an "error" parameter for it.
            var variants = DocumentationDataVariants<ParametersSection>()
            for trait in signatures.keys {
                variants[trait] = ParametersSection(parameters: []) // Add an empty section so that this language doesn't fallback to the Objective-C content.
            }
            variants[.objectiveC] = ParametersSection(parameters: [Parameter(name: "error", contents: Self.objcErrorDescription)]) // This parameter is synthesized and doesn't have a source range.
            return variants
        }
        
        var variants = DocumentationDataVariants<ParametersSection>()
        var allKnownParameterNames: Set<String> = []
        var parameterNamesByExternalName: [String: Set<String>] = [:]
        // Group the parameters by name to be able to diagnose parameters documented more than once.
        let parametersByName = [String: [Parameter]](grouping: parameters, by: \.name)
        
        for (trait, signature) in signatures {
            // Collect all language representations's parameter information from the function signatures.
            let knownParameterNames = Set(signature.parameters.map(\.name))
            allKnownParameterNames.formUnion(knownParameterNames)
            
            // Remove documented parameters that don't apply to this language representation's function signature.
            var languageApplicableParametersByName = parametersByName.filter { knownParameterNames.contains($0.key) }
            
            // Add a missing error parameter documentation if needed.
            if trait == .objectiveC, Self.shouldAddObjectiveCErrorParameter(signatures, parameters) {
                languageApplicableParametersByName["error"] = [Parameter(name: "error", contents: Self.objcErrorDescription)] // This parameter is synthesized and doesn't have a source range.
            }
            
            // Ensure that the parameters are displayed in the order that they need to be passed.
            var sortedParameters: [Parameter] = []
            sortedParameters.reserveCapacity(languageApplicableParametersByName.count)
            for parameter in signature.parameters {
                if let foundParameter = languageApplicableParametersByName[parameter.name]?.first {
                    sortedParameters.append(foundParameter)
                }
                // While we're looping over the parameters, gather the parameters with external names so that this information can be
                // used to diagnose authored documentation that uses the "external name" instead of the "name" to refer to the parameter.
                if let externalName = parameter.externalName {
                    parameterNamesByExternalName[externalName, default: []].insert(parameter.name)
                }
            }
            
            variants[trait] = ParametersSection(parameters: sortedParameters)
        }
        
        // Diagnose documented parameters that's not found in any language representation's function signature.
        for parameter in parameters where !allKnownParameterNames.contains(parameter.name) {
            if let matchingParameterNames = parameterNamesByExternalName[parameter.name] {
                diagnosticEngine.emit(makeExternalParameterNameProblem(parameter, knownParameterNamesWithSameExternalName: matchingParameterNames.sorted()))
            } else {
                diagnosticEngine.emit(makeExtraParameterProblem(parameter, knownParameterNames: allKnownParameterNames, symbolKind: symbolKind))
            }
        }
        
        // Diagnose parameters that are documented more than once.
        for (name, parameters) in parametersByName where allKnownParameterNames.contains(name) && parameters.count > 1 {
            let first = parameters.first! // Each group is guaranteed to be non-empty.
            for parameter in parameters.dropFirst() {
                diagnosticEngine.emit(makeDuplicateParameterProblem(parameter, previous: first))
            }
        }
        
        // Diagnose missing parameters.
        //
        // In all programming languages that DocC supports so far, a language representation's function signature may support a subset of the parameters
        // but there's always one language that supports the all the parameters. By finding the declaration with the most parameters we can know what
        // the expected parameter order is in all language representations (by skipping the parameters that don't exist in that language representation's
        // function signature).
        if let parameterNameOrder = signatures.values.map(\.parameters).max(by: { $0.count < $1.count })?.map(\.name) {
            let parametersEndLocation = parameters.last?.range?.upperBound
            
            var missingParameterNames = allKnownParameterNames.subtracting(["error"]).filter { parametersByName[$0] == nil }
            for parameter in parameters {
                // Parameters that are documented using their external name already has raised a more specific diagnostic.
                if let documentedByExternalName = parameterNamesByExternalName[parameter.name] {
                    missingParameterNames.subtract(documentedByExternalName)
                }
            }

            for parameterName in missingParameterNames{
                // Look for the parameter that should come after the missing parameter to insert the placeholder documentation in the right location.
                let parameterAfter = parameterNameOrder.drop(while: { $0 != parameterName }).dropFirst()
                    .mapFirst(where: { parametersByName[$0]?.first! /* Each group is guaranteed to be non-empty */ })
                
                // Match the placeholder formatting with the other parameters; either as a standalone parameter or as an item in a parameters outline.
                let standalone = parameterAfter?.isStandalone ?? parametersByName.first?.value.first?.isStandalone ?? false
                diagnosticEngine.emit(makeMissingParameterProblem(name: parameterName, before: parameterAfter, standalone: standalone, lastParameterEndLocation: parametersEndLocation))
            }
        }
        
        return variants
    }
    
    /// Creates a validated returns section containing only the return values that exist in each language representation's function signature.
    ///
    /// - Parameters:
    ///   - returns: The symbol's documented return values.
    ///   - signatures: The symbol's containing only the values that exist in that language representation's function signature.
    ///   - symbolKind: The documented symbol's kind, for use in diagnostics.
    ///   - hasDocumentedParameters: `true` if the symbol has documented any of its parameters; otherwise `false`.
    /// - Returns: A returns section variant containing only the return values that exist in each language representation's function signature.
    private func makeReturnsSectionVariants(
        _ returns: Return?,
        _ signatures: Signatures,
        _ symbolKind: SymbolGraph.Symbol.Kind?,
        hasDocumentedParameters: Bool
    ) -> DocumentationDataVariants<ReturnsSection> {
        let returnsSection = returns.map { ReturnsSection(content: $0.contents) }
        var variants = DocumentationDataVariants<ReturnsSection>()
        
        var traitsWithNonVoidReturnValues = Set(signatures.keys)
        for (trait, signature) in signatures where !signature.returns.isEmpty {
            // Don't display any return value documentation for language representations that only return void.
            if let language = trait.interfaceLanguage.flatMap(SourceLanguage.init(knownLanguageIdentifier:)),
               let voidReturnValues = Self.knownVoidReturnValuesByLanguage[language],
               signature.returns.allSatisfy({ voidReturnValues.contains($0) })
            {
                traitsWithNonVoidReturnValues.remove(trait)
                // Add an empty section so that this language doesn't fallback to another language's content.
                variants[trait] = ReturnsSection(content: [])
                continue
            }
            
            variants[trait] = returnsSection
        }
        
        // Check if there's new or updated return value content that we should add for Objective-C
        if returns != nil || hasDocumentedParameters, let newContent = Self.newObjectiveCReturnsContent(signatures, returns: returns) {
            variants[.objectiveC] = ReturnsSection(content: newContent)
        }
        
        // Diagnose if the symbol had documented its return values but all language representations only return void.
        if let returns, traitsWithNonVoidReturnValues.isEmpty {
            diagnosticEngine.emit(makeReturnsDocumentedForVoidProblem(returns, symbolKind: symbolKind))
        }
        return variants
    }
    
    // MARK: Helpers
    
    /// Checks if the symbol's documentation is inherited from another source location.
    private func hasInheritedDocumentationComment(symbol: UnifiedSymbolGraph.Symbol) -> Bool {
        let symbolLocationURI = symbol.documentedSymbol?.mixins.getValueIfPresent(for: SymbolGraph.Symbol.Location.self)?.uri
        for case .sourceCode(let location, _) in docChunkSources {
            // Check if the symbol has documentation from another source location
            return location?.uri != symbolLocationURI
        }
        // If the symbol didn't have any in-source documentation, check if there's a extension file override.
        return docChunkSources.isEmpty
    }
    
    private typealias Signatures = [DocumentationDataVariantsTrait: SymbolGraph.Symbol.FunctionSignature]
    
    /// Returns the symbol's function signatures for each variant trait, or `nil` if the symbol doesn't have any function signature data.
    private static func traitSpecificSignatures(_ symbol: UnifiedSymbolGraph.Symbol) -> Signatures? {
        var signatures: [DocumentationDataVariantsTrait: SymbolGraph.Symbol.FunctionSignature] = [:]
        for (selector, mixin) in symbol.mixins {
            guard let signature = mixin.getValueIfPresent(for: SymbolGraph.Symbol.FunctionSignature.self) else {
                continue
            }
            signatures[DocumentationDataVariantsTrait(for: selector)] = signature
        }
        return signatures.isEmpty ? nil : signatures
    }
    
    /// Checks if the language specific function signatures describe a throwing function in Swift that bridges to an Objective-C method with a trailing error parameter.
    private static func hasSwiftThrowsObjectiveCErrorBridging(_ signatures: Signatures) -> Bool {
        guard let objcSignature = signatures[.objectiveC],
              objcSignature.parameters.last?.name == "error",
              objcSignature.returns != knownVoidReturnValuesByLanguage[.objectiveC]!
        else {
            return false
        }
        guard let swiftSignature = signatures[.swift],
                swiftSignature.parameters.last?.name != "error"
        else {
            return false
        }
        
        return true
    }
    
    /// Checks if the validator should synthesize documentation for an Objective-C error parameter.
    private static func shouldAddObjectiveCErrorParameter(_ signatures: Signatures, _ parameters: [Parameter]?) -> Bool {
        parameters?.last?.name != "error" && hasSwiftThrowsObjectiveCErrorBridging(signatures)
    }
    
    /// Returns the updated return value content, with an added description of what happens when an error occurs, if needed.
    private static func newObjectiveCReturnsContent(_ signatures: Signatures, returns: Return?) -> [Markup]? {
        guard hasSwiftThrowsObjectiveCErrorBridging(signatures) else { return nil }
        
        guard let returns, !returns.contents.isEmpty else {
            if signatures[.objectiveC]?.returns == [.init(kind: .typeIdentifier, spelling: "BOOL", preciseIdentifier: "c:@T@BOOL")] {
                // There is no documented return value and the Objective-C signature returns BOOL
                return objcBoolErrorDescription
            } else {
                return nil
            }
        }
        
        if returns.contents.contains(where: { $0.format().lowercased().contains("error") }) {
            // If the existing returns value documentation mentions "error" at all, don't add anything
            return nil
        }
        if signatures[.objectiveC]?.returns == [.init(kind: .typeIdentifier, spelling: "BOOL", preciseIdentifier: "c:@T@BOOL")] {
            // If the Objective-C function signature returns BOOL, don't add anything
            return nil
        }
        
        let lastSentenceEndsWithPunctuation = returns.contents.last?.format().removingTrailingWhitespace().last?.isPunctuation == true
        if let inlineContents = returns.contents as? [InlineMarkup] {
            return [Paragraph(inlineContents + objcObjectErrorAddition(endPreviousSentence: !lastSentenceEndsWithPunctuation))]
        } else if let paragraphs = returns.contents as? [Paragraph] {
            guard let lastParagraph = paragraphs.last else {
                return [Paragraph(objcObjectErrorAddition(endPreviousSentence: false))]
            }
            return paragraphs.dropLast() + [Paragraph(lastParagraph.inlineChildren + objcObjectErrorAddition(endPreviousSentence: !lastSentenceEndsWithPunctuation))]
        } else {
            return returns.contents + [Paragraph(objcObjectErrorAddition(endPreviousSentence: false))]
        }
    }
    
    /// The known declaration fragment alternatives that represents "void" in each programming language.
    static var knownVoidReturnValuesByLanguage: [SourceLanguage: [SymbolGraph.Symbol.DeclarationFragments.Fragment]] = [
        .swift: [
            // The Swift symbol graph extractor uses one of these values depending on if the return value is explicitly defined or not.
            .init(kind: .text, spelling: "()", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Void", preciseIdentifier: "s:s4Voida"),
        ],
        .objectiveC: [
            .init(kind: .typeIdentifier, spelling: "void", preciseIdentifier: "c:v"),
        ]
    ]
    
    /// Translates a relative documentation comment source range to the absolute location in that source file.
    private func adjusted(_ range: SourceRange?) -> SourceRange? {
        range.map { adjusted($0) }
    }
    
    /// Translates a relative documentation comment source range to the absolute location in that source file.
    private func adjusted(_ range: SourceRange) -> SourceRange {
        var range = range
        if let source = range.source {
            for case let .sourceCode(location?, offset?) in docChunkSources where location.url == source {
                range.offsetWithRange(offset)
                return range
            }
        }
        return range
    }
    
    // MARK: Diagnostics
    
    /// Creates a new problem about return value documentation for a symbol that returns void.
    ///
    /// ## Example
    ///
    /// ```swift
    /// /// - Parameters:
    /// ///   - someValue: Some description of this parameter
    /// /// - Returns: Description of what this function returns
    /// ///   ^~~~~~~
    /// ///   Return value documented for function returning void
    /// func doSomething(with someValue: Int) {}
    /// ```
    ///
    /// - Parameters:
    ///   - returns: The authored documentation for the return value.
    ///   - symbolKind: The kind of the symbol, used for more specific phrasing in the warning message
    /// - Returns: A new problem that suggests that the developer removes the return value documentation.
    private func makeReturnsDocumentedForVoidProblem(_ returns: Return, symbolKind: SymbolGraph.Symbol.Kind?) -> Problem {
        return Problem(
            diagnostic: Diagnostic(
                source: returns.range?.source,
                severity: .warning,
                range: adjusted(returns.range),
                identifier: "org.swift.docc.VoidReturnDocumented",
                summary: "Return value documented for \(symbolKind?.displayName.lowercased() ?? "symbol") returning void"
            ),
            possibleSolutions: [
                Solution(
                    summary: "Remove return value documentation",
                    replacements: returns.range.map { [Replacement(range: adjusted($0), replacement: "")] } ?? []
                )
            ]
        )
    }
    
    /// Creates a new problem about documentation for a parameter that's not known to that symbol.
    ///
    /// ## Example
    ///
    /// ```swift
    /// /// - Parameters:
    /// ///   - someValue: Some description of this parameter
    /// ///   - anotherValue: Another description of this parameter
    /// ///     ^~~~~~~~~~~~
    /// ///     Parameter 'anotherValue' not found in the function declaration
    /// func doSomething(with someValue: Int) {}
    /// ```
    ///
    /// - Parameters:
    ///   - parameter: The authored documentation for the unknown parameter name
    ///   - knownParameterNames: All known parameter names for that symbol
    ///   - symbolKind: The kind of the symbol, used for more specific phrasing in the warning message
    /// - Returns: A new problem that suggests that the developer removes the documentation for the unknown parameter.
    private func makeExtraParameterProblem(_ parameter: Parameter, knownParameterNames: Set<String>, symbolKind: SymbolGraph.Symbol.Kind?) -> Problem {
        let source = parameter.range?.source
        
        let summary = "Parameter \(parameter.name.singleQuoted) not found in \(symbolKind.map { $0.displayName.lowercased() } ?? "the") declaration"
        let identifier = "org.swift.docc.DocumentedParameterNotFound"
        
        let nearMisses = NearMiss.bestMatches(for: knownParameterNames, against: parameter.name)
        
        if nearMisses.isEmpty {
            // If this parameter doesn't resemble any of this symbols parameters, suggest to remove it.
            return Problem(
                diagnostic: Diagnostic(source: source, severity: .warning, range: adjusted(parameter.range), identifier: identifier, summary: summary),
                possibleSolutions: [
                    Solution(
                        summary: "Remove \(parameter.name.singleQuoted) parameter documentation",
                        replacements: parameter.range.map { [Replacement(range: adjusted($0), replacement: "")] } ?? []
                    )
                ]
            )
        }
        
        // Otherwise, suggest to replace the documented parameter name with the one of the similarly named parameters.
        return Problem(
            diagnostic: Diagnostic(source: source, severity: .warning, range: adjusted(parameter.nameRange), identifier: identifier, summary: summary),
            possibleSolutions: nearMisses.map { candidate in
                Solution(
                    summary: "Replace \(parameter.name.singleQuoted) with \(candidate.singleQuoted)",
                    replacements: parameter.nameRange.map { [Replacement(range: adjusted($0), replacement: candidate)] } ?? []
                )
            }
        )
    }
    
    /// Creates a new problem about a parameter that's documented using its "external name" instead of its "name".
    ///
    /// ## Example
    ///
    /// ```swift
    /// /// - Parameters:
    /// ///   - with: Some description of this parameter
    /// ///     ^~~~
    /// ///     External name 'with' used to document parameter
    /// func doSomething(with someValue: Int) {}
    /// ```
    ///
    /// - Parameters:
    ///   - parameter: The authored documentation for the external parameter name
    ///   - knownParameterNamesWithSameExternalName: A list of all the known parameter names that also have that external name
    /// - Returns: A new problem that suggests that the developer replaces the external name with one of the known parameter names.
    private func makeExternalParameterNameProblem(_ parameter: Parameter, knownParameterNamesWithSameExternalName: [String]) -> Problem {
        return Problem(
            diagnostic: Diagnostic(
                source: parameter.range?.source,
                severity: .warning,
                range: adjusted(parameter.nameRange),
                identifier: "org.swift.docc.DocumentedExternalName",
                summary: "External name \(parameter.name.singleQuoted) used to document parameter"
            ),
            // Suggest to replace the documented argument label with the one of the parameter names.
            possibleSolutions: knownParameterNamesWithSameExternalName.map { candidate in
                Solution(
                    summary: "Replace \(parameter.name.singleQuoted) with \(candidate.singleQuoted)",
                    replacements: parameter.nameRange.map { [Replacement(range: adjusted($0), replacement: candidate)] } ?? []
                )
            }
        )
    }
    
    /// Creates a new problem about a parameter that's documented more than once.
    ///
    /// ## Example
    ///
    /// ```swift
    /// /// - Parameters:
    /// ///   - someValue: Some description of this parameter
    /// ///   - someValue: Another description of this parameter
    /// ///     ^~~~~~~~~
    /// ///     Parameter 'someValue' is already documented
    /// func doSomething(with someValue: Int) {}
    /// ```
    ///
    /// - Parameters:
    ///   - parameter: The authored documentation for this parameter
    ///   - previous: The previous occurrence of documentation for this parameter
    /// - Returns: A new problem that suggests that the developer removes the duplicated parameter documentation.
    private func makeDuplicateParameterProblem(_ parameter: Parameter, previous: Parameter) -> Problem {
        let notes: [DiagnosticNote]
        if let previousRange = previous.range, let source = previousRange.source {
            notes = [DiagnosticNote(source: source, range: adjusted(previousRange), message: "Previously documented here")]
        } else {
            notes = []
        }
        
        return Problem(
            diagnostic: Diagnostic(
                source: parameter.range?.source,
                severity: .warning,
                range: adjusted(parameter.range),
                identifier: "org.swift.docc.DuplicateParameterDocumentation",
                summary: "Parameter \(parameter.name.singleQuoted) is already documented",
                notes: notes
            ),
            possibleSolutions: [
                Solution(
                    summary: "Remove duplicate parameter documentation",
                    replacements: parameter.range.map { [Replacement(range: adjusted($0), replacement: "")] } ?? []
                )
            ]
        )
    }
    
    /// Creates a new problem about a parameter that's missing documentation.
    ///
    /// ## Example
    /// 
    /// ```swift
    /// /// - Parameters:
    /// ///   - firstValue: Description of the first parameter
    /// ///                                                   ^
    /// ///                                                   Parameter 'secondValue' is missing documentation
    /// func doSomething(with firstValue: Int, and secondValue: Int) {}
    /// ```
    /// 
    /// - Parameters:
    ///   - name: The (non-external) name of the undocumented parameter
    ///   - nextParameter: The next documented parameter for this symbol or `nil`, if the undocumented parameter is the last parameter for the symbol.
    ///   - standalone: `true` if the existing documented parameters use the standalone syntax `- Parameter someValue:` or `false` if the existing documented parameters use the `- someValue` syntax within a `- Parameters:` list.
    ///   - location: The end of the last parameter. Used as the diagnostic location when the undocumented parameter is the last parameter of the symbol.
    /// - Returns: A new problem that suggests that the developer adds documentation for the parameter.
    private func makeMissingParameterProblem(name: String, before nextParameter: Parameter?, standalone: Bool, lastParameterEndLocation: SourceLocation?) -> Problem {
        let solutions: [Solution]
        if let insertLocation = nextParameter?.range?.lowerBound ?? lastParameterEndLocation {
            let extraWhitespace = "\n///" + String(repeating: " ", count: (nextParameter?.range?.lowerBound.column ?? 1 + (standalone ? 0 : 2) /* indent items in a parameter outline by 2 spaces */) - 1)
            let replacement: String
            if nextParameter != nil {
                // /// - Parameters:
                // ///   - nextParameter: Description
                //      ^inserting "- parameterName: placeholder\n///  "
                //                                              ^^^^ add newline after to insert before the other parameter
                replacement = Self.newParameterDescription(name: name, standalone: standalone) + extraWhitespace
            } else {
                // /// - Parameters:
                // ///   - otherParameter: Description
                //                                    ^inserting "\n///  - parameterName: placeholder"
                //                                                ^^^^ add newline before to insert after the last parameter
                replacement = extraWhitespace + Self.newParameterDescription(name: name, standalone: standalone)
            }
            solutions = [
                Solution(
                    summary: "Document \(name.singleQuoted) parameter",
                    replacements: [
                        Replacement(range: adjusted(insertLocation ..< insertLocation), replacement: replacement)
                    ]
                )
            ]
        } else {
            solutions = []
        }
        
        return Problem(
            diagnostic: Diagnostic(
                source: lastParameterEndLocation?.source ?? nextParameter?.range?.source,
                severity: .warning,
                range: adjusted(lastParameterEndLocation.map { $0 ..< $0 }),
                identifier: "org.swift.docc.MissingParameterDocumentation",
                summary: "Parameter \(name.singleQuoted) is missing documentation"
            ),
            possibleSolutions: solutions
        )
    }
    
    // MARK: Generated content
    
    private static let objcErrorDescription: [Markup] = [
        Paragraph([
            Text("On output, a pointer to an error object that describes why the method failed, or ") as InlineMarkup, InlineCode("nil"), Text(" if no error occurred. If you are not interested in the error information, pass "), InlineCode("nil"), Text(" for this parameter.")
        ])
    ]
    private static let objcBoolErrorDescription: [Markup] = [
        Paragraph([
            InlineCode("YES") as InlineMarkup, Text(" if the method succeeded, otherwise "), InlineCode("NO"), Text(".")
        ])
    ]
    private static func objcObjectErrorAddition(endPreviousSentence: Bool) -> [InlineMarkup] {
        [Text("\(endPreviousSentence ? "." : "") On failure, this method returns "), InlineCode("nil"), Text(".")]
    }
    
    private static func newParameterDescription(name: String, standalone: Bool) -> String {
        "- \(standalone ? "Parameter " : "")\(name): <#parameter description#>"
    }
}
