/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC
import TestUtilities
import SymbolKit

fileprivate let jsonDecoder = JSONDecoder()
fileprivate let jsonEncoder = JSONEncoder()

class ConstraintsRenderSectionTests: XCTestCase {
    
    func testSingleConstraint() async throws {
        let (_, _, context) = try await testBundleAndContext(copying: "LegacyBundle_DoNotUseInNewTests", excludingPaths: []) { bundleURL in
            // Add constraints to `MyClass`
            let graphURL = bundleURL.appendingPathComponent("mykit-iOS.symbols.json")
            var graph = try jsonDecoder.decode(SymbolGraph.self, from: try Data(contentsOf: graphURL))
            
            // "Inject" generic constraints
            graph.symbols = try graph.symbols.mapValues({ symbol -> SymbolGraph.Symbol in
                guard symbol.identifier.precise == "s:5MyKit0A5ClassC" else { return symbol }
                var symbol = symbol
                symbol.mixins[SymbolGraph.Symbol.Swift.Extension.mixinKey] = try jsonDecoder.decode(SymbolGraph.Symbol.Swift.Extension.self, from: """
                {"extendedModule": "MyKit",
                 "constraints": [
                    { "kind" : "sameType", "lhs" : "Label", "rhs" : "Text" }
                ]}
                """.data(using: .utf8)!)
                return symbol
            })
            try jsonEncoder.encode(graph).write(to: graphURL)
        }

        // Compile docs and verify contents
        let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/MyKit/MyClass", sourceLanguage: .swift))
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        let renderNode = translator.visitSymbol(symbol) as! RenderNode
        
        XCTAssertEqual(renderNode.metadata.conformance?.constraints.map(flattenInlineElements).joined(), "Label is Text.")
    }

    func testSingleRedundantConstraint() async throws {
        let (_, _, context) = try await testBundleAndContext(copying: "LegacyBundle_DoNotUseInNewTests", excludingPaths: []) { bundleURL in
            // Add constraints to `MyClass`
            let graphURL = bundleURL.appendingPathComponent("mykit-iOS.symbols.json")
            var graph = try jsonDecoder.decode(SymbolGraph.self, from: try Data(contentsOf: graphURL))
            
            // "Inject" generic constraints
            graph.symbols = try graph.symbols.mapValues({ symbol -> SymbolGraph.Symbol in
                guard symbol.identifier.precise == "s:5MyKit0A5ClassC" else { return symbol }
                var symbol = symbol
                symbol.mixins[SymbolGraph.Symbol.Swift.Extension.mixinKey] = try jsonDecoder.decode(SymbolGraph.Symbol.Swift.Extension.self, from: """
                {"extendedModule": "MyKit",
                 "constraints": [
                    { "kind" : "sameType", "lhs" : "Self", "rhs" : "MyClass" }
                ]}
                """.data(using: .utf8)!)
                return symbol
            })
            try jsonEncoder.encode(graph).write(to: graphURL)
        }

        // Compile docs and verify contents
        let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/MyKit/MyClass", sourceLanguage: .swift))
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        let renderNode = translator.visitSymbol(symbol) as! RenderNode
        XCTAssertNil(renderNode.metadata.conformance)
    }

    func testSingleRedundantConstraintForLeaves() async throws {
        let (_, _, context) = try await testBundleAndContext(copying: "LegacyBundle_DoNotUseInNewTests", excludingPaths: []) { bundleURL in
            // Add constraints to `MyClass`
            let graphURL = bundleURL.appendingPathComponent("mykit-iOS.symbols.json")
            var graph = try jsonDecoder.decode(SymbolGraph.self, from: try Data(contentsOf: graphURL))
            
            // "Inject" generic constraints
            graph.symbols = try graph.symbols.mapValues({ symbol -> SymbolGraph.Symbol in
                guard symbol.identifier.precise == "s:5MyKit0A5ClassC10myFunctionyyF" else { return symbol }
                var symbol = symbol
                symbol.mixins[SymbolGraph.Symbol.Swift.Extension.mixinKey] = try jsonDecoder.decode(SymbolGraph.Symbol.Swift.Extension.self, from: """
                {"extendedModule": "MyKit",
                 "constraints": [
                    { "kind" : "sameType", "lhs" : "Self", "rhs" : "MyClass" }
                ]}
                """.data(using: .utf8)!)
                return symbol
            })
            try jsonEncoder.encode(graph).write(to: graphURL)
        }

        // Compile docs and verify contents
        let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/MyKit/MyClass/myFunction()", sourceLanguage: .swift))
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        let renderNode = translator.visitSymbol(symbol) as! RenderNode
        XCTAssertNil(renderNode.metadata.conformance)
    }

