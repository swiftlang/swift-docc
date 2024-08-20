/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import Markdown
@testable import SymbolKit
@testable import SwiftDocC
import SwiftDocCTestUtilities

class ParametersAndReturnValidatorTests: XCTestCase {
    
    func testFiltersParameters() throws {
        let (bundle, context) = try testBundleAndContext(named: "ErrorParameters")
        
        // /// - Parameters:
        // ///   - someValue: Some value.
        // ///   - error: On input, a pointer to an error object. If an error occurs, this pointer is set to an actual error object containing the error information.
        // /// - Returns: `YES` if doing something was successful, or `NO` if an error occurred.
        // - (void)doSomethingWith:(NSInteger)someValue error:(NSError **)error;
        do {
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ErrorParameters/MyClassInObjectiveC/doSomething(with:)", sourceLanguage: .swift)
            let node = try context.entity(with: reference)
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            
            let titles = symbol.titleVariants
            XCTAssertEqual(titles[.swift], "doSomething(with:)")
            XCTAssertEqual(titles[.objectiveC], "doSomethingWith:error:")
            
            let parameterSections = symbol.parametersSectionVariants
            XCTAssertEqual(parameterSections[.swift]?.parameters.map(\.name), ["someValue"], "The Swift variant has no error parameter")
            XCTAssertEqual(parameterSections[.objectiveC]?.parameters.map(\.name), ["someValue", "error"])
            
            let returnsSections = symbol.returnsSectionVariants
            XCTAssertEqual(returnsSections[.swift]?.content.map({ $0.format() }).joined(), "", "The Swift variant returns Void but needs an empty returns section to so that the rendered page doesn't use the Objective-C variant as a fallback.")
            XCTAssertEqual(returnsSections[.objectiveC]?.content.map({ $0.format() }).joined(), "`YES` if doing something was successful, or `NO` if an error occurred.", "The Objective-C variant returns BOOL")
        }
        
        // /// - Parameter error: On input, a pointer to an error object. If an error occurs, this pointer is set to an actual error object containing the error information.
        // /// - Returns: Some string. If an error occurs, this method returns `nil` and assigns an appropriate error object to the `error` parameter.
        // - (nullable NSString *)returnSomethingAndReturnError:(NSError **)error;
        do {
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ErrorParameters/MyClassInObjectiveC/returnSomething()", sourceLanguage: .swift)
            let node = try context.entity(with: reference)
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            
            let titles = symbol.titleVariants
            XCTAssertEqual(titles[.swift], "returnSomething()")
            XCTAssertEqual(titles[.objectiveC], "returnSomethingAndReturnError:")
            
            let parameterSections = symbol.parametersSectionVariants
            XCTAssertEqual(parameterSections[.swift]?.parameters.map(\.name), [], "The Swift variant has no parameters but needs an empty returns section to so that the rendered page doesn't use the Objective-C variant as a fallback.")
            XCTAssertEqual(parameterSections[.objectiveC]?.parameters.map(\.name), ["error"])
            
            let returnsSections = symbol.returnsSectionVariants
            XCTAssertEqual(returnsSections[.swift]?.content.map({ $0.format() }).joined(), "Some string. If an error occurs, this method returns `nil` and assigns an appropriate error object to the `error` parameter.")
            XCTAssertEqual(returnsSections[.objectiveC]?.content.map({ $0.format() }).joined(), "Some string. If an error occurs, this method returns `nil` and assigns an appropriate error object to the `error` parameter.")
        }
        
        // /// - Parameter someValue: Some value.
        // /// - Throws: Some error if something does wrong
        // @objc public func doSomething(with someValue: Int) throws { }
        do {
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ErrorParameters/MyClassInSwift/doSomething(with:)", sourceLanguage: .swift)
            let node = try context.entity(with: reference)
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            
            let titles = symbol.titleVariants
            XCTAssertEqual(titles[.swift], "doSomething(with:)")
            XCTAssertEqual(titles[.objectiveC], "doSomethingWith:error:")
            
            let parameterSections = symbol.parametersSectionVariants
            XCTAssertEqual(parameterSections[.swift]?.parameters.map(\.name), ["someValue"], "The Swift variant has no error parameter")
            XCTAssertEqual(parameterSections[.swift]?.parameters.first?.contents.map({ $0.format() }).joined(), "Some value.")
            XCTAssertEqual(parameterSections[.objectiveC]?.parameters.map(\.name), ["someValue", "error"])
            XCTAssertEqual(parameterSections[.objectiveC]?.parameters.first?.contents.map({ $0.format() }).joined(), "Some value.")
            XCTAssertEqual(parameterSections[.objectiveC]?.parameters.last?.contents.map({ $0.format() }).joined(), "On output, a pointer to an error object that describes why the method failed, or `nil` if no error occurred. If you are not interested in the error information, pass `nil` for this parameter.")
            
            let returnsSections = symbol.returnsSectionVariants
            XCTAssertEqual(returnsSections[.swift]?.content.map({ $0.format() }).joined(), "", "The method has no return value documentation but needs an empty returns section to so that the rendered page doesn't use the Objective-C variant as a fallback.")
            XCTAssertEqual(returnsSections[.objectiveC]?.content.map({ $0.format() }).joined(), "`YES` if the method succeeded, otherwise `NO`.", "The Objective-C variant returns BOOL")
        }
        
        // /// Returns something from Swift.
        // /// - Returns: Some string.
        // /// - Throws: Some error if something does wrong
        // @objc public func returnSomething() throws -> String { "" }
        do {
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ErrorParameters/MyClassInSwift/returnSomething()", sourceLanguage: .swift)
            let node = try context.entity(with: reference)
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            
            let titles = symbol.titleVariants
            XCTAssertEqual(titles[.swift], "returnSomething()")
            XCTAssertEqual(titles[.objectiveC], "returnSomethingAndReturnError:")
            
            let parameterSections = symbol.parametersSectionVariants
            XCTAssertEqual(parameterSections[.swift]?.parameters.map(\.name), [], "The documentation comment has no parameter documentation but needs an empty returns section to so that the rendered page doesn't use the Objective-C variant as a fallback.")
            XCTAssertEqual(parameterSections[.objectiveC]?.parameters.map(\.name), ["error"], "A generated error description is added because the symbol has documented the return value.")
            
            let returnsSections = symbol.returnsSectionVariants
            XCTAssertEqual(returnsSections[.swift]?.content.map({ $0.format() }).joined(), "Some string.")
            XCTAssertEqual(returnsSections[.objectiveC]?.content.map({ $0.format() }).joined(), "Some string. On failure, this method returns `nil`.")
        }
    }
    
