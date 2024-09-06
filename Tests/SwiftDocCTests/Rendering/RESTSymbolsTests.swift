/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC
import SwiftDocCTestUtilities
import SymbolKit

fileprivate extension [RenderBlockContent] {
    var firstParagraphText: String? {
        return first(where: { block in
            switch block {
            case .paragraph: return true
            default: return false
            }
        })
        .flatMap { block -> String? in
            switch block {
            case .paragraph(let p):
                switch p.inlineContent.first {
                case .some(.text(let string)): return string
                default: return nil
                }
            default: return nil
            }
        }
    }
}

class RESTSymbolsTests: XCTestCase {
    func testDecodeRESTSymbol() throws {
        let restSymbolURL = Bundle.module.url(
            forResource: "rest-symbol", withExtension: "json",
            subdirectory: "Rendering Fixtures")!
        
        let data = try Data(contentsOf: restSymbolURL)
        let symbol = try RenderNode.decode(fromJSON: data)
        
        //
        // REST Endpoint
        //
        
        guard let endpoint = symbol.primaryContentSections.first(where: { section -> Bool in
            section.kind == .restEndpoint
        }) as? RESTEndpointRenderSection else {
            XCTFail("REST endpoint section not decoded")
            return
        }
        
        XCTAssertEqual(endpoint.tokens.count, 5)
        guard endpoint.tokens.count == 5 else { return }

        XCTAssertEqual(endpoint.title, "URL")
        XCTAssertEqual(endpoint.tokens.map { $0.text }, ["GET", " ", "https://www.example.com", "/v1/me/library/artists/", "{id}"])
        
        //
        // REST Path Parameters
        //
        
        guard let parameters = symbol.primaryContentSections.first(where: { section -> Bool in
            section.kind == .restParameters && (section as? RESTParametersRenderSection)?.source == .path
        }) as? RESTParametersRenderSection else {
            XCTFail("REST parameters section not decoded")
            return
        }
        
        XCTAssertEqual(parameters.items.count, 1)
        
        guard parameters.items.count == 1 else { return }
        
        XCTAssertEqual(parameters.items[0].required, true)
        XCTAssertEqual(parameters.items[0].name, "id")
        XCTAssertEqual(parameters.items[0].type.first?.text, "string")
        
        XCTAssertEqual(parameters.items[0].typeDetails?.count, 2)
        guard parameters.items[0].typeDetails?.count == 2 else { return }
        
        XCTAssertNil(parameters.items[0].typeDetails?[0].arrayMode)
        XCTAssertNil(parameters.items[0].typeDetails?[0].baseType)
        XCTAssertEqual(parameters.items[0].typeDetails?[1].arrayMode, true)
        XCTAssertEqual(parameters.items[0].typeDetails?[1].baseType, "string")

        XCTAssertEqual(parameters.items[0].type.first?.text, "string")
        XCTAssertEqual(parameters.items[0].content?.firstParagraphText, "The unique identifier for the artist.")
        
        XCTAssertEqual(parameters.headings.joined(), parameters.items[0].name)
        XCTAssertEqual(parameters.rawIndexableTextContent(references: [:]), parameters.items[0].content?.firstParagraphText)
        
        //
        // REST Query Parameters
        //
        
        guard let query = symbol.primaryContentSections.first(where: { section -> Bool in
            section.kind == .restParameters && (section as? RESTParametersRenderSection)?.source == .query
        }) as? RESTParametersRenderSection else {
            XCTFail("REST parameters section not decoded")
            return
        }
        
        XCTAssertEqual(query.items.count, 2)
        
        guard query.items.count == 2 else { return }
        
        XCTAssertNil(query.items[0].required)
        XCTAssertEqual(query.items[0].name, "l")
        XCTAssertEqual(query.items[0].type.first?.text, "string")
        
        XCTAssertEqual(query.headings.first, query.items[0].name)

        //
        // REST Headers
        //
        guard let headers = symbol.primaryContentSections.first(where: { section -> Bool in
            section.kind == .restParameters && (section as? RESTParametersRenderSection)?.source == .header
        }) as? RESTParametersRenderSection else {
            XCTFail("REST headers section not decoded")
            return
        }
        
        XCTAssertEqual(headers.items.count, 1)
        
        guard headers.items.count == 1 else { return }
        
        XCTAssertEqual(headers.items[0].name, "X-TotalCount")
        XCTAssertEqual(headers.items[0].content?.firstParagraphText, "Total amount of results")
        
        XCTAssertEqual(headers.headings.joined(), headers.items[0].name)
        XCTAssertEqual(headers.rawIndexableTextContent(references: [:]), headers.items[0].content?.firstParagraphText)

        //
        // REST Responses
        //
        
        guard let responses = symbol.primaryContentSections.first(where: { section -> Bool in
            section.kind == .restResponses
        }) as? RESTResponseRenderSection else {
            XCTFail("REST responses section not decoded")
            return
        }
        
        XCTAssertEqual(responses.responses.count, 1)

        guard responses.responses.count == 1 else { return }

        XCTAssertEqual(responses.responses[0].status, 200)
        XCTAssertEqual(responses.responses[0].reason, "OK")
        XCTAssertEqual(responses.responses[0].mimeType, "application/json")
        XCTAssertEqual(responses.responses[0].type.first?.identifier, "doc://org.swift.docc/applemusicapi/libraryartistresponse")
        XCTAssertEqual(responses.responses[0].content?.firstParagraphText, "The request was successful.")

        XCTAssertEqual(responses.headings.joined(), responses.responses[0].reason)
        XCTAssertEqual(responses.rawIndexableTextContent(references: [:]), responses.responses[0].content?.firstParagraphText)
        
        // REST mulitpart Body
        
        guard let body = symbol.primaryContentSections.first(where: { section -> Bool in
            section.kind == .restBody
        }) as? RESTBodyRenderSection else {
            XCTFail("REST body section not decoded")
            return
        }

        XCTAssertEqual(body.title, "Parts")
        XCTAssertEqual(body.mimeType, "multipart/form-data")
        XCTAssertEqual(body.bodyContentType.first?.text, "form-data")
        XCTAssertEqual(body.content?.firstParagraphText, "The article’s Apple News Format JSON document and other assets.")
        
        XCTAssertEqual(body.parameters?.count, 1)
        guard body.parameters?.count == 1 else { return }

        XCTAssertEqual(body.parameters?[0].name, "Any Key")
        XCTAssertEqual(body.parameters?[0].type.first?.text, "binary")
        XCTAssertEqual(body.parameters?[0].required, true)
        XCTAssertEqual(body.parameters?[0].mimeType, "application/octet-stream")
        XCTAssertEqual(body.parameters?[0].content?.firstParagraphText, "Assets, such as images.")
        
        // REST endpoint example
        
        guard let discussion = symbol.primaryContentSections.first(where: { section -> Bool in
            section.kind == .content
        }) as? ContentRenderSection else {
            XCTFail("Discussion section not found")
            return
        }
        
        guard let example = discussion.content.first(where: { (block) -> Bool in
            if case RenderBlockContent.endpointExample = block {
                return true
            } else { return false }
        }) else {
            XCTFail("Failed to find rest example block")
            return
        }

        if case RenderBlockContent.endpointExample(let e) = example {
            XCTAssertNotNil(e.summary)
            if case RenderBlockContent.paragraph(let summary)? = e.summary?.first {
                XCTAssertEqual(summary.inlineContent, [RenderInlineContent.text("The summary of this endpoint example.")])
            } else {
                XCTFail("Summary paragraph not found.")
            }
            
            XCTAssertEqual(e.request.type, "file")
            XCTAssertEqual(e.request.syntax, "http")
            XCTAssertEqual(e.request.content.first?.collapsible, false)
            XCTAssertEqual(e.request.content.first?.code.joined(), "Request content")

            XCTAssertEqual(e.response.type, "file")
            XCTAssertEqual(e.response.syntax, "json")
            XCTAssertEqual(e.response.content.first?.collapsible, true)
            XCTAssertEqual(e.response.content.first?.code.joined(), "Response content")
        }
        
        AssertRoundtrip(for: symbol)
    }
    
