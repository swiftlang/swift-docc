/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

final class RenderIndexTests: XCTestCase {
    func testTestBundleRenderIndexGeneration() throws {
        let expectedIndexURL = try XCTUnwrap(
            Bundle.module.url(
                forResource: "TestBundle-RenderIndex",
                withExtension: "json",
                subdirectory: "Test Resources"
            )
        )
        
        try XCTAssertEqual(
            generatedRenderIndex(for: "TestBundle", with: "org.swift.docc.example"),
            RenderIndex.fromURL(expectedIndexURL)
        )
    }
    
    func testRenderIndexGenerationForBundleWithTechnologyRoot() throws {
        try XCTAssertEqual(
            generatedRenderIndex(for: "BundleWithTechnologyRoot", with: "org.swift.docc.example"),
            RenderIndex.fromString(#"""
                {
                  "interfaceLanguages": {
                    "swift": [
                      {
                        "title": "Articles",
                        "type": "groupMarker"
                      },
                      {
                        "path": "\/documentation\/technologyx\/article",
                        "title": "My Article",
                        "type": "article"
                      }
                    ]
                  },
                  "schemaVersion": {
                    "major": 0,
                    "minor": 1,
                    "patch": 0
                  }
                }
                """#
            )
            
        )
    }
    
    func testRenderIndexGenerationForMixedLanguageFramework() throws {
        enableFeatureFlag(\.isExperimentalObjectiveCSupportEnabled)
        
        XCTAssertEqual(
            try generatedRenderIndex(for: "MixedLanguageFramework", with: "org.swift.MixedLanguageFramework"),
            try RenderIndex.fromString(#"""
                {
                  "interfaceLanguages": {
                    "occ": [
                      {
                        "title": "Classes",
                        "type": "groupMarker"
                      },
                      {
                        "children": [
                          {
                            "title": "Type Methods",
                            "type": "groupMarker"
                          },
                          {
                            "children": [
                              {
                                "title": "Custom",
                                "type": "groupMarker"
                              },
                              {
                                "path": "\/documentation\/mixedlanguageframework\/foo-occ.typealias",
                                "title": "Foo",
                                "type": "typealias"
                              }
                            ],
                            "path": "\/documentation\/mixedlanguageframework\/bar\/mystringfunction(_:)",
                            "title": "typedef enum Foo : NSString {\n    ...\n} Foo;",
                            "type": "method"
                          }
                        ],
                        "path": "\/documentation\/mixedlanguageframework\/bar",
                        "title": "Bar",
                        "type": "class"
                      },
                      {
                        "title": "Variables",
                        "type": "groupMarker"
                      },
                      {
                        "path": "\/documentation\/mixedlanguageframework\/_mixedlanguageframeworkversionnumber",
                        "title": "_MixedLanguageFrameworkVersionNumber",
                        "type": "var"
                      },
                      {
                        "path": "\/documentation\/mixedlanguageframework\/_mixedlanguageframeworkversionstring",
                        "title": "_MixedLanguageFrameworkVersionString",
                        "type": "var"
                      },
                      {
                        "title": "Enumerations",
                        "type": "groupMarker"
                      },
                      {
                        "children": [
                          {
                            "title": "Enumeration Cases",
                            "type": "groupMarker"
                          },
                          {
                            "path": "\/documentation\/mixedlanguageframework\/foo-swift.struct\/first",
                            "title": "static var first: Foo",
                            "type": "case"
                          },
                          {
                            "path": "\/documentation\/mixedlanguageframework\/foo-swift.struct\/fourth",
                            "title": "static var fourth: Foo",
                            "type": "case"
                          },
                          {
                            "path": "\/documentation\/mixedlanguageframework\/foo-swift.struct\/second",
                            "title": "static var second: Foo",
                            "type": "case"
                          },
                          {
                            "path": "\/documentation\/mixedlanguageframework\/foo-swift.struct\/third",
                            "title": "static var third: Foo",
                            "type": "case"
                          }
                        ],
                        "path": "\/documentation\/mixedlanguageframework\/foo-swift.struct",
                        "title": "Foo",
                        "type": "enum"
                      }
                    ],
                    "swift": [
                      {
                        "title": "Classes",
                        "type": "groupMarker"
                      },
                      {
                        "children": [
                          {
                            "title": "Type Methods",
                            "type": "groupMarker"
                          },
                          {
                            "children": [
                              {
                                "title": "Custom",
                                "type": "groupMarker"
                              }
                            ],
                            "path": "\/documentation\/mixedlanguageframework\/bar\/mystringfunction(_:)",
                            "title": "class func myStringFunction(String) throws -> String",
                            "type": "method"
                          }
                        ],
                        "path": "\/documentation\/mixedlanguageframework\/bar",
                        "title": "Bar",
                        "type": "class"
                      },
                      {
                        "title": "Structures",
                        "type": "groupMarker"
                      },
                      {
                        "children": [
                          {
                            "title": "Initializers",
                            "type": "groupMarker"
                          },
                          {
                            "path": "\/documentation\/mixedlanguageframework\/foo-swift.struct\/init(rawvalue:)",
                            "title": "init(rawValue: UInt)",
                            "type": "init"
                          },
                          {
                            "title": "Type Properties",
                            "type": "groupMarker"
                          },
                          {
                            "path": "\/documentation\/mixedlanguageframework\/foo-swift.struct\/first",
                            "title": "static var first: Foo",
                            "type": "property"
                          },
                          {
                            "path": "\/documentation\/mixedlanguageframework\/foo-swift.struct\/fourth",
                            "title": "static var fourth: Foo",
                            "type": "property"
                          },
                          {
                            "path": "\/documentation\/mixedlanguageframework\/foo-swift.struct\/second",
                            "title": "static var second: Foo",
                            "type": "property"
                          },
                          {
                            "path": "\/documentation\/mixedlanguageframework\/foo-swift.struct\/third",
                            "title": "static var third: Foo",
                            "type": "property"
                          }
                        ],
                        "path": "\/documentation\/mixedlanguageframework\/foo-swift.struct",
                        "title": "Foo",
                        "type": "struct"
                      },
                      {
                        "children": [
                          {
                            "title": "Instance Methods",
                            "type": "groupMarker"
                          },
                          {
                            "path": "\/documentation\/mixedlanguageframework\/swiftonlystruct\/tada()",
                            "title": "func tada()",
                            "type": "method"
                          }
                        ],
                        "path": "\/documentation\/mixedlanguageframework\/swiftonlystruct",
                        "title": "SwiftOnlyStruct",
                        "type": "struct"
                      }
                    ]
                  },
                  "schemaVersion": {
                    "major": 0,
                    "minor": 1,
                    "patch": 0
                  }
                }
                """#
            )
        )
    }
    
    func generatedRenderIndex(for testBundleName: String, with bundleIdentifier: String) throws -> RenderIndex {
        let (bundle, context) = try testBundleAndContext(named: testBundleName)
        let renderContext = RenderContext(documentationContext: context, bundle: bundle)
        let converter = DocumentationContextConverter(bundle: bundle, context: context, renderContext: renderContext)
        let indexDirectory = try createTemporaryDirectory()
        let builder = NavigatorIndex.Builder(
            outputURL: indexDirectory,
            bundleIdentifier: bundleIdentifier,
            sortRootChildrenByName: true
        )

        builder.setup()
        
        for identifier in context.knownPages {
            let source = context.documentURL(for: identifier)
            let entity = try context.entity(with: identifier)
            let renderNode = try XCTUnwrap(converter.renderNode(for: entity, at: source))
            try builder.index(renderNode: renderNode)
        }
        
        builder.finalize(emitJSONRepresentation: true, emitLMDBRepresentation: false)
        
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(at: indexDirectory, includingPropertiesForKeys: nil).count,
            1,
            "More than one file was emitted while finalizing the index builder and only requesting the JSON representation."
        )
        
        return try RenderIndex.fromURL(indexDirectory.appendingPathComponent("index.json"))
    }
    
}

extension RenderIndex {
    static func fromString(_ string: String) throws -> RenderIndex {
        let decoder = JSONDecoder()
        return try decoder.decode(RenderIndex.self, from: Data(string.utf8))
    }
    
    static func fromURL(_ url: URL) throws -> RenderIndex {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(RenderIndex.self, from: data)
    }
}