    func testParameterDiagnosticsInDocumentationExtension() throws {
        let (url, _, context) = try testBundleAndContext(copying: "ErrorParameters") { url in
            try """
            # ``MyClassInObjectiveC/doSomethingWith:error:``
            
            @Metadata {
              @DocumentationExtension(mergeBehavior: override)
            }
            
            Override the documentation with a parameter section that raise warnings.
            
            - Parameters:
              - someValue: First description
              - someValue: second description
              - somevalue: Lowercase parameter name that doesn't exist
              - somethingElse: Another parameter that isn't similar to any found parameter
            """.write(to: url.appendingPathComponent("extension.md"), atomically: true, encoding: .utf8)
            
            try """
            # ``MyClassInSwift/doSomething(with:)``
            
            @Metadata {
              @DocumentationExtension(mergeBehavior: override)
            }
            
            Override the documentation with a parameter section that raise warnings.
            
            - Parameter with: Documented using argument label
            - Parameter error: Error description
            """.write(to: url.appendingPathComponent("swift-extension.md"), atomically: true, encoding: .utf8)
        }
        
        do {
            XCTAssertEqual(context.problems.count, 4)
            
            let parameterNearMissProblem = try XCTUnwrap(context.problems.first(where: { $0.diagnostic.summary == "Parameter 'somevalue' not found in instance method declaration" }))
            XCTAssertEqual(parameterNearMissProblem.diagnostic.source, url.appendingPathComponent("extension.md"))
            XCTAssertEqual(parameterNearMissProblem.diagnostic.range?.lowerBound.line, 12)
            XCTAssertEqual(parameterNearMissProblem.diagnostic.range?.lowerBound.column, 5)
            XCTAssertEqual(parameterNearMissProblem.diagnostic.range?.upperBound.line, 12)
            XCTAssertEqual(parameterNearMissProblem.diagnostic.range?.upperBound.column, 14)
            
            XCTAssertEqual(parameterNearMissProblem.possibleSolutions.first?.summary, "Replace 'somevalue' with 'someValue'")
            XCTAssertEqual(parameterNearMissProblem.possibleSolutions.first?.replacements.first?.range, parameterNearMissProblem.diagnostic.range)
            
            let parameterNotFoundProblem = try XCTUnwrap(context.problems.first(where: { $0.diagnostic.summary == "Parameter 'somethingElse' not found in instance method declaration" }))
            XCTAssertEqual(parameterNotFoundProblem.diagnostic.source, url.appendingPathComponent("extension.md"))
            XCTAssertEqual(parameterNotFoundProblem.diagnostic.range?.lowerBound.line, 13)
            XCTAssertEqual(parameterNotFoundProblem.diagnostic.range?.lowerBound.column, 3)
            XCTAssertEqual(parameterNotFoundProblem.diagnostic.range?.upperBound.line, 13)
            XCTAssertEqual(parameterNotFoundProblem.diagnostic.range?.upperBound.column, 79)
            
            XCTAssertEqual(parameterNotFoundProblem.possibleSolutions.first?.summary, "Remove 'somethingElse' parameter documentation")
            XCTAssertEqual(parameterNotFoundProblem.possibleSolutions.first?.replacements.first?.range, parameterNotFoundProblem.diagnostic.range)
            
            let duplicateParameterProblem = try XCTUnwrap(context.problems.first(where: { $0.diagnostic.summary == "Parameter 'someValue' is already documented" }))
            XCTAssertEqual(duplicateParameterProblem.diagnostic.source, url.appendingPathComponent("extension.md"))
            XCTAssertEqual(duplicateParameterProblem.diagnostic.range?.lowerBound.line, 11)
            XCTAssertEqual(duplicateParameterProblem.diagnostic.range?.lowerBound.column, 3)
            XCTAssertEqual(duplicateParameterProblem.diagnostic.range?.upperBound.line, 11)
            XCTAssertEqual(duplicateParameterProblem.diagnostic.range?.upperBound.column, 34)
            
            XCTAssertEqual(duplicateParameterProblem.possibleSolutions.first?.summary, "Remove duplicate parameter documentation")
            XCTAssertEqual(duplicateParameterProblem.possibleSolutions.first?.replacements.first?.range, duplicateParameterProblem.diagnostic.range)
            
            XCTAssertEqual(duplicateParameterProblem.diagnostic.notes.first?.message, "Previously documented here")
            XCTAssertEqual(duplicateParameterProblem.diagnostic.notes.first?.source, duplicateParameterProblem.diagnostic.source)
            XCTAssertEqual(duplicateParameterProblem.diagnostic.notes.first?.range.lowerBound.line, 10)
            XCTAssertEqual(duplicateParameterProblem.diagnostic.notes.first?.range.lowerBound.column, 3)
            XCTAssertEqual(duplicateParameterProblem.diagnostic.notes.first?.range.upperBound.line, 10)
            XCTAssertEqual(duplicateParameterProblem.diagnostic.notes.first?.range.upperBound.column, 33)
            
            let argumentLabelProblem = try XCTUnwrap(context.problems.first(where: { $0.diagnostic.summary == "External name 'with' used to document parameter" }))
            XCTAssertEqual(argumentLabelProblem.diagnostic.source, url.appendingPathComponent("swift-extension.md"))
            XCTAssertEqual(argumentLabelProblem.diagnostic.range?.lowerBound.line, 9)
            XCTAssertEqual(argumentLabelProblem.diagnostic.range?.lowerBound.column, 13)
            XCTAssertEqual(argumentLabelProblem.diagnostic.range?.upperBound.line, 9)
            XCTAssertEqual(argumentLabelProblem.diagnostic.range?.upperBound.column, 17)
            
            XCTAssertEqual(argumentLabelProblem.possibleSolutions.first?.summary, "Replace 'with' with 'someValue'")
            XCTAssertEqual(argumentLabelProblem.possibleSolutions.first?.replacements.first?.range, argumentLabelProblem.diagnostic.range)
            XCTAssertEqual(argumentLabelProblem.possibleSolutions.first?.replacements.first?.replacement, "someValue")
        }
    }
    
