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
        
        var returnVariants = makeReturnsSectionVariants(
            returns?.first,
            signatures,
            documentedSymbolKind: symbol.documentedSymbol?.kind,
            swiftSymbolKind: symbol.kind.mapFirst { selector, kind in
                SourceLanguage(knownLanguageIdentifier: selector.interfaceLanguage) == .swift ? kind.identifier : nil
            },
            hasDocumentedParameters: parameters != nil
        )
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
        var allKnownFunctionParameterNames: Set<String> = []
        var parameterNamesByExternalName: [String: Set<String>] = [:]
        
        // Wrap the documented parameters in classes so that `isMatchedInAnySignature` can be modified and tracked across different signatures.
        // This is used later in this method body to raise warnings about documented parameters that wasn't found in any symbol representation's function signature.
        class ParameterReference {
            let wrapped: Parameter
            init(_ parameter: Parameter) {
                self.wrapped = parameter
            }
            
            var isMatchedInAnySignature: Bool = false
            var name: String { wrapped.name }
        }
        let parameterReferences = parameters.map { ParameterReference($0) }
        // Accumulate which unnamed parameters in the function signatures are missing documentation.
        var undocumentedUnnamedParameters = Set<Int>()
        
        for (trait, signature) in signatures {
            // Insert parameter documentation in the order of the signature.
            var orderedParameters = [ParameterReference?](repeating: nil, count: signature.parameters.count)
            var remainingDocumentedParameters = parameterReferences
            
            // Some languages support both names and unnamed parameters, and allow mixing them in the same declaration.
            // It's an uncommon style to mix both in the same declaration but if the developer's code does this we try to minimize warnings
            // and display as much written documentation as possible on the rendered page by matching _named_ parameters first.
            // This only matters if the developer _both_ mixes named and unnamed parameters in the same declaration and documents those parameters out-of-order.
            //
            // For example, consider this C function:
            //
            //     /// - Parameters:
            //     ///   - first: Some documentation
            //     ///   - last: Some documentation
            //     ///   - anything: Some documentation
            //     void functionName (int first, int /*unnamed*/, int last);
            //
            // Because there is a parameter named "last", the 2nd parameter documentation matches the 3rd (named) function parameter instead of the 2nd (unnamed).
            // This means that the above doesn't raise any warnings and that the displayed order on the page is "first", "anything", "last".
            //
            // If we'd matched unnamed parameters first, the above would have matched the 2nd ("last") parameter documentation with the 2nd unnamed function parameter,
            // which would have resulted in two confusing warnings:
            //  - One that the "last" parameter is missing documentation
            //  - One that the "anything" parameter doesn't exist in the function signature.
            //
            // Again, unless the developer documents the mixed named and unnamed parameters out-of-order, both approaches behave the same.
            
            // As described above, match the named function parameters first.
            for (index, functionParameter) in signature.parameters.enumerated() where !functionParameter.isUnnamed {
                // While we're looping over the parameters, gather information about the function parameters to use in diagnostics later in this method body.
                if let externalName = functionParameter.externalName {
                    parameterNamesByExternalName[externalName, default: []].insert(functionParameter.name)
                }
                allKnownFunctionParameterNames.insert(functionParameter.name)
                
                // Match this function parameter with a named documented parameter.
                guard let parameterIndex = remainingDocumentedParameters.firstIndex(where: { $0.name == functionParameter.name }) else {
                    continue
                }
                let parameter = remainingDocumentedParameters.remove(at: parameterIndex)
                parameter.isMatchedInAnySignature = true
                orderedParameters[index] = parameter
            }
            
            // As describe above, match the unnamed parameters last.
            var unnamedParameterNumber = 0 // Track how many unnamed parameters we've encountered.
            for (index, functionParameter) in signature.parameters.enumerated() where functionParameter.isUnnamed {
                defer { unnamedParameterNumber += 1 }
                guard !remainingDocumentedParameters.isEmpty else {
                    // If the function signature has more unnamed parameters than there are documented parameters, the remaining function parameters are missing documentation.
                    undocumentedUnnamedParameters.insert(unnamedParameterNumber)
                    continue
                }
                // Match this function parameter with a named documented parameter.
                let parameter = remainingDocumentedParameters.removeFirst()
                parameter.isMatchedInAnySignature = true
                orderedParameters[index] = parameter
            }
            
            // Add a missing error parameter documentation if needed.
            if trait == .objectiveC, Self.shouldAddObjectiveCErrorParameter(signatures, parameters) {
                orderedParameters.append(
                    ParameterReference(
                        Parameter(name: "error", contents: Self.objcErrorDescription) // This parameter is synthesized and doesn't have a source range.
                    )
                )
            }
            
            variants[trait] = ParametersSection(parameters: orderedParameters.compactMap { $0?.wrapped })
        }
        
        // Diagnose documented parameters that aren't found in any language representation's function signature.
        for parameterReference in parameterReferences where !parameterReference.isMatchedInAnySignature && !allKnownFunctionParameterNames.contains(parameterReference.name) {
            let parameter = parameterReference.wrapped
            if let matchingParameterNames = parameterNamesByExternalName[parameter.name] {
                diagnosticEngine.emit(makeExternalParameterNameProblem(parameter, knownParameterNamesWithSameExternalName: matchingParameterNames.sorted()))
            } else {
                diagnosticEngine.emit(makeExtraParameterProblem(parameter, knownParameterNames: allKnownFunctionParameterNames, symbolKind: symbolKind))
            }
        }
        
        // Diagnose parameters that are documented more than once.
        let documentedParametersByName = [String: [Parameter]](grouping: parameters, by: \.name)
        for (name, parameters) in documentedParametersByName where allKnownFunctionParameterNames.contains(name) && parameters.count > 1 {
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
            
            var missingParameterNames = allKnownFunctionParameterNames.subtracting(["error"]).filter { documentedParametersByName[$0] == nil }
            for parameter in parameters {
                // Parameters that are documented using their external name already has raised a more specific diagnostic.
                if let documentedByExternalName = parameterNamesByExternalName[parameter.name] {
                    missingParameterNames.subtract(documentedByExternalName)
                }
            }

            for parameterName in missingParameterNames {
                // Look for the parameter that should come after the missing parameter to insert the placeholder documentation in the right location.
                let parameterAfter = parameterNameOrder.drop(while: { $0 != parameterName }).dropFirst()
                    .mapFirst(where: { documentedParametersByName[$0]?.first! /* Each group is guaranteed to be non-empty */ })
                
                // Match the placeholder formatting with the other parameters; either as a standalone parameter or as an item in a parameters outline.
                let standalone = parameterAfter?.isStandalone ?? parameters.first?.isStandalone ?? false
                diagnosticEngine.emit(makeMissingParameterProblem(name: parameterName, before: parameterAfter, standalone: standalone, lastParameterEndLocation: parametersEndLocation))
            }
            
            for unnamedParameterNumber in undocumentedUnnamedParameters.sorted() {
                let standalone = parameters.first?.isStandalone ?? false
                diagnosticEngine.emit(makeMissingUnnamedParameterProblem(unnamedParameterNumber: unnamedParameterNumber, standalone: standalone, lastParameterEndLocation: parametersEndLocation))
            }
        }
        
        return variants
    }
    
    /// Creates a validated returns section containing only the return values that exist in each language representation's function signature.
    ///
    /// - Parameters:
    ///   - returns: The symbol's documented return values.
    ///   - signatures: The symbol's containing only the values that exist in that language representation's function signature.
    ///   - documentedSymbolKind: The documented symbol's kind, for use in diagnostics.
    ///   - swiftSymbolKind: The symbol's Swift representation's kind, or `nil` if the symbol doesn't have a Swift representation.
    ///   - hasDocumentedParameters: `true` if the symbol has documented any of its parameters; otherwise `false`.
    /// - Returns: A returns section variant containing only the return values that exist in each language representation's function signature.
    private func makeReturnsSectionVariants(
        _ returns: Return?,
        _ signatures: Signatures,
        documentedSymbolKind: SymbolGraph.Symbol.Kind?,
        swiftSymbolKind: SymbolGraph.Symbol.KindIdentifier?,
        hasDocumentedParameters: Bool
    ) -> DocumentationDataVariants<ReturnsSection> {
        let returnsSection = returns.map { ReturnsSection(content: $0.contents) }
        var variants = DocumentationDataVariants<ReturnsSection>()
        
        var traitsWithNonVoidReturnValues = Set(signatures.keys)
        for (trait, signature) in signatures {
            let language = trait.interfaceLanguage.flatMap(SourceLanguage.init(knownLanguageIdentifier:))
            
            // The function signature for Swift initializers indicate a Void return type.
            // However, initializers have a _conceptual_ return value that's sometimes worth documenting (rdar://131913065).
            if language == .swift, swiftSymbolKind == .`init` {
                variants[trait] = returnsSection
                continue
            }
            
            /// A Boolean value that indicates whether the current signature returns a known "void" value.
            var returnsKnownVoidValue: Bool {
                guard let language, let voidReturnValues = Self.knownVoidReturnValuesByLanguage[language] else {
                    return false
                }
                return signature.returns.allSatisfy { voidReturnValues.contains($0) }
            }
            
            // Don't display any return value documentation for language representations that return nothing or that only return void.
            if signature.returns.isEmpty || returnsKnownVoidValue {
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
            diagnosticEngine.emit(makeReturnsDocumentedForVoidProblem(returns, symbolKind: documentedSymbolKind))
        }
        return variants
    }
    
    // MARK: Helpers
    
    /// Checks if the symbol's documentation is inherited from another source location.
    private func hasInheritedDocumentationComment(symbol: UnifiedSymbolGraph.Symbol) -> Bool {
        guard let documentedSymbol = symbol.documentedSymbol else {
            // If there's no doc comment, any documentation comes from an extension file and isn't inherited from another symbol.
            return false
        }
        
        // A symbol has inherited documentation if the doc comment doesn't come from the current module.
        let moduleNames = symbol.modules.values.reduce(into: Set()) { $0.insert($1.name) }
        return !moduleNames.contains(where: { moduleName in
            documentedSymbol.isDocCommentFromSameModule(symbolModuleName: moduleName) == true
        })
    }
    
    private typealias Signatures = [DocumentationDataVariantsTrait: SymbolGraph.Symbol.FunctionSignature]
    
    /// Returns the symbol's function signatures for each variant trait, or `nil` if the symbol doesn't have any function signature data.
    private static func traitSpecificSignatures(_ symbol: UnifiedSymbolGraph.Symbol) -> Signatures? {
        var signatures: [DocumentationDataVariantsTrait: SymbolGraph.Symbol.FunctionSignature] = [:]
        for (selector, mixin) in symbol.mixins {
            guard var signature = mixin.getValueIfPresent(for: SymbolGraph.Symbol.FunctionSignature.self) else {
                continue
            }
            
            if let alternateSymbols = mixin.getValueIfPresent(for: SymbolGraph.Symbol.AlternateSymbols.self) {
                for alternateSymbol in alternateSymbols.alternateSymbols {
                    guard let alternateSignature = alternateSymbol.functionSignature else { continue }
                    signature.merge(with: alternateSignature, selector: selector)
                }
            }
            
            let trait = DocumentationDataVariantsTrait(for: selector)
            // Check if we've already encountered a different signature for another platform
            guard let existing = signatures.removeValue(forKey: trait) else {
                signatures[trait] = signature
                continue
            }
            
            signature.merge(with: existing, selector: selector)
            signatures[trait] = signature
        }
        
        guard !signatures.isEmpty else { return nil }
        
        // If the unified symbol has at least one function signature, fill in empty signatures for the other language representations.
        //
        // This, for example, makes it so that a functions in C which corresponds to property in Swift, displays its parameters and return value documentation
        // for the C function representation, but not the Swift property representation of the documented symbol.
        let traitsWithoutSignatures = Set(symbol.mainGraphSelectors.map { DocumentationDataVariantsTrait(for: $0) }).subtracting(signatures.keys)
        for trait in traitsWithoutSignatures {
            signatures[trait] = .init(parameters: [], returns: [])
        }
        
        return signatures
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
        
        if returns.possiblyDocumentsFailureBehavior() {
            // If the existing returns value documentation appears to describe the failure / error behavior, don't add anything
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
    
    /// Creates a new problem about a named parameter that's missing documentation.
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
        _makeMissingParameterProblem(
            diagnosticSummary: "Parameter \(name.singleQuoted) is missing documentation",
            solutionText: "Document \(name.singleQuoted) parameter",
            replacementText: Self.newParameterDescription(name: name, standalone: standalone),
            before: nextParameter,
            standalone: standalone,
            lastParameterEndLocation: lastParameterEndLocation
        )
    }
    /// Creates a new problem about an unnamed parameter that's missing documentation.
    ///
    /// ## Example
    /// 
    /// ```c
    /// /// - Parameters:
    /// ///   - firstValue: Description of the first parameter
    /// ///                                                   ^
    /// ///                                                   Unnamed parameter #1 is missing documentation
    /// void doSomething(int firstValue, int /*unnamed*/);
    /// ```
    /// 
    /// - Parameters:
    ///   - unnamedParameterNumber: A number indicating which unnamed parameter this diagnostic refers to.
    ///   - standalone: `true` if the existing documented parameters use the standalone syntax `- Parameter someValue:` or `false` if the existing documented parameters use the `- someValue` syntax within a `- Parameters:` list.
    ///   - location: The end of the last parameter. Used as the diagnostic location when the undocumented parameter is the last parameter of the symbol.
    /// - Returns: A new problem that suggests that the developer adds documentation for the parameter.
    private func makeMissingUnnamedParameterProblem(unnamedParameterNumber: Int, standalone: Bool, lastParameterEndLocation: SourceLocation?) -> Problem {
        _makeMissingParameterProblem(
            diagnosticSummary: "Unnamed parameter #\(unnamedParameterNumber + 1) is missing documentation",
            solutionText: "Document unnamed parameter #\(unnamedParameterNumber + 1)",
            replacementText: Self.newUnnamedParameterDescription(standalone: standalone),
            before: nil,
            standalone: standalone,
            lastParameterEndLocation: lastParameterEndLocation
        )
    }
    
    private func _makeMissingParameterProblem(
        diagnosticSummary: String,
        solutionText: String,
        replacementText: String,
        before nextParameter: Parameter?,
        standalone: Bool,
        lastParameterEndLocation: SourceLocation?
    ) -> Problem {
        let solutions: [Solution]
        if let insertLocation = nextParameter?.range?.lowerBound ?? lastParameterEndLocation {
            let extraWhitespace = "\n///" + String(repeating: " ", count: (nextParameter?.range?.lowerBound.column ?? 1 + (standalone ? 0 : 2) /* indent items in a parameter outline by 2 spaces */) - 1)
            let replacement: String
            if nextParameter != nil {
                // /// - Parameters:
                // ///   - nextParameter: Description
                //      ^inserting "- parameterName: placeholder\n///  "
                //                                              ^^^^ add newline after to insert before the other parameter
                replacement = replacementText + extraWhitespace
            } else {
                // /// - Parameters:
                // ///   - otherParameter: Description
                //                                    ^inserting "\n///  - parameterName: placeholder"
                //                                                ^^^^ add newline before to insert after the last parameter
                replacement = extraWhitespace + replacementText
            }
            solutions = [
                Solution(
                    summary: solutionText,
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
                summary: diagnosticSummary
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
    
    private static func newUnnamedParameterDescription(standalone: Bool) -> String {
        "- \(standalone ? "Parameter " : "")<#uniqueParameterName#>: <#parameter description#>"
    }
}

// MARK: Helper extensions

private extension Return {
    /// Applies a basic heuristic to give an indication if the return value documentation possibly documents what happens when an error occurs
    func possiblyDocumentsFailureBehavior() -> Bool {
        contents.contains(where: { markup in
            let formatted = markup.format().lowercased()
            
            // Check if the authored markup contains one of a handful of words as an indication that it possibly documents what happens when an error occurs.
            return returnValueDescribesErrorRegex.firstMatch(in: formatted, range: NSRange(formatted.startIndex ..< formatted.endIndex, in: formatted)) != nil
        })
    }
}
    
/// A regular expression that finds the words; "error", "fail", "fails", "failure", "failures", "nil", and "null".
/// These words only match at word boundaries or when surrounded by single backticks ("`").
///
/// This is used as a heuristic to give an indication if the return value documentation possibly documents what happens when an error occurs.
private let returnValueDescribesErrorRegex = try! NSRegularExpression(pattern: "(\\b|`)(error|fail(ure)?s?|nil|null)(\\b|`)", options: .caseInsensitive)

private extension SymbolGraph.Symbol.FunctionSignature {
    mutating func merge(with signature: Self, selector: UnifiedSymbolGraph.Selector) {
        // An internal helper function that compares parameter names
        func hasSameNames(_ lhs: Self.FunctionParameter, _ rhs: Self.FunctionParameter) -> Bool {
            lhs.name == rhs.name && lhs.externalName == rhs.externalName
        }
        // If the two signatures have different parameters, add any missing parameters.
        // This allows for documenting parameters that are only available on some platforms.
        //
        // Note: Doing this redundant `elementsEqual(_:by:)` check is significantly faster in the common case when all platforms have the same signature.
        // In the rare case where platforms have different signatures, the overhead of checking `elementsEqual(_:by:)` first is too small to measure.
        if !self.parameters.elementsEqual(signature.parameters, by: hasSameNames) {
            for case .insert(offset: let offset, element: let element, _) in signature.parameters.difference(from: self.parameters, by: hasSameNames) {
                self.parameters.insert(element, at: offset)
            }
        }
        
        // If the already encountered signature has a void return type, replace it with the non-void return type.
        // This allows for documenting the return values that are only available on some platforms.
        if self.returns != signature.returns,
           let knownVoidReturnValues = ParametersAndReturnValidator.knownVoidReturnValuesByLanguage[.init(id: selector.interfaceLanguage)]
        {
            for knownVoidReturnValue in knownVoidReturnValues where [knownVoidReturnValue] == self.returns {
                // The current return value was a known void return value so we replace it with the new return value.
                self.returns = signature.returns
                return
            }
        }
    }
}

private extension SymbolGraph.Symbol.FunctionSignature.FunctionParameter {
    /// A Boolean value indicating whether this function parameter is "unnamed".
    var isUnnamed: Bool {
        // C and C++ use "" to indicate an unnamed function parameter whereas Swift use "_" to indicate an unnamed function parameter.
        name.isEmpty || name == "_"
    }
}
