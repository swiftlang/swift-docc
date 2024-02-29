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
                    "patch": 1
                  }
                }
                """#
            )
            
        )
    }
    
    func testRenderIndexGenerationForMixedLanguageFramework() throws {
        let renderIndex = try generatedRenderIndex(for: "MixedLanguageFramework", with: "org.swift.MixedLanguageFramework")

        XCTAssertEqual(
            renderIndex,
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
                        "title": "Some Swift-only APIs, some Objective-C–only APIs, some mixed",
                        "type": "groupMarker"
                      },
                      {
                        "path": "\/documentation\/mixedlanguageframework\/_mixedlanguageframeworkversionstring",
                        "title": "_MixedLanguageFrameworkVersionString",
                        "type": "var"
                      },
                      {
                        "path": "/documentation/mixedlanguageframework/bar",
                        "title": "Bar",
                        "type": "class",
                        "children": [
                          {
                            "title": "Type Methods",
                            "type": "groupMarker"
                          },
                          {
                            "path": "/documentation/mixedlanguageframework/bar/mystringfunction(_:)",
                            "title": "myStringFunction:error: (navigator title)",
                            "type": "method",
                            "children": [
                              {
                                "title": "Custom",
                                "type": "groupMarker"
                              },
                              {
                                "title": "Foo",
                                "path": "/documentation/mixedlanguageframework/foo-c.typealias",
                                "type": "typealias"
                              }
                            ]
                          }
                        ]
                      },
                      {
                        "title": "Article",
                        "path": "/documentation/mixedlanguageframework/article",
                        "type": "article"
                      },
                      {
                        "title": "Tutorials",
                        "type": "groupMarker"
                      },
                      {
                        "path": "/tutorials/tutorialoverview",
                        "title": "MixedLanguageFramework Tutorials",
                        "type": "overview",
                        "children": [
                          {
                            "title": "Chapter",
                            "type": "groupMarker"
                          },
                          {
                            "title": "Tutorial",
                            "path": "/tutorials/mixedlanguageframework/tutorial",
                            "type": "project"
                          },
                          {
                            "title": "Tutorial Article",
                            "path": "/tutorials/mixedlanguageframework/tutorialarticle",
                            "type": "article"
                          }
                        ]
                      },
                      {
                        "title": "Tutorial Article",
                        "path": "/tutorials/mixedlanguageframework/tutorialarticle",
                        "type": "article"
                      },
                      {
                        "title": "Tutorial",
                        "path": "/tutorials/mixedlanguageframework/tutorial",
                        "type": "project"
                      },
                      {
                        "title": "Articles",
                        "type": "groupMarker"
                      },
                      {
                        "title": "Article",
                        "path": "/documentation/mixedlanguageframework/article",
                        "type": "article"
                      },
                      {
                        "title": "APICollection",
                        "path": "/documentation/mixedlanguageframework/apicollection",
                        "type": "symbol",
                        "children": [
                            {
                              "title": "Objective-C–only APIs",
                              "type": "groupMarker"
                            },
                            {
                              "title": "_MixedLanguageFrameworkVersionNumber",
                              "path": "/documentation/mixedlanguageframework/_mixedlanguageframeworkversionnumber",
                              "type": "var"
                            }
                        ]
                      },
                      {
                        "title": "Classes",
                        "type": "groupMarker"
                      },
                      {
                        "path": "/documentation/mixedlanguageframework/mixedlanguageclassconformingtoprotocol",
                        "title": "MixedLanguageClassConformingToProtocol",
                        "type": "class",
                        "children": [
                          {
                            "title": "Instance Methods",
                            "type": "groupMarker"
                          },
                          {
                            "title": "init",
                            "path": "/documentation/mixedlanguageframework/mixedlanguageclassconformingtoprotocol/init()",
                            "type": "method"
                          },
                          {
                            "title": "Default Implementations",
                            "type": "groupMarker"
                          },
                          {
                            "path": "/documentation/mixedlanguageframework/mixedlanguageclassconformingtoprotocol/mixedlanguageprotocol-implementations",
                            "title": "MixedLanguageProtocol Implementations",
                            "type": "symbol",
                            "children": [
                              {
                                "title": "Instance Methods",
                                "type": "groupMarker"
                              },
                              {
                                "title": "mixedLanguageMethod",
                                "path": "/documentation/mixedlanguageframework/mixedlanguageclassconformingtoprotocol/mixedlanguagemethod()",
                                "type": "method"
                              }
                            ]
                          }
                        ]
                      },
                      {
                        "title": "Protocols",
                        "type": "groupMarker"
                      },
                      {
                        "path": "/documentation/mixedlanguageframework/mixedlanguageprotocol",
                        "title": "MixedLanguageProtocol",
                        "type": "protocol",
                        "children": [
                          {
                            "title": "Instance Methods",
                            "type": "groupMarker"
                          },
                          {
                            "title": "mixedLanguageMethod",
                            "path": "/documentation/mixedlanguageframework/mixedlanguageprotocol/mixedlanguagemethod()",
                            "type": "method"
                          }
                        ]
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
                            "title": "Multi-language pages",
                            "type": "groupMarker"
                          },
                          {
                            "path": "\/documentation\/mixedlanguageframework\/articlecuratedinasinglelanguagepage",
                            "title": "Article curated in a single-language page",
                            "type": "article"
                          },
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
                        "title": "Some Swift-only APIs, some Objective-C–only APIs, some mixed",
                        "type": "groupMarker"
                      },
                      {
                        "title": "SwiftOnlyClass",
                        "path": "/documentation/mixedlanguageframework/swiftonlyclass",
                        "type": "class"
                      },
                      {
                        "path": "/documentation/mixedlanguageframework/bar",
                        "title": "Bar",
                        "type": "class",
                        "children": [
                          {
                            "title": "Type Methods",
                            "type": "groupMarker"
                          },
                          {
                            "title": "class func myStringFunction(String) throws -> String",
                            "path": "/documentation/mixedlanguageframework/bar/mystringfunction(_:)",
                            "type": "method"
                          }
                        ]
                      },
                      {
                        "title": "Article",
                        "path": "/documentation/mixedlanguageframework/article",
                        "type": "article"
                      },
                      {
                        "title": "Tutorials",
                        "type": "groupMarker"
                      },
                      {
                        "path": "/tutorials/tutorialoverview",
                        "title": "MixedLanguageFramework Tutorials",
                        "type": "overview",
                        "children": [
                          {
                            "title": "Chapter",
                            "type": "groupMarker"
                          },
                          {
                            "title": "Tutorial",
                            "path": "/tutorials/mixedlanguageframework/tutorial",
                            "type": "project"
                          },
                          {
                            "title": "Tutorial Article",
                            "path": "/tutorials/mixedlanguageframework/tutorialarticle",
                            "type": "article"
                          }
                        ]
                      },
                      {
                        "title": "Tutorial Article",
                        "path": "/tutorials/mixedlanguageframework/tutorialarticle",
                        "type": "article"
                      },
                      {
                        "title": "Tutorial",
                        "path": "/tutorials/mixedlanguageframework/tutorial",
                        "type": "project"
                      },
                      {
                        "title": "Articles",
                        "type": "groupMarker"
                      },
                      {
                        "title": "Article",
                        "path": "/documentation/mixedlanguageframework/article",
                        "type": "article"
                      },
                      {
                        "path": "/documentation/mixedlanguageframework/apicollection",
                        "title": "APICollection",
                        "type": "symbol",
                        "children": [
                          {
                            "title": "Swift-only APIs",
                            "type": "groupMarker"
                          },
                          {
                            "path": "/documentation/mixedlanguageframework/swiftonlystruct",
                            "title": "SwiftOnlyStruct",
                            "type": "struct",
                            "children": [
                              {
                                "title": "Multi-language pages",
                                "type": "groupMarker"
                              },
                              {
                                "path": "\/documentation\/mixedlanguageframework\/articlecuratedinasinglelanguagepage",
                                "title": "Article curated in a single-language page",
                                "type": "article"
                              },
                              {
                                "title": "Instance Methods",
                                "type": "groupMarker"
                              },
                              {
                                "title": "func tada()",
                                "path": "/documentation/mixedlanguageframework/swiftonlystruct/tada()",
                                "type": "method"
                              }
                            ]
                          }
                        ]
                      },
                      {
                        "title": "Classes",
                        "type": "groupMarker"
                      },
                      {
                        "path": "/documentation/mixedlanguageframework/mixedlanguageclassconformingtoprotocol",
                        "title": "MixedLanguageClassConformingToProtocol",
                        "type": "class",
                        "children": [
                          {
                            "title": "Initializers",
                            "type": "groupMarker"
                          },
                          {
                            "title": "init()",
                            "path": "/documentation/mixedlanguageframework/mixedlanguageclassconformingtoprotocol/init()",
                            "type": "init"
                          },
                          {
                            "title": "Default Implementations",
                            "type": "groupMarker"
                          },
                          {
                            "path": "/documentation/mixedlanguageframework/mixedlanguageclassconformingtoprotocol/mixedlanguageprotocol-implementations",
                            "title": "MixedLanguageProtocol Implementations",
                            "type": "symbol",
                            "children": [
                              {
                                "title": "Instance Methods",
                                "type": "groupMarker"
                              },
                              {
                                "title": "func mixedLanguageMethod()",
                                "path": "/documentation/mixedlanguageframework/mixedlanguageclassconformingtoprotocol/mixedlanguagemethod()",
                                "type": "method"
                              }
                            ]
                          }
                        ]
                      },
                      {
                        "title": "Protocols",
                        "type": "groupMarker"
                      },
                      {
                        "path": "/documentation/mixedlanguageframework/mixedlanguageprotocol",
                        "title": "MixedLanguageProtocol",
                        "type": "protocol",
                        "children": [
                          {
                            "title": "Instance Methods",
                            "type": "groupMarker"
                          },
                          {
                            "title": "func mixedLanguageMethod()",
                            "path": "/documentation/mixedlanguageframework/mixedlanguageprotocol/mixedlanguagemethod()",
                            "type": "method"
                          }
                        ]
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
                    "patch": 1
                  }
                }
                """#
            ),
            """
            Generated render index does not match expected index. Actual index was: \
            \(String(data: (try? JSONEncoder().encode(renderIndex)) ?? Data(), encoding: .utf8) ?? "")
            """
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
                    "patch": 1
                }
            }
            """#))
    }
    
    func testRenderIndexGenerationWithCustomIcon() throws {
        try XCTAssertEqual(
            generatedRenderIndex(for: "BookLikeContent", with: "org.swift.docc.Book"),
            RenderIndex.fromString(#"""
                {
                  "interfaceLanguages" : {
                    "swift" : [
                      {
                        "title" : "Articles",
                        "type" : "groupMarker"
                      },
                      {
                        "path" : "\/documentation\/bestbook\/myarticle",
                        "title" : "My Article",
                        "icon" : "plus.svg",
                        "type" : "article"
                      },
                      {
                        "path" : "\/documentation\/bestbook\/tabnavigatorarticle",
                        "title" : "Tab Navigator Article",
                        "type" : "article"
                      }
                    ]
                  },
                  "references" : {
                    "plus.svg" : {
                      "alt" : null,
                      "type" : "image",
                      "identifier" : "plus.svg",
                      "variants" : [
                        {
                          "url" : "\/images\/plus.svg",
                          "traits" : [
                            "1x",
                            "light"
                          ],
                          "svgID" : "plus-id"
                        }
                      ]
                    }
                  },
                  "schemaVersion" : {
                    "major" : 0,
                    "minor" : 1,
                    "patch" : 1
                  }
                }
                """#
            )
        )
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