    func testFunctionsThatCorrespondToPropertiesInAnotherLanguage() throws {
        let (_, _, context) = try testBundleAndContext(named: "GeometricalShapes")
        XCTAssertEqual(context.problems.map(\.diagnostic.summary), [])
        
        // A small test helper to format markup for test assertions in this test.
        func _format(_ markup: [any Markup]) -> String {
            markup.map { $0.format() }.joined()
        }
        
        let reference = try XCTUnwrap(context.knownPages.first(where: { $0.lastPathComponent == "isEmpty" }))
        let node = try context.entity(with: reference)
        
        let symbolSemantic = try XCTUnwrap(node.semantic as? Symbol)
        let swiftParameterNames = symbolSemantic.parametersSectionVariants.firstValue?.parameters
        let objcParameterNames  = symbolSemantic.parametersSectionVariants.allValues.mapFirst(where: { (trait, variant) -> [Parameter]? in
            guard trait.interfaceLanguage == SourceLanguage.objectiveC.id else { return nil }
            return variant.parameters
        })
        
        XCTAssertEqual(swiftParameterNames?.map(\.name), [])
        XCTAssertEqual(objcParameterNames?.map(\.name), ["circle"])
        XCTAssertEqual(objcParameterNames?.map { _format($0.contents) }, ["The circle to examine."])
        
        let swiftReturnsContent = symbolSemantic.returnsSection.map { _format($0.content) }
        let objcReturnsContent  = symbolSemantic.returnsSectionVariants.allValues.mapFirst(where: { (trait, variant) -> String? in
            guard trait.interfaceLanguage == SourceLanguage.objectiveC.id else { return nil }
            return variant.content.map { $0.format() }.joined()
        })
        
        XCTAssertEqual(swiftReturnsContent, "")
        XCTAssertEqual(objcReturnsContent, "`YES` if the specified circle is empty; otherwise, `NO`.")
    }
    