    func testPreservesNonRedundantConstraints() async throws {
        let (_, _, context) = try await testBundleAndContext(copying: "LegacyBundle_DoNotUseInNewTests", excludingPaths: []) { bundleURL in
            // Add constraints to `MyClass`
            let graphURL = bundleURL.appendingPathComponent("mykit-iOS.symbols.json")
            var graph = try jsonDecoder.decode(SymbolGraph.self, from: try Data(contentsOf: graphURL))
            
            // "Inject" generic constraints
            graph.symbols = try graph.symbols.mapValues({ symbol -> SymbolGraph.Symbol in
                guard symbol.identifier.precise == "s:5MyKit0A5ClassC10myFunctionyyF" else { return symbol }
                var symbol = symbol
                symbol.mixins[SymbolGraph.Symbol.Swift.Extension.mixinKey] = try jsonDecoder.decode(SymbolGraph.Symbol.Swift.Extension.self, from: """
                {"extendedModule": "MyKit",
                 "constraints": [
                    { "kind" : "sameType", "lhs" : "Self", "rhs" : "MyClass" },
                    { "kind" : "sameType", "lhs" : "Element", "rhs" : "MyClass" }
                ]}
                """.data(using: .utf8)!)
                return symbol
            })
            try jsonEncoder.encode(graph).write(to: graphURL)
        }

        // Compile docs and verify contents
        let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/MyKit/MyClass/myFunction()", sourceLanguage: .swift))
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        let renderNode = translator.visitSymbol(symbol) as! RenderNode
        XCTAssertEqual(renderNode.metadata.conformance?.constraints.map(flattenInlineElements).joined(), "Element is MyClass.")
    }

    func testGroups2Constraints() async throws {
        let (_, _, context) = try await testBundleAndContext(copying: "LegacyBundle_DoNotUseInNewTests", excludingPaths: []) { bundleURL in
            // Add constraints to `MyClass`
            let graphURL = bundleURL.appendingPathComponent("mykit-iOS.symbols.json")
            var graph = try jsonDecoder.decode(SymbolGraph.self, from: try Data(contentsOf: graphURL))
            
            // "Inject" generic constraints
            graph.symbols = try graph.symbols.mapValues({ symbol -> SymbolGraph.Symbol in
                guard symbol.identifier.precise == "s:5MyKit0A5ClassC10myFunctionyyF" else { return symbol }
                var symbol = symbol
                symbol.mixins[SymbolGraph.Symbol.Swift.Extension.mixinKey] = try jsonDecoder.decode(SymbolGraph.Symbol.Swift.Extension.self, from: """
                {"extendedModule": "MyKit",
                 "constraints": [
                    { "kind" : "conformance", "lhs" : "Element", "rhs" : "MyProtocol" },
                    { "kind" : "conformance", "lhs" : "Element", "rhs" : "Equatable" }
                ]}
                """.data(using: .utf8)!)
                return symbol
            })
            try jsonEncoder.encode(graph).write(to: graphURL)
        }

        // Compile docs and verify contents
        let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/MyKit/MyClass/myFunction()", sourceLanguage: .swift))
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        let renderNode = translator.visitSymbol(symbol) as! RenderNode
        XCTAssertEqual(renderNode.metadata.conformance?.constraints.map(flattenInlineElements).joined(), "Element conforms to MyProtocol and Equatable.")
    }

    func testGroups3Constraints() async throws {
        let (_, _, context) = try await testBundleAndContext(copying: "LegacyBundle_DoNotUseInNewTests", excludingPaths: []) { bundleURL in
            // Add constraints to `MyClass`
            let graphURL = bundleURL.appendingPathComponent("mykit-iOS.symbols.json")
            var graph = try jsonDecoder.decode(SymbolGraph.self, from: try Data(contentsOf: graphURL))
            
            // "Inject" generic constraints
            graph.symbols = try graph.symbols.mapValues({ symbol -> SymbolGraph.Symbol in
                guard symbol.identifier.precise == "s:5MyKit0A5ClassC10myFunctionyyF" else { return symbol }
                var symbol = symbol
                symbol.mixins[SymbolGraph.Symbol.Swift.Extension.mixinKey] = try jsonDecoder.decode(SymbolGraph.Symbol.Swift.Extension.self, from: """
                {"extendedModule": "MyKit",
                 "constraints": [
                    { "kind" : "conformance", "lhs" : "Element", "rhs" : "MyProtocol" },
                    { "kind" : "conformance", "lhs" : "Element", "rhs" : "Equatable" },
                    { "kind" : "conformance", "lhs" : "Element", "rhs" : "Hashable" }
                ]}
                """.data(using: .utf8)!)
                return symbol
            })
            try jsonEncoder.encode(graph).write(to: graphURL)
        }

        // Compile docs and verify contents
        let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/MyKit/MyClass/myFunction()", sourceLanguage: .swift))
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        let renderNode = translator.visitSymbol(symbol) as! RenderNode
        XCTAssertEqual(renderNode.metadata.conformance?.constraints.map(flattenInlineElements).joined(), "Element conforms to MyProtocol, Equatable, and Hashable.")
    }

