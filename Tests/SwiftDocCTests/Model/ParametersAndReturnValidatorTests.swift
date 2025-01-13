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
            let reference = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/ErrorParameters/MyClassInObjectiveC/doSomething(with:)", sourceLanguage: .swift)
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
            let reference = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/ErrorParameters/MyClassInObjectiveC/returnSomething()", sourceLanguage: .swift)
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
            let reference = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/ErrorParameters/MyClassInSwift/doSomething(with:)", sourceLanguage: .swift)
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
            let reference = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/ErrorParameters/MyClassInSwift/returnSomething()", sourceLanguage: .swift)
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
    
    func testExtendsReturnValueDocumentation() throws {
        for (returnValueDescription, expectsExtendedDocumentation) in [
            // Expects to extend the documentation
            ("Returns some value.", true),
            ("Returns some failsafe value.", true),
            ("Returns some errorless value.", true),
            ("Returns a NSNull value.", true),
            
            // Expects to not extend the documentation
            ("Returns some value, except if the function fails.", false),
            ("Returns some value. If an error occurs, this function doesn't return a value.", false),
            ("Returns some value. On failure, this function doesn't return a value.", false),
            ("Returns some value. If something happens, this function returns `nil` instead.", false),
            ("Returns some value, or `nil` if something goes wrong.", false),
            ("Returns some value, or `NULL` if something goes wrong.", false),
            ("Returns some value or a null-pointer.", false),
        ] {
            let catalog = Folder(name: "unit-test.docc", content: [
                Folder(name: "swift", content: [
                    JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                        docComment: nil,
                        docCommentModuleName: "ModuleName",
                        sourceLanguage: .swift,
                        parameters: [],
                        returnValue: .init(kind: .typeIdentifier, spelling: "String", preciseIdentifier: "s:SS")
                    ))
                ]),
                Folder(name: "clang", content: [
                    JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                        docComment: """
                        Some function description
                        
                        - Returns: \(returnValueDescription)
                        """,
                        docCommentModuleName: "ModuleName",
                        sourceLanguage: .objectiveC,
                        parameters: [(name: "error", externalName: nil)],
                        returnValue: .init(kind: .typeIdentifier, spelling: "NSString", preciseIdentifier: "c:objc(cs)NSString")
                    ))
                ])
            ])
            
            let (bundle, context) = try loadBundle(catalog: catalog)
            
            XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
            
            let reference = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/ModuleName/functionName(...)", sourceLanguage: .swift)
            let node = try context.entity(with: reference)
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            
            let parameterSections = symbol.parametersSectionVariants
            XCTAssertEqual(parameterSections[.swift]?.parameters.map(\.name), [], "The Swift variant has no error parameter")
            XCTAssertEqual(parameterSections[.objectiveC]?.parameters.map(\.name), ["error"])
            XCTAssertEqual(parameterSections[.objectiveC]?.parameters.last?.contents.map({ $0.format() }).joined(), "On output, a pointer to an error object that describes why the method failed, or `nil` if no error occurred. If you are not interested in the error information, pass `nil` for this parameter.")
            
            let returnsSections = symbol.returnsSectionVariants
            let expectedReturnValueDescription = returnValueDescription.replacingOccurrences(of: "\'", with: "’")
            XCTAssertEqual(returnsSections[.swift]?.content.map({ $0.format() }).joined(), expectedReturnValueDescription)
            if expectsExtendedDocumentation {
                XCTAssertEqual(returnsSections[.objectiveC]?.content.map({ $0.format() }).joined(), "\(expectedReturnValueDescription) On failure, this method returns `nil`.")
            } else {
                XCTAssertEqual(returnsSections[.objectiveC]?.content.map({ $0.format() }).joined(), expectedReturnValueDescription)
            }
        }
    }
    
    func testParametersWithAlternateSignatures() throws {
        let (_, _, context) = try testBundleAndContext(copying: "AlternateDeclarations") { url in
            try """
            # ``MyClass/present(completion:)``
            
            @Metadata {
              @DocumentationExtension(mergeBehavior: override)
            }
            
            Override the documentation with a parameter section that raise warnings.
            
            - Parameters:
              - completion: Description of the parameter that's available in some alternatives.
            - Returns: Description of the return value that's available for some other alternatives.
            """.write(to: url.appendingPathComponent("extension.md"), atomically: true, encoding: .utf8)
        }
        
        let reference = try XCTUnwrap(context.soleRootModuleReference).appendingPath("MyClass/present(completion:)")
        let node = try context.entity(with: reference)
        let symbolSemantic = try XCTUnwrap(node.semantic as? Symbol)
        
        let swiftParameterNames = symbolSemantic.parametersSectionVariants.firstValue?.parameters
        
        XCTAssertEqual(swiftParameterNames?.map(\.name), ["completion"])
        XCTAssertEqual(swiftParameterNames?.map { _format($0.contents) }, ["Description of the parameter that’s available in some alternatives."])
        
        let swiftReturnsContent = symbolSemantic.returnsSection.map { _format($0.content) }
        XCTAssertEqual(swiftReturnsContent, "Description of the return value that’s available for some other alternatives.")
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
    
    func testCanDocumentInitializerReturnValue() throws {
        let (_, _, context) = try testBundleAndContext(copying: "GeometricalShapes") { url in
            try """
            # ``Circle/init(center:radius:)``
            
            @Metadata {
              @DocumentationExtension(mergeBehavior: override)
            }
            
            Override the documentation with a return section that raise warnings.
            
            - Returns: Return value documentation for an initializer.
            """.write(to: url.appendingPathComponent("init-extension.md"), atomically: true, encoding: .utf8)
        }
        XCTAssertEqual(context.problems.map(\.diagnostic.summary), [])
        
        let reference = try XCTUnwrap(context.soleRootModuleReference).appendingPath("Circle/init(center:radius:)")
        let node = try context.entity(with: reference)
        
        // Verify that this symbol doesn't have a return value in its signature
        XCTAssertEqual(node.symbol?.functionSignature?.returns, [])
        
        let symbolSemantic = try XCTUnwrap(node.semantic as? Symbol)
        let swiftReturnsSection = try XCTUnwrap(
            symbolSemantic.returnsSectionVariants.allValues.first(where: { trait, _ in trait.interfaceLanguage == "swift" })
        ).variant
        XCTAssertEqual(swiftReturnsSection.content.map { $0.format() }, [
            "Return value documentation for an initializer."
        ])
    }
    
    func testNoParameterDiagnosticWithoutFunctionSignature() throws {
        var symbolGraph = makeSymbolGraph(docComment: """
            Some function description
            
            - Parameters:
              - secondParameter: One description
              - thirdParameter: Another description
            """)
        
        symbolGraph.symbols["symbol-id"]?.mixins[SymbolGraph.Symbol.FunctionSignature.mixinKey] = nil
        
        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "ModuleName.symbols.json", content: symbolGraph)
        ])
        let (_, context) = try loadBundle(catalog: catalog)
        
        XCTAssertEqual(context.problems.count, 0)
    }
    
    func testNoParameterDiagnosticWithoutDocumentationComment() throws {
        let symbolGraph = makeSymbolGraph(docComment: """
            Some function description
            
            No parameters section
            """)
        
        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "ModuleName.symbols.json", content: symbolGraph)
        ])
        let (_, context) = try loadBundle(catalog: catalog)
        
        XCTAssertEqual(context.problems.count, 0)
    }
    
    func testMissingParametersInDocCommentDiagnostics() throws {
        let symbolGraph = makeSymbolGraph(docComment: """
            Some function description
            
            - Parameters:
              - secondParameter: One description
              - thirdParameter: Another description
            """)
        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "ModuleName.symbols.json", content: symbolGraph)
        ])
        let (_, context) = try loadBundle(catalog: catalog)
        
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
        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "ModuleName.symbols.json", content: symbolGraph)
        ])
        let (_, context) = try loadBundle(catalog: catalog)
        
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
        let catalog =
            Folder(name: "unit-test.docc", content: [
                Folder(name: "swift", content: [
                    JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                        docComment: nil,
                        docCommentModuleName: "ModuleName",
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
                        docCommentModuleName: "ModuleName",
                        sourceLanguage: .objectiveC,
                        parameters: [(name: "error", externalName: nil)],
                        returnValue: .init(kind: .typeIdentifier, spelling: "BOOL", preciseIdentifier: "c:@T@BOOL")
                    ))
                ])
            ])
        let (bundle, context) = try loadBundle(catalog: catalog)
        
        XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let reference = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/ModuleName/functionName(...)", sourceLanguage: .swift)
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
        let catalog =
            Folder(name: "unit-test.docc", content: [
                // One parameter, void return
                JSONFile(name: "Platform1-ModuleName.symbols.json", content: makeSymbolGraph(
                    platform: .init(operatingSystem: .init(name: "Platform1")),
                    docComment: nil,
                    docCommentModuleName: "ModuleName",
                    sourceLanguage: .objectiveC,
                    parameters: [(name: "first", externalName: nil)],
                    returnValue: .init(kind: .typeIdentifier, spelling: "void", preciseIdentifier: "c:v")
                )),
                // Two parameters, void return
                JSONFile(name: "Platform2-ModuleName.symbols.json", content: makeSymbolGraph(
                    platform: .init(operatingSystem: .init(name: "Platform2")),
                    docComment: nil,
                    docCommentModuleName: "ModuleName",
                    sourceLanguage: .objectiveC,
                    parameters: [(name: "first", externalName: nil), (name: "second", externalName: nil)],
                    returnValue: .init(kind: .typeIdentifier, spelling: "void", preciseIdentifier: "c:v")
                )),
                // One parameter, BOOL return
                JSONFile(name: "Platform3-ModuleName.symbols.json", content: makeSymbolGraph(
                    platform: .init(operatingSystem: .init(name: "Platform3")),
                    docComment: nil,
                    docCommentModuleName: "ModuleName",
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
        
        let (bundle, context) = try loadBundle(catalog: catalog)
        
        XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let reference = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/ModuleName/functionName(...)", sourceLanguage: .swift)
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
        let catalog =
            Folder(name: "unit-test.docc", content: [
                Folder(name: "swift", content: [
                    JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                        docComment: nil,
                        docCommentModuleName: "ModuleName",
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
                        docCommentModuleName: "ModuleName",
                        sourceLanguage: .objectiveC,
                        parameters: [(name: "error", externalName: nil)],
                        returnValue: .init(kind: .typeIdentifier, spelling: "void", preciseIdentifier: "c:v")
                    ))
                ])
            ])
        
        let (bundle, context) = try loadBundle(catalog: catalog)
        
        XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let reference = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/ModuleName/functionName(...)", sourceLanguage: .swift)
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
    
    func testDoesNotWarnAboutInheritedDocumentation() throws {
        let warningOutput = try warningOutputRaisedFrom(
            docComment: """
            Some function description
            
            - Parameter second: Some parameter description
            - Returns: Nothing.
            """,
            docCommentModuleName: "SomeOtherModule",
            parameters: [(name: "first", externalName: "with"), (name: "second", externalName: "and")],
            returnValue: .init(kind: .typeIdentifier, spelling: "Void", preciseIdentifier: "s:s4Voida")
        )
        XCTAssertEqual(warningOutput, "")
    }
    
    func testDocumentingTwoUnnamedParameters() throws {
        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                docComment: """
                Some function description
                
                - Parameters: 
                  - first: Some unnamed parameter description
                  - anything: Some second unnamed parameter description
                """,
                docCommentModuleName: "ModuleName",
                sourceLanguage: .swift,
                parameters: .init(repeating: (name: "", externalName: nil), count: 2),
                returnValue: .init(kind: .typeIdentifier, spelling: "Void", preciseIdentifier: "s:s4Voida")
            ))
        ])
        
        let (bundle, context) = try loadBundle(catalog: catalog)
        
        XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let reference = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/ModuleName/functionName(...)", sourceLanguage: .swift)
        let node = try context.entity(with: reference)
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        
        let parameterSections = symbol.parametersSectionVariants
        XCTAssertEqual(parameterSections[.swift]?.parameters.map(\.name), ["first", "anything"])
        XCTAssertEqual(parameterSections[.swift]?.parameters.first?.contents.map({ $0.format() }).joined(), "Some unnamed parameter description")
        XCTAssertEqual(parameterSections[.swift]?.parameters.last?.contents.map({ $0.format() }).joined(), "Some second unnamed parameter description")
        XCTAssertNil(parameterSections[.objectiveC])
        
        let returnsSections = symbol.returnsSectionVariants
        XCTAssertNil(returnsSections[.swift])
        XCTAssertNil(returnsSections[.objectiveC])
    }
    
    func testDocumentingMixedNamedAndUnnamedParameters() throws {
        // This test verifies the behavior of documenting two named parameters and one unnamed parameter.
        //
        // It checks different combinations of which parameter is unnamed:
        // "_ second third"   "first _ third"   "first second _"
        // And different combinations of the order that these parameters are documented:
        // "anything second third"   "second anything third"    "second third anything"  etc.
        
        let functionParameterNames = ["first", "second", "third"]
        
        // Check each possible parameter that could be unnamed
        for unnamedParameterIndex in functionParameterNames.indices {
            var functionParameterNames = functionParameterNames
            functionParameterNames[unnamedParameterIndex] = "_"
            
            var expectedParameterNames = functionParameterNames
            expectedParameterNames[unnamedParameterIndex] = "anything"
            
            // Check each possible order that these parameters could be documented.
            for index in functionParameterNames.indices {
                var documentedParameterNames = functionParameterNames
                documentedParameterNames.remove(at: unnamedParameterIndex)
                documentedParameterNames.insert("anything", at: index)
                XCTAssertEqual(documentedParameterNames.count, functionParameterNames.count)
                
                let catalog = Folder(name: "unit-test.docc", content: [
                    JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                        docComment: """
                        Some function description
                        
                        - Parameters: 
                          - \(documentedParameterNames[0]): Some \(documentedParameterNames[0]) parameter description
                          - \(documentedParameterNames[1]): Some \(documentedParameterNames[1]) parameter description
                          - \(documentedParameterNames[2]): Some \(documentedParameterNames[2]) parameter description
                        """,
                        docCommentModuleName: "ModuleName",
                        sourceLanguage: .swift,
                        parameters: functionParameterNames.map { (name: $0, externalName: nil) },
                        returnValue: .init(kind: .typeIdentifier, spelling: "Void", preciseIdentifier: "s:s4Voida")
                    ))
                ])
                let (bundle, context) = try loadBundle(catalog: catalog)
                
                XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
                
                let reference = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/ModuleName/functionName(...)", sourceLanguage: .swift)
                let node = try context.entity(with: reference)
                let symbol = try XCTUnwrap(node.semantic as? Symbol)
                
                let parameterSections = symbol.parametersSectionVariants
                // Verify that the parameter names are in the expected order.
                XCTAssertEqual(parameterSections[.swift]?.parameters.map(\.name), expectedParameterNames)
                // Verify that the parameter descriptions are in the expected order.
                XCTAssertEqual(parameterSections[.swift]?.parameters[0].contents.map { $0.format() }.joined(), "Some \(expectedParameterNames[0]) parameter description")
                XCTAssertEqual(parameterSections[.swift]?.parameters[1].contents.map { $0.format() }.joined(), "Some \(expectedParameterNames[1]) parameter description")
                XCTAssertEqual(parameterSections[.swift]?.parameters[2].contents.map { $0.format() }.joined(), "Some \(expectedParameterNames[2]) parameter description")
                XCTAssertNil(parameterSections[.objectiveC])
                
                let returnsSections = symbol.returnsSectionVariants
                XCTAssertNil(returnsSections[.swift])
                XCTAssertNil(returnsSections[.objectiveC])
            }
        }
    }
    
    func testWarningsForMissingOrExtraUnnamedParameters() throws {
        let returnValue = SymbolKit.SymbolGraph.Symbol.DeclarationFragments.Fragment(kind: .typeIdentifier, spelling: "void", preciseIdentifier: "c:v")
        
        let tooFewParametersOutput = try warningOutputRaisedFrom(
            docComment: """
            Some function description
            
            - Parameters: 
              - first: Some unnamed parameter description
            """,
            parameters: .init(repeating: (name: "", externalName: nil), count: 3),
            returnValue: returnValue
        )
        
        XCTAssertEqual(tooFewParametersOutput, """
        warning: Unnamed parameter #2 is missing documentation
          --> /path/to/SomeFile.swift:11:52-11:52
        9  |   ///
        10 |   /// - Parameters:
        11 +   ///   - first: Some unnamed parameter description
           |                                                    ╰─suggestion: Document unnamed parameter #2

        warning: Unnamed parameter #3 is missing documentation
          --> /path/to/SomeFile.swift:11:52-11:52
        9  |   ///
        10 |   /// - Parameters:
        11 +   ///   - first: Some unnamed parameter description
           |                                                    ╰─suggestion: Document unnamed parameter #3
        """)
        
        let tooManyParametersOutput = try warningOutputRaisedFrom(
            docComment: """
            Some function description
            
            - Parameters: 
              - first: Some unnamed parameter description
              - anything: Some second unnamed parameter description
              - third: More parameters than the function signature
            """,
            parameters: .init(repeating: (name: "", externalName: nil), count: 2),
            returnValue: returnValue
        )
        XCTAssertEqual(tooManyParametersOutput, """
        warning: Parameter 'third' not found in function declaration
          --> /path/to/SomeFile.swift:13:9-13:61
        11 |   ///   - first: Some unnamed parameter description
        12 |   ///   - anything: Some second unnamed parameter description
        13 +   ///   - third: More parameters than the function signature
           |         ╰─suggestion: Remove 'third' parameter documentation
        """)
    }
    
    // MARK: Test helpers
    
    private func warningOutputRaisedFrom(
        docComment: String,
        docCommentModuleName: String? = "ModuleName",
        parameters: [(name: String, externalName: String?)],
        returnValue: SymbolGraph.Symbol.DeclarationFragments.Fragment,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> String {
        let fileSystem = try TestFileSystem(folders: [
            Folder(name: "path", content: [
                Folder(name: "to", content: [
                    // The generated symbol graph uses a fake source file where the documentation comment starts at line 7, column 6
                    TextFile(name: "SomeFile.swift", utf8Content: String(repeating: "\n", count: 7) + docComment.splitByNewlines.map { "  /// \($0)" }.joined(separator: "\n"))
                ])
            ]),
      
            Folder(name: "unit-test.docc", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                    docComment: docComment,
                    docCommentModuleName: docCommentModuleName,
                    sourceLanguage: .swift,
                    parameters: parameters,
                    returnValue: returnValue
                ))
            ])
        ])
        
        let logStorage = LogHandle.LogStorage()
        
        let diagnosticEngine = DiagnosticEngine()
        diagnosticEngine.add(DiagnosticConsoleWriter(LogHandle.memory(logStorage), highlight: false, dataProvider: fileSystem))
        
        let (bundle, dataProvider) = try DocumentationContext.InputsProvider(fileManager: fileSystem)
            .inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/unit-test.docc"), options: .init())

        _ = try DocumentationContext(bundle: bundle, dataProvider: dataProvider, diagnosticEngine: diagnosticEngine)
        
        diagnosticEngine.flush()
        return logStorage.text.trimmingCharacters(in: .newlines)
    }
    
    private let start = SymbolGraph.LineList.SourceRange.Position(line: 7, character: 6) // an arbitrary non-zero start position
    private let symbolURL = URL(fileURLWithPath: "/path/to/SomeFile.swift")
    
    private func makeSymbolGraph(docComment: String) -> SymbolGraph {
        makeSymbolGraph(
            docComment: docComment,
            docCommentModuleName: "ModuleName",
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
        docCommentModuleName: String?,
        sourceLanguage: SourceLanguage,
        parameters: [(name: String, externalName: String?)],
        returnValue: SymbolGraph.Symbol.DeclarationFragments.Fragment
    ) -> SymbolGraph {
        return makeSymbolGraph(
            moduleName: "ModuleName", // Don't use `docCommentModuleName` here.
            platform: platform,
            symbols: [
                makeSymbol(
                    id: "symbol-id",
                    language: sourceLanguage,
                    kind: .func,
                    pathComponents: ["functionName(...)"],
                    docComment: docComment,
                    moduleName: docCommentModuleName,
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

// A small test helper to format markup for test assertions in this file.
private func _format(_ markup: [any Markup]) -> String {
    markup.map { $0.format() }.joined()
}