    func testNoParameterDiagnosticWithoutFunctionSignature() throws {
        var symbolGraph = makeSymbolGraph(docComment: """
            Some function description
            
            - Parameters:
              - secondParameter: One description
              - thirdParameter: Another description
            """)
        
        symbolGraph.symbols["symbol-id"]?.mixins[SymbolGraph.Symbol.FunctionSignature.mixinKey] = nil
        
        let url = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                JSONFile(name: "ModuleName.symbols.json", content: symbolGraph)
            ])
        ])
        let (_, _, context) = try loadBundle(from: url)
        
        XCTAssertEqual(context.problems.count, 0)
    }
    
    func testNoParameterDiagnosticWithoutDocumentationComment() throws {
        let symbolGraph = makeSymbolGraph(docComment: """
            Some function description
            
            No parameters section
            """)
        
        let url = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                JSONFile(name: "ModuleName.symbols.json", content: symbolGraph)
            ])
        ])
        let (_, _, context) = try loadBundle(from: url)
        
        XCTAssertEqual(context.problems.count, 0)
    }
    
    func testMissingParametersInDocCommentDiagnostics() throws {
        let symbolGraph = makeSymbolGraph(docComment: """
            Some function description
            
            - Parameters:
              - secondParameter: One description
              - thirdParameter: Another description
            """)
        let url = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                JSONFile(name: "ModuleName.symbols.json", content: symbolGraph)
            ])
        ])
        let (_, _, context) = try loadBundle(from: url)
        
        XCTAssertEqual(context.problems.count, 2)
        let endOfParameterSectionLocation = SourceLocation(line: start.line + 5, column: start.character + 40, source: symbolURL)
        
        let oneMissingParameterProblem = try XCTUnwrap(context.problems.first(where: { $0.diagnostic.summary == "Parameter 'firstParameter' is missing documentation" }))
        XCTAssertEqual(oneMissingParameterProblem.diagnostic.source, symbolURL)
        XCTAssertEqual(oneMissingParameterProblem.diagnostic.range?.lowerBound, endOfParameterSectionLocation)
        XCTAssertEqual(oneMissingParameterProblem.diagnostic.range?.upperBound, endOfParameterSectionLocation)
        
        // The missing `firstParameter` should be added before 'secondParameter'
        XCTAssertEqual(oneMissingParameterProblem.possibleSolutions.first?.summary, "Document 'firstParameter' parameter")
        let startOfParameterTwoLocation = SourceLocation(line: start.line + 4, column: start.character + 3, source: symbolURL)
        XCTAssertEqual(oneMissingParameterProblem.possibleSolutions.first?.replacements.first?.range.lowerBound, startOfParameterTwoLocation)
        XCTAssertEqual(oneMissingParameterProblem.possibleSolutions.first?.replacements.first?.range.upperBound, startOfParameterTwoLocation)
        XCTAssertEqual(oneMissingParameterProblem.possibleSolutions.first?.replacements.first?.replacement, "- firstParameter: <#parameter description#>\n///  ")
        
        let otherMissingParameterProblem = try XCTUnwrap(context.problems.first(where: { $0.diagnostic.summary == "Parameter 'fourthParameter' is missing documentation" }))
        XCTAssertEqual(otherMissingParameterProblem.diagnostic.source, symbolURL)
        XCTAssertEqual(otherMissingParameterProblem.diagnostic.range?.lowerBound, endOfParameterSectionLocation)
        XCTAssertEqual(otherMissingParameterProblem.diagnostic.range?.upperBound, endOfParameterSectionLocation)
        
        // The missing 'fourthParameter' should be added after the 'thirdParameter'
        XCTAssertEqual(otherMissingParameterProblem.possibleSolutions.first?.summary, "Document 'fourthParameter' parameter")
        XCTAssertEqual(otherMissingParameterProblem.possibleSolutions.first?.replacements.first?.range.lowerBound, endOfParameterSectionLocation)
        XCTAssertEqual(otherMissingParameterProblem.possibleSolutions.first?.replacements.first?.range.upperBound, endOfParameterSectionLocation)
        XCTAssertEqual(otherMissingParameterProblem.possibleSolutions.first?.replacements.first?.replacement, "\n///  - fourthParameter: <#parameter description#>")
    }
    
    func testMissingSeparateParametersInDocCommentDiagnostics() throws {
        let symbolGraph = makeSymbolGraph(docComment: """
            Some function description
            
            - Parameter secondParameter: One description
            - Parameter thirdParameter: Another description
            """)
        let url = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                JSONFile(name: "ModuleName.symbols.json", content: symbolGraph)
            ])
        ])
        let (_, _, context) = try loadBundle(from: url)
        
        XCTAssertEqual(context.problems.count, 2)
        let endOfParameterSectionLocation = SourceLocation(line: start.line + 4, column: start.character + 48, source: symbolURL)
        
        let oneMissingParameterProblem = try XCTUnwrap(context.problems.first(where: { $0.diagnostic.summary == "Parameter 'firstParameter' is missing documentation" }))
        XCTAssertEqual(oneMissingParameterProblem.diagnostic.source, symbolURL)
        XCTAssertEqual(oneMissingParameterProblem.diagnostic.range?.lowerBound, endOfParameterSectionLocation)
        XCTAssertEqual(oneMissingParameterProblem.diagnostic.range?.upperBound, endOfParameterSectionLocation)
        
        // The missing `firstParameter` should be added before 'secondParameter'
        XCTAssertEqual(oneMissingParameterProblem.possibleSolutions.first?.summary, "Document 'firstParameter' parameter")
        let startOfParameterTwoLocation = SourceLocation(line: start.line + 3, column: start.character + 1, source: symbolURL)
        XCTAssertEqual(oneMissingParameterProblem.possibleSolutions.first?.replacements.first?.range.lowerBound, startOfParameterTwoLocation)
        XCTAssertEqual(oneMissingParameterProblem.possibleSolutions.first?.replacements.first?.range.upperBound, startOfParameterTwoLocation)
        XCTAssertEqual(oneMissingParameterProblem.possibleSolutions.first?.replacements.first?.replacement, "- Parameter firstParameter: <#parameter description#>\n///")
        
        let otherMissingParameterProblem = try XCTUnwrap(context.problems.first(where: { $0.diagnostic.summary == "Parameter 'fourthParameter' is missing documentation" }))
        XCTAssertEqual(otherMissingParameterProblem.diagnostic.source, symbolURL)
        XCTAssertEqual(otherMissingParameterProblem.diagnostic.range?.lowerBound, endOfParameterSectionLocation)
        XCTAssertEqual(otherMissingParameterProblem.diagnostic.range?.upperBound, endOfParameterSectionLocation)
        
        // The missing 'fourthParameter' should be added after the 'thirdParameter'
        XCTAssertEqual(otherMissingParameterProblem.possibleSolutions.first?.summary, "Document 'fourthParameter' parameter")
        XCTAssertEqual(otherMissingParameterProblem.possibleSolutions.first?.replacements.first?.range.lowerBound, endOfParameterSectionLocation)
        XCTAssertEqual(otherMissingParameterProblem.possibleSolutions.first?.replacements.first?.range.upperBound, endOfParameterSectionLocation)
        XCTAssertEqual(otherMissingParameterProblem.possibleSolutions.first?.replacements.first?.replacement, "\n///- Parameter fourthParameter: <#parameter description#>")
    }
    
    func testFunctionWithOnlyErrorParameter() throws {
        let url = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                Folder(name: "swift", content: [
                    JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                        docComment: nil,
                        sourceLanguage: .swift,
                        parameters: [],
                        returnValue: .init(kind: .typeIdentifier, spelling: "Void", preciseIdentifier: "s:s4Voida")
                    ))
                ]),
                Folder(name: "clang", content: [
                    JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                        docComment: """
                        Some function description
                        
                        - Returns: Some return value description.
                        """,
                        sourceLanguage: .objectiveC,
                        parameters: [(name: "error", externalName: nil)],
                        returnValue: .init(kind: .typeIdentifier, spelling: "BOOL", preciseIdentifier: "c:@T@BOOL")
                    ))
                ])
            ])
        ])
        let (_, bundle, context) = try loadBundle(from: url)
        
        XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ModuleName/functionName(...)", sourceLanguage: .swift)
        let node = try context.entity(with: reference)
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        
        let parameterSections = symbol.parametersSectionVariants
        XCTAssertEqual(parameterSections[.swift]?.parameters.map(\.name), [], "The Swift variant has no error parameter")
        XCTAssertEqual(parameterSections[.objectiveC]?.parameters.map(\.name), ["error"])
        XCTAssertEqual(parameterSections[.objectiveC]?.parameters.last?.contents.map({ $0.format() }).joined(), "On output, a pointer to an error object that describes why the method failed, or `nil` if no error occurred. If you are not interested in the error information, pass `nil` for this parameter.")
        
        let returnsSections = symbol.returnsSectionVariants
        XCTAssertEqual(returnsSections[.swift]?.content.map({ $0.format() }).joined(), "", "The Swift variant has no return value")
        XCTAssertEqual(returnsSections[.objectiveC]?.content.map({ $0.format() }).joined(), "Some return value description.")
    }
    
    func testFunctionWithDifferentSignaturesOnDifferentPlatforms() throws {
        let url = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                // One parameter, void return
                JSONFile(name: "Platform1-ModuleName.symbols.json", content: makeSymbolGraph(
                    platform: .init(operatingSystem: .init(name: "Platform1")),
                    docComment: nil,
                    sourceLanguage: .objectiveC,
                    parameters: [(name: "first", externalName: nil)],
                    returnValue: .init(kind: .typeIdentifier, spelling: "void", preciseIdentifier: "c:v")
                )),
                // Two parameters, void return
                JSONFile(name: "Platform2-ModuleName.symbols.json", content: makeSymbolGraph(
                    platform: .init(operatingSystem: .init(name: "Platform2")),
                    docComment: nil,
                    sourceLanguage: .objectiveC,
                    parameters: [(name: "first", externalName: nil), (name: "second", externalName: nil)],
                    returnValue: .init(kind: .typeIdentifier, spelling: "void", preciseIdentifier: "c:v")
                )),
                // One parameter, BOOL return
                JSONFile(name: "Platform3-ModuleName.symbols.json", content: makeSymbolGraph(
                    platform: .init(operatingSystem: .init(name: "Platform3")),
                    docComment: nil,
                    sourceLanguage: .objectiveC,
                    parameters: [(name: "first", externalName: nil),],
                    returnValue: .init(kind: .typeIdentifier, spelling: "BOOL", preciseIdentifier: "c:@T@BOOL")
                )),
                TextFile(name: "Extension.md", utf8Content: """
                # ``functionName(...)``
                
                A documentation extension that documents both parameters
                
                - Parameters:
                  - first: Some description of the parameter that is available on all three platforms.
                  - second: Some description of the parameter that is only available on platform 2.
                - Returns: Some description of the return value that is only available on platform 3.
                """)
            ])
        ])
        let (_, bundle, context) = try loadBundle(from: url)
        
        XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ModuleName/functionName(...)", sourceLanguage: .swift)
        let node = try context.entity(with: reference)
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        
        let parameterSections = symbol.parametersSectionVariants
        XCTAssertEqual(parameterSections[.objectiveC]?.parameters.map(\.name), ["first", "second"])
        XCTAssertEqual(parameterSections[.objectiveC]?.parameters.first?.contents.map({ $0.format() }).joined(), "Some description of the parameter that is available on all three platforms.")
        XCTAssertEqual(parameterSections[.objectiveC]?.parameters.last?.contents.map({ $0.format() }).joined(), "Some description of the parameter that is only available on platform 2.")
        
        let returnSections = symbol.returnsSectionVariants
        XCTAssertEqual(returnSections[.objectiveC]?.content.map({ $0.format() }).joined(), "Some description of the return value that is only available on platform 3.")
    }
    
    func testFunctionWithErrorParameterButVoidType() throws {
        let url = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                Folder(name: "swift", content: [
                    JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                        docComment: nil,
                        sourceLanguage: .swift,
                        parameters: [(name: "error", externalName: nil)],
                        returnValue: .init(kind: .typeIdentifier, spelling: "Void", preciseIdentifier: "s:s4Voida")
                    ))
                ]),
                Folder(name: "clang", content: [
                    JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                        docComment: """
                        Some function description
                        
                        - Parameter error: Some parameter description.
                        """,
                        sourceLanguage: .objectiveC,
                        parameters: [(name: "error", externalName: nil)],
                        returnValue: .init(kind: .typeIdentifier, spelling: "void", preciseIdentifier: "c:v")
                    ))
                ])
            ])
        ])
        let (_, bundle, context) = try loadBundle(from: url)
        
        XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ModuleName/functionName(...)", sourceLanguage: .swift)
        let node = try context.entity(with: reference)
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        
        let parameterSections = symbol.parametersSectionVariants
        XCTAssertEqual(parameterSections[.swift]?.parameters.map(\.name), ["error"])
        XCTAssertEqual(parameterSections[.swift]?.parameters.last?.contents.map({ $0.format() }).joined(), "Some parameter description.")
        XCTAssertEqual(parameterSections[.objectiveC]?.parameters.map(\.name), ["error"])
        XCTAssertEqual(parameterSections[.objectiveC]?.parameters.last?.contents.map({ $0.format() }).joined(), "Some parameter description.")
        
        let returnsSections = symbol.returnsSectionVariants
        XCTAssertNil(returnsSections[.swift])
        XCTAssertNil(returnsSections[.objectiveC])
    }
    
    func testWarningForDocumentingExternalParameterNames() throws {
        let warningOutput = try warningOutputRaisedFrom(
            docComment: """
            Some function description
            
            - Parameter with: Some parameter description
            """,
            parameters: [(name: "someValue", externalName: "with")],
            returnValue: .init(kind: .typeIdentifier, spelling: "Void", preciseIdentifier: "s:s4Voida")
        )
        XCTAssertEqual(warningOutput, """
        warning: External name 'with' used to document parameter
          --> /path/to/SomeFile.swift:10:19-10:23
        8  |   /// Some function description
        9  |   ///
        10 +   /// - Parameter with: Some parameter description
           |                   ╰─suggestion: Replace 'with' with 'someValue'
        """)
    }
    
    func testWarningForDocumentingVoidReturn() throws {
        let warningOutput = try warningOutputRaisedFrom(
            docComment: """
            Some function description
            
            - Parameter someValue: Some parameter description
            - Returns: Some return value description
            """,
            parameters: [(name: "someValue", externalName: "with")],
            returnValue: .init(kind: .typeIdentifier, spelling: "Void", preciseIdentifier: "s:s4Voida")
        )
        XCTAssertEqual(warningOutput, """
        warning: Return value documented for function returning void
          --> /path/to/SomeFile.swift:11:7-11:47
        9  |   ///
        10 |   /// - Parameter someValue: Some parameter description
        11 +   /// - Returns: Some return value description
           |       ╰─suggestion: Remove return value documentation
        """)
    }
    
    func testWarningForParameterDocumentedTwice() throws {
        let warningOutput = try warningOutputRaisedFrom(
            docComment: """
            Some function description
            
            - Parameter someValue: Some parameter description
            - Parameter someValue: Some parameter description
            """,
            parameters: [(name: "someValue", externalName: "with")],
            returnValue: .init(kind: .typeIdentifier, spelling: "Void", preciseIdentifier: "s:s4Voida")
        )
        XCTAssertEqual(warningOutput, """
        warning: Parameter 'someValue' is already documented
        /path/to/SomeFile.swift:10:7: Previously documented here
          --> /path/to/SomeFile.swift:11:7-11:56
        9  |   ///
        10 |   /// - Parameter someValue: Some parameter description
        11 +   /// - Parameter someValue: Some parameter description
           |       ╰─suggestion: Remove duplicate parameter documentation
        """)
    }
    
    func testWarningForExtraDocumentedParameter() throws {
        let warningOutput = try warningOutputRaisedFrom(
            docComment: """
            Some function description
            
            - Parameter someValue: Some parameter description
            - Parameter anotherValue: Some other parameter description
            """,
            parameters: [(name: "someValue", externalName: "with")],
            returnValue: .init(kind: .typeIdentifier, spelling: "Void", preciseIdentifier: "s:s4Voida")
        )
        XCTAssertEqual(warningOutput, """
        warning: Parameter 'anotherValue' not found in function declaration
          --> /path/to/SomeFile.swift:11:7-11:65
        9  |   ///
        10 |   /// - Parameter someValue: Some parameter description
        11 +   /// - Parameter anotherValue: Some other parameter description
           |       ╰─suggestion: Remove 'anotherValue' parameter documentation
        """)
    }
    
    func testWarningForUndocumentedParameter() throws {
        let missingFirstWarningOutput = try warningOutputRaisedFrom(
            docComment: """
            Some function description
            
            - Parameter second: Some parameter description
            """,
            parameters: [(name: "first", externalName: "with"), (name: "second", externalName: "and")],
            returnValue: .init(kind: .typeIdentifier, spelling: "Void", preciseIdentifier: "s:s4Voida")
        )
        XCTAssertEqual(missingFirstWarningOutput, """
        warning: Parameter 'first' is missing documentation
          --> /path/to/SomeFile.swift:10:53-10:53
        8  |   /// Some function description
        9  |   ///
        10 +   /// - Parameter second: Some parameter description
           |       ╰─suggestion: Document 'first' parameter
        """)
        
        
        let missingSecondWarningOutput = try warningOutputRaisedFrom(
            docComment: """
            Some function description
            
            - Parameter first: Some parameter description
            """,
            parameters: [(name: "first", externalName: "with"), (name: "second", externalName: "and")],
            returnValue: .init(kind: .typeIdentifier, spelling: "Void", preciseIdentifier: "s:s4Voida")
        )
        XCTAssertEqual(missingSecondWarningOutput, """
        warning: Parameter 'second' is missing documentation
          --> /path/to/SomeFile.swift:10:52-10:52
        8  |   /// Some function description
        9  |   ///
        10 +   /// - Parameter first: Some parameter description
           |                                                    ╰─suggestion: Document 'second' parameter
        """)
        
        
    }
    
    // MARK: Test helpers
    
    private func warningOutputRaisedFrom(
        docComment: String,
        parameters: [(name: String, externalName: String?)],
        returnValue: SymbolGraph.Symbol.DeclarationFragments.Fragment,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> String {
        let url = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                    docComment: docComment,
                    sourceLanguage: .swift,
                    parameters: parameters,
                    returnValue: returnValue
                ))
            ])
        ])
        let logStorage = LogHandle.LogStorage()
        let (_, _, context) = try loadBundle(from: url, configureContext: { context in
            for consumerID in context.diagnosticEngine.consumers.sync({ $0.values }) {
                context.diagnosticEngine.remove(consumerID)
            }
            let fileSystem = try TestFileSystem(folders: [
                Folder(name: "path", content: [
                    Folder(name: "to", content: [
                        // The generated symbol graph uses a fake source file where the documentation comment starts at line 7, column 6
                        TextFile(name: "SomeFile.swift", utf8Content: String(repeating: "\n", count: 7) + docComment.splitByNewlines.map { "  /// \($0)" }.joined(separator: "\n"))
                    ])
                ])
            ])
            context.diagnosticEngine.add(DiagnosticConsoleWriter(LogHandle.memory(logStorage), highlight: false, fileManager: fileSystem))
        })
        
        context.diagnosticEngine.flush()
        return logStorage.text
    }
    
    private let start = SymbolGraph.LineList.SourceRange.Position(line: 7, character: 6) // an arbitrary non-zero start position
    private let symbolURL = URL(fileURLWithPath: "/path/to/SomeFile.swift")
    
    private func makeSymbolGraph(docComment: String) -> SymbolGraph {
        makeSymbolGraph(
            docComment: docComment,
            sourceLanguage: .swift,
            parameters: [
                ("firstParameter", nil),
                ("secondParameter", nil),
                ("thirdParameter", nil),
                ("fourthParameter", nil),
            ],
            returnValue: .init(kind: .typeIdentifier, spelling: "ReturnValue", preciseIdentifier: "return-value-id")
        )
    }
    
    private func makeSymbolGraph(
        platform: SymbolGraph.Platform = .init(),
        docComment: String?,
        sourceLanguage: SourceLanguage,
        parameters: [(name: String, externalName: String?)],
        returnValue: SymbolGraph.Symbol.DeclarationFragments.Fragment
    ) -> SymbolGraph {
        return makeSymbolGraph(
            moduleName: "ModuleName",
            platform: platform,
            symbols: [
                makeSymbol(
                    id: "symbol-id",
                    language: sourceLanguage,
                    kind: .func,
                    pathComponents: ["functionName(...)"],
                    docComment: docComment,
                    location: (start, symbolURL),
                    signature: .init(
                        parameters: parameters.map {
                            .init(name: $0.name, externalName: $0.externalName, declarationFragments: [], children: [])
                        },
                        returns: [returnValue]
                    )
                )
            ]
        )
    }
}