    func testDecodeRESTObject() throws {
        let restObjectURL = Bundle.module.url(
            forResource: "rest-object", withExtension: "json",
            subdirectory: "Rendering Fixtures")!
        
        let data = try Data(contentsOf: restObjectURL)
        let object = try RenderNode.decode(fromJSON: data)
        
        //
        // REST Object
        //
        
        XCTAssertEqual(object.metadata.title, "Error")
        
        guard let properties = object.primaryContentSections.first(where: { section -> Bool in
            section.kind == .properties
        }) as? PropertiesRenderSection else {
            XCTFail("Properties section not decoded")
            return
        }
        
        XCTAssertEqual(properties.items.count, 2)
        guard properties.items.count == 2 else { return }
        
        // The first property is not deprecated/readonly but required
        XCTAssertNil(properties.items[0].deprecated)
        XCTAssertNil(properties.items[0].readOnly)
        XCTAssertEqual(properties.items[0].required, true)
        // The second property is deprecated/readonly but not required
        XCTAssertEqual(properties.items[1].deprecated, true)
        XCTAssertEqual(properties.items[1].readOnly, true)
        XCTAssertNil(properties.items[1].required)
        
        guard let attributes = properties.items[0].attributes else {
            XCTFail("Expected property attributes list not found")
            return
        }

        XCTAssertEqual(attributes.count, 7)
        guard attributes.count == 7 else { return }
        
        if case RenderAttribute.default(let value) = attributes[0] {
            XCTAssertEqual(value, "AABBCC")
        } else {
            XCTFail("Unexpected attribute")
        }
        
        if case RenderAttribute.minimum(let value) = attributes[1] {
            XCTAssertEqual(value, "0.0")
        } else {
            XCTFail("Unexpected attribute")
        }
        
        if case RenderAttribute.minimumExclusive(let value) = attributes[2] {
            XCTAssertEqual(value, "0.0")
        } else {
            XCTFail("Unexpected attribute")
        }
        
        if case RenderAttribute.maximum(let value) = attributes[3] {
            XCTAssertEqual(value, "10.0")
        } else {
            XCTFail("Unexpected attribute")
        }
                
        if case RenderAttribute.maximumExclusive(let value) = attributes[4] {
            XCTAssertEqual(value, "10.0")
        } else {
            XCTFail("Unexpected attribute")
        }
        
        if case RenderAttribute.allowedValues(let values) = attributes[5] {
            XCTAssertEqual(values, ["one", "two", "three"])
        } else {
            XCTFail("Unexpected attribute")
        }

        XCTAssertEqual(properties.items[0].name, "code")
        XCTAssertEqual(properties.items[0].type.first?.text, "*")
        XCTAssertEqual(properties.items[0].content?.firstParagraphText, "A code description")

        if case RenderAttribute.allowedTypes(let values) = attributes[6] {
            XCTAssertEqual(values.map({ $0.map({ $0.text }).joined() }), ["number", "[string]"])
        } else {
            XCTFail("Unexpected attribute")
        }
        
        AssertRoundtrip(for: object)
    }
    
