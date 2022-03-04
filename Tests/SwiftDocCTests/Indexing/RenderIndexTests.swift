/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import SwiftDocCTestUtilities

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
                        "title": "Objective-C–only APIs",
                        "type": "groupMarker"
                      },
                      {
                        "path": "\/documentation\/mixedlanguageframework\/_mixedlanguageframeworkversionnumber",
                        "title": "_MixedLanguageFrameworkVersionNumber",
                        "type": "var"
                      },
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
                            "title": "myStringFunction:error: (navigator title)",
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
                            "title": "first",
                            "type": "case"
                          },
                          {
                            "path": "\/documentation\/mixedlanguageframework\/foo-swift.struct\/fourth",
                            "title": "fourth",
                            "type": "case"
                          },
                          {
                            "path": "\/documentation\/mixedlanguageframework\/foo-swift.struct\/second",
                            "title": "second",
                            "type": "case"
                          },
                          {
                            "path": "\/documentation\/mixedlanguageframework\/foo-swift.struct\/third",
                            "title": "third",
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
                        "title": "Swift-only APIs",
                        "type": "groupMarker"
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
                      },
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
    
    func testRenderIndexGenerationWithExternalNode() throws {
        try testRenderIndexGenerationFromJSON(
            makeRenderIndexJSONSingleNode(withOptionalProperty: "external")
        ) { renderIndex in
            // Let's check that the "external" key is correctly parsed into the isExternal field of RenderIndex.Node.
            XCTAssertTrue(try XCTUnwrap(renderIndex.interfaceLanguages["swift"])[0].isExternal)
        }
    }
    
    func testRenderIndexGenerationWithDeprecatedNode() throws {
        try testRenderIndexGenerationFromJSON(
            makeRenderIndexJSONSingleNode(withOptionalProperty: "deprecated")
        ) { renderIndex in
            // Let's check that the "deprecated" key is correctly parsed into the isDeprecated field of RenderIndex.Node.
            XCTAssertTrue(try XCTUnwrap(renderIndex.interfaceLanguages["swift"])[0].isDeprecated)
        }
    }
    
    func testRenderIndexGenerationWithBetaNode() throws {
        try testRenderIndexGenerationFromJSON(
            makeRenderIndexJSONSingleNode(withOptionalProperty: "beta")
        ) { renderIndex in
            // Let's check that the "deprecated" key is correctly parsed into the isDeprecated field of RenderIndex.Node.
            XCTAssertTrue(try XCTUnwrap(renderIndex.interfaceLanguages["swift"])[0].isBeta)
        }
    }
    
    func makeRenderIndexJSONSingleNode(withOptionalProperty property: String) -> String {
        return """
    {
      "interfaceLanguages": {
        "swift": [
          {
            "path": "/documentation/framework/foo-swift.struct",
            "title": "Foo",
            "type": "struct",
            "\(property)": true
          }
        ]
      },
      "schemaVersion": {
        "major": 0,
        "minor": 1,
        "patch": 0
      }
    }
"""
    }
    
    func testRenderIndexGenerationFromJSON(_ json: String, check: (RenderIndex) throws -> Void) throws {
        let renderIndexFromJSON = try RenderIndex.fromString(json)
        
        try check(renderIndexFromJSON)
        try assertRoundTripCoding(renderIndexFromJSON)
    }
    
    func testRenderIndexGenerationWithDeprecatedSymbol() throws {
        let swiftWithDeprecatedSymbolGraphFile = Bundle.module.url(
                forResource: "Deprecated",
                withExtension: "symbols.json",
                subdirectory: "Test Resources"
            )!

        let bundle = Folder(name: "unit-test-swift.docc", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            CopyOfFile(original: swiftWithDeprecatedSymbolGraphFile)
        ])

        // The navigator index needs to test with the real File Manager
        let testTemporaryDirectory = try createTemporaryDirectory()

        let bundleDirectory = testTemporaryDirectory.appendingPathComponent(
           bundle.name,
           isDirectory: true
        )
        try bundle.write(to: bundleDirectory)

        let (_, loadedBundle, context) = try loadBundle(from: bundleDirectory)

        XCTAssertEqual(
            try generatedRenderIndex(for: loadedBundle, withIdentifier: "com.test.example", withContext: context),
            try RenderIndex.fromString(#"""
            {
                "interfaceLanguages": {
                    "swift": [
                        {
                            "title": "Functions",
                            "type": "groupMarker"
                        },
                        {
                            "deprecated": true,
                            "path": "/documentation/mylibrary/foo()",
                            "title": "func foo() -> Int",
                            "type": "func"
                        }
                    ]
                },
                "schemaVersion": {
                    "major": 0,
                    "minor": 1,
                    "patch": 0
                }
            }
            """#))
    }
    
    func generatedRenderIndex(for testBundleName: String, with bundleIdentifier: String) throws -> RenderIndex {
        let (bundle, context) = try testBundleAndContext(named: testBundleName)
        return try generatedRenderIndex(for: bundle, withIdentifier: bundleIdentifier, withContext: context)
    }
    
    func generatedRenderIndex(for bundle: DocumentationBundle, withIdentifier bundleIdentifier: String, withContext context: DocumentationContext) throws -> RenderIndex {
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