    func testRenderReferences() async throws {
        let (_, _, context) = try await testBundleAndContext(copying: "LegacyBundle_DoNotUseInNewTests", excludingPaths: []) { bundleURL in
            // Add constraints to `MyClass`
            let graphURL = bundleURL.appendingPathComponent("mykit-iOS.symbols.json")
            var graph = try jsonDecoder.decode(SymbolGraph.self, from: try Data(contentsOf: graphURL))
            
            // "Inject" generic constraints
            graph.symbols = try graph.symbols.mapValues({ symbol -> SymbolGraph.Symbol in
                guard symbol.identifier.precise == "s:5MyKit0A5ClassC10myFunctionyyF" else { return symbol }
                var symbol = symbol
                symbol.mixins[SymbolGraph.Symbol.Swift.Extension.mixinKey] = try jsonDecoder.decode(SymbolGraph.Symbol.Swift.Extension.self, from: """
                {"extendedModule": "MyKit",
                 "constraints": [
                    { "kind" : "conformance", "lhs" : "Element", "rhs" : "MyProtocol" },
                    { "kind" : "conformance", "lhs" : "Element", "rhs" : "Equatable" }
                ]}
                """.data(using: .utf8)!)
                return symbol
            })
            try jsonEncoder.encode(graph).write(to: graphURL)
        }

        // Compile docs and verify contents
        let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/MyKit/MyClass", sourceLanguage: .swift))
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        let renderNode = translator.visitSymbol(symbol) as! RenderNode
        
        guard let renderReference = renderNode.references.first(where: { (key, value) -> Bool in
            return key.hasSuffix("myFunction()")
        })?.value as? TopicRenderReference else {
            XCTFail("Did not find render reference to myFunction()")
            return
        }
        
        XCTAssertEqual(renderReference.conformance?.constraints.map(flattenInlineElements).joined(), "Element conforms to MyProtocol and Equatable.")
    }

    func testRenderReferencesWithNestedTypeInSelf() async throws {
        let (_, _, context) = try await testBundleAndContext(copying: "LegacyBundle_DoNotUseInNewTests", excludingPaths: []) { bundleURL in
            // Add constraints to `MyClass`
            let graphURL = bundleURL.appendingPathComponent("mykit-iOS.symbols.json")
            var graph = try jsonDecoder.decode(SymbolGraph.self, from: try Data(contentsOf: graphURL))
            
            // "Inject" generic constraints
            graph.symbols = try graph.symbols.mapValues({ symbol -> SymbolGraph.Symbol in
                guard symbol.identifier.precise == "s:5MyKit0A5ClassC10myFunctionyyF" else { return symbol }
                var symbol = symbol
                symbol.mixins[SymbolGraph.Symbol.Swift.Extension.mixinKey] = try jsonDecoder.decode(SymbolGraph.Symbol.Swift.Extension.self, from: """
                {"extendedModule": "MyKit",
                 "constraints": [
                    { "kind" : "conformance", "lhs" : "Self.Element", "rhs" : "MyProtocol" },
                    { "kind" : "conformance", "lhs" : "Self.Index", "rhs" : "Equatable" }
                ]}
                """.data(using: .utf8)!)
                return symbol
            })
            try jsonEncoder.encode(graph).write(to: graphURL)
        }

        // Compile docs and verify contents
        let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/MyKit/MyClass", sourceLanguage: .swift))
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        let renderNode = translator.visitSymbol(symbol) as! RenderNode
        
        guard let renderReference = renderNode.references.first(where: { (key, value) -> Bool in
            return key.hasSuffix("myFunction()")
        })?.value as? TopicRenderReference else {
            XCTFail("Did not find render reference to myFunction()")
            return
        }
        
        // Verify we've removed the "Self." prefix in the type names
        XCTAssertEqual(renderReference.conformance?.constraints.map(flattenInlineElements).joined(), "Element conforms to MyProtocol and Index conforms to Equatable.")
    }

    func testRenderSameShape() async throws {
        let symbolGraphFile = Bundle.module.url(
            forResource: "SameShapeConstraint",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!

        let catalog = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "SameShapeConstraint", identifier: "com.test.example"),
            CopyOfFile(original: symbolGraphFile),
        ])

        let (_, context) = try await loadBundle(catalog: catalog)

        // Compile docs and verify contents
        let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/SameShapeConstraint/function(_:)", sourceLanguage: .swift))
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        let renderNode = translator.visitSymbol(symbol) as! RenderNode

        guard let renderReference = renderNode.references.first(where: { (key, value) -> Bool in
            return key.hasSuffix("function(_:)")
        })?.value as? TopicRenderReference else {
            XCTFail("Did not find render reference to function(_:)")
            return
        }

        // The symbol graph only defines constraints on the `swiftGenerics` mixin,
        // which docc doesn't load or render.
        // However, this test should still run without crashing on decoding the symbol graph.
        XCTAssertEqual(renderReference.conformance?.constraints.map(flattenInlineElements).joined(), nil)
    }
}

fileprivate func flattenInlineElements(el: RenderInlineContent) -> String {
    switch el {
    case .text(let text): return text
    case .codeVoice(let text): return text
    default: return ""
    }
}
