/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
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
    
    override func setUp() {
        super.setUp()
        enableFeatureFlag(\.isExperimentalParametersAndReturnsValidationEnabled)
    }
    
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
            XCTAssertEqual(parameterSections[.objectiveC]?.parameters.last?.contents.map({ $0.format() }).joined(), "On input, a pointer to an error object. If an error occurs, this pointer is set to an actual error object containing the error information.")
            
            let returnsSections = symbol.returnsSectionVariants
            XCTAssertEqual(returnsSections[.swift]?.content.map({ $0.format() }).joined(), "", "The method has no return value documentation but needs an empty returns section to so that the rendered page doesn't use the Objective-C variant as a fallback.")
            XCTAssertEqual(returnsSections[.objectiveC]?.content.map({ $0.format() }).joined(), "`YES` if successful, or `NO` if an error occurred.", "The Objective-C variant returns BOOL")
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
            XCTAssertEqual(returnsSections[.objectiveC]?.content.map({ $0.format() }).joined(), "Some string. If an error occurs, this method returns `nil` and assigns an appropriate error object to the `error` parameter.")
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
            XCTAssertEqual(context.problems.count, 5)
            
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
            
            let undocumentedParameterProblem = try XCTUnwrap(context.problems.first(where: { $0.diagnostic.summary == "Parameter 'someValue' is missing documentation" }))
            XCTAssertEqual(undocumentedParameterProblem.diagnostic.source, url.appendingPathComponent("swift-extension.md"))
            XCTAssertEqual(undocumentedParameterProblem.diagnostic.range?.lowerBound.line, 10)
            XCTAssertEqual(undocumentedParameterProblem.diagnostic.range?.lowerBound.column, 37)
            XCTAssertEqual(undocumentedParameterProblem.diagnostic.range?.upperBound.line, 10)
            XCTAssertEqual(undocumentedParameterProblem.diagnostic.range?.upperBound.column, 37)
            
            XCTAssertEqual(undocumentedParameterProblem.possibleSolutions.first?.summary, "Document 'someValue' parameter")
            XCTAssertEqual(undocumentedParameterProblem.possibleSolutions.first?.replacements.first?.range.source, url.appendingPathComponent("swift-extension.md"))
            XCTAssertEqual(undocumentedParameterProblem.possibleSolutions.first?.replacements.first?.range.lowerBound.line, 10)
            XCTAssertEqual(undocumentedParameterProblem.possibleSolutions.first?.replacements.first?.range.lowerBound.column, 1)
            XCTAssertEqual(undocumentedParameterProblem.possibleSolutions.first?.replacements.first?.range.upperBound.line, 10)
            XCTAssertEqual(undocumentedParameterProblem.possibleSolutions.first?.replacements.first?.range.upperBound.column, 1)
            XCTAssertEqual(undocumentedParameterProblem.possibleSolutions.first?.replacements.first?.replacement, "- Parameter someValue: <#parameter description#>\n///")
        }
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
    
    private let start = SymbolGraph.LineList.SourceRange.Position(line: 7, character: 3) // an arbitrary non-zero start position
    private let symbolURL =  URL(fileURLWithPath: "/path/to/SomeFile.swift")
    
    private func makeSymbolGraph(docComment: String) -> SymbolGraph {
        let uri = symbolURL.absoluteString // we want to include the file:// scheme here
        func makeLineList(text: String) -> SymbolGraph.LineList {
            
            return .init(text.splitByNewlines.enumerated().map { lineOffset, line in
                    .init(text: line, range: .init(start: .init(line: start.line + lineOffset, character: start.character),
                                                   end: .init(line: start.line + lineOffset, character: start.character + line.count)))
            }, uri: uri)
        }
        
        return makeSymbolGraph(
            moduleName: "ModuleName",
            symbols: [
                .init(
                    identifier: .init(precise: "symbol-id", interfaceLanguage: "swift"),
                    names: .init(title: "functionName(...)", navigator: nil, subHeading: nil, prose: nil),
                    pathComponents: ["functionName(...)"],
                    docComment: makeLineList(text: docComment),
                    accessLevel: .public, kind: .init(parsedIdentifier: .func, displayName: "Function"),
                    mixins: [
                        SymbolGraph.Symbol.Location.mixinKey: SymbolGraph.Symbol.Location(uri: uri, position: start),
                        
                        SymbolGraph.Symbol.FunctionSignature.mixinKey: SymbolGraph.Symbol.FunctionSignature(
                            parameters: [
                                .init(name: "firstParameter", externalName: nil, declarationFragments: [], children: []),
                                .init(name: "secondParameter", externalName: nil, declarationFragments: [], children: []),
                                .init(name: "thirdParameter", externalName: nil, declarationFragments: [], children: []),
                                .init(name: "fourthParameter", externalName: nil, declarationFragments: [], children: []),
                            ],
                            returns: [
                                .init(kind: .typeIdentifier, spelling: "ReturnValue", preciseIdentifier: "return-value-id")
                            ]
                        )
                    ]
                )
            ]
        )
    }
}