    func testReferenceOfEntitlementWithKeyName() throws {
        
        func createDocumentationTopicRenderReferenceForSymbol(keyCustomName: String?) throws -> TopicRenderReference.PropertyListKeyNames {
            let exampleDocumentation = Folder(name: "unit-test.docc", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                    moduleName: "ModuleName",
                    symbols: [
                        SymbolGraph.Symbol(
                            identifier: .init(precise: "symbol-id", interfaceLanguage: "swift"),
                            names: .init(title: "Symbol Name", navigator: nil, subHeading: nil, prose: nil),
                            pathComponents: ["Symbol Name"],
                            docComment: nil,
                            accessLevel: .public,
                            kind: .init(parsedIdentifier: .typeProperty, displayName: "Type Property"),
                            mixins: [SymbolGraph.Symbol.PlistDetails.mixinKey:SymbolGraph.Symbol.PlistDetails(rawKey: "plist-key-symbolname", customTitle: keyCustomName)]
                        )
                    ]
                ))
            ])
            let (_, bundle, context) = try loadBundle(from: (try createTempFolder(content: [exampleDocumentation])))
            let moduleReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ModuleName", sourceLanguage: .swift)
            let moduleSymbol = try XCTUnwrap((try context.entity(with: moduleReference)).semantic as? Symbol)
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: moduleReference)
            let renderNode = translator.visit(moduleSymbol) as! RenderNode
            return try XCTUnwrap((renderNode.references["doc://unit-test/documentation/ModuleName/Symbol_Name"] as? TopicRenderReference)?.propertyListKeyNames)
        }
        
        // The symbol has a custom title.
        var propertyListKeyNames = try createDocumentationTopicRenderReferenceForSymbol(keyCustomName: "Symbol Custom Title")
        // Check that the reference contains the key symbol name.
        XCTAssertEqual(propertyListKeyNames.titleStyle, .useDisplayName)
        XCTAssertEqual(propertyListKeyNames.rawKey, "plist-key-symbolname")
        XCTAssertEqual(propertyListKeyNames.displayName, "Symbol Custom Title")
        
        // The symbol does not have a custom title.
        propertyListKeyNames = try createDocumentationTopicRenderReferenceForSymbol(keyCustomName: nil)
        // Check that the reference does not contain the key symbol name.
        XCTAssertEqual(propertyListKeyNames.titleStyle, .useRawKey)
        XCTAssertEqual(propertyListKeyNames.rawKey, "plist-key-symbolname")
        XCTAssertNil(propertyListKeyNames.displayName)
    }
    
    
}
