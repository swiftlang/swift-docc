/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class GeneratedCurationWriterTests: XCTestCase {
    func testWriteTopLevelSymbolCuration() throws {
        let (url, _, context) = try testBundleAndContext(copying: "MixedLanguageFrameworkWithLanguageRefinements")
        
        let writer = try XCTUnwrap(GeneratedCurationWriter(context: context, catalogURL: url, outputURL: url))
        let contentsToWrite = try writer.generateDefaultCurationContents(depthLimit: 0)
        
        XCTAssertEqual(contentsToWrite.count, 1, "Results is limited to only the module")
        
        XCTAssertEqual(contentsToWrite[url.appendingPathComponent("MixedFramework.md")], """
        # ``/MixedFramework``

        <!-- The content below this line is auto-generated and is redundant. You should either incorporate it into your content above this line or delete it. -->

        ## Topics

        ### Classes

        - ``CollisionsWithDifferentCapitalization``
        - ``CollisionsWithEscapedKeywords``
        - ``MyClass``
        - ``MyClassThatConformToMyOtherProtocol``
        - ``MyObjectiveCClassSwiftName``
        - ``MySwiftClassSwiftName``

        ### Protocols

        - ``MyObjectiveCCompatibleProtocol``
        - ``MyOtherProtocolThatConformToMySwiftProtocol``
        - ``MySwiftProtocol``

        ### Structures

        - ``MyObjectiveCOption``
        - ``MyStruct``
        - ``MyTypedObjectiveCEnum``
        - ``MyTypedObjectiveCExtensibleEnum``

        ### Variables

        - ``MixedFrameworkVersionNumber``
        - ``MixedFrameworkVersionString``
        - ``myTopLevelVariable``

        ### Functions

        - ``myTopLevelFunction()``

        ### Type Aliases

        - ``MyTypeAlias``

        ### Enumerations

        - ``CollisionsWithDifferentFunctionArguments``
        - ``CollisionsWithDifferentKinds``
        - ``CollisionsWithDifferentSubscriptArguments``
        - ``MyEnum``
        - ``MyObjectiveCEnum``
        - ``MyObjectiveCEnumSwiftName``
        """)
    }
    
    func testWriteSymbolCurationFromTopLevelSymbol() throws {
        let (url, _, context) = try testBundleAndContext(copying: "MixedLanguageFrameworkWithLanguageRefinements")
        
        let writer = try XCTUnwrap(GeneratedCurationWriter(context: context, catalogURL: url, outputURL: url))
        
        XCTAssertThrowsError(try writer.generateDefaultCurationContents(fromSymbol: "MyClas")) { error in
            XCTAssertEqual(error.localizedDescription, """
        '--from-symbol <symbol-link>' not found: 'MyClas' doesn't exist at '/MixedFramework'
        Replace 'MyClas' with 'MyClass'
        """)
        }
        
        let contentsToWrite = try writer.generateDefaultCurationContents(fromSymbol: "CollisionsWithDifferentCapitalization")
        
        XCTAssertEqual(contentsToWrite.count, 1, "Descendants don't have any curation to write.")
        
        XCTAssertEqual(contentsToWrite[url.appendingPathComponent("MixedFramework/CollisionsWithDifferentCapitalization.md")], """
        # ``/MixedFramework/CollisionsWithDifferentCapitalization``

        <!-- The content below this line is auto-generated and is redundant. You should either incorporate it into your content above this line or delete it. -->

        ## Topics

        ### Instance Properties

        - ``someThing``
        - ``something``
        """)
    }
    
    func testWriteSymbolCurationWithLimitedDepth() throws {
        let (url, _, context) = try testBundleAndContext(copying: "BundleWithSameNameForSymbolAndContainer")
        
        let writer = try XCTUnwrap(GeneratedCurationWriter(context: context, catalogURL: url, outputURL: url))
        let depthLevelsToTest = [nil, 0, 1, 2, 3, 4, 5]
        
        // From the module
        for depthLimit in depthLevelsToTest {
            let contentsToWrite = try writer.generateDefaultCurationContents(depthLimit: depthLimit)
            
            // In this test bundle there's one symbol per level and the target symbol is always included.
            let expectedFileCount = min(2, depthLimit ?? .max) + 1
            XCTAssertEqual(contentsToWrite.count, expectedFileCount)
            
            XCTAssertEqual(contentsToWrite[url.appendingPathComponent("SameNames.md")], """
            # ``/SameNames``

            <!-- The content below this line is auto-generated and is redundant. You should either incorporate it into your content above this line or delete it. -->

            ## Topics

            ### Structures

            - ``Something``
            """)
            
            if expectedFileCount > 1 {
                XCTAssertEqual(contentsToWrite[url.appendingPathComponent("SameNames/Something.md")], """
                # ``/SameNames/Something``
                
                <!-- The content below this line is auto-generated and is redundant. You should either incorporate it into your content above this line or delete it. -->
                
                ## Topics
                
                ### Structures
                
                - ``Something``
                
                ### Enumerations
                
                - ``SomethingElse``
                """)
            }
            
            if expectedFileCount > 2 {
                XCTAssertEqual(contentsToWrite[url.appendingPathComponent("SameNames/Something/Something.md")], """
                # ``/SameNames/Something/Something``
                
                <!-- The content below this line is auto-generated and is redundant. You should either incorporate it into your content above this line or delete it. -->
                
                ## Topics
                
                ### Enumerations
                
                - ``SomethingElse``
                """)
            }
        }
        
        // From a specific top-level symbol
        for depthLimit in depthLevelsToTest {
            let contentsToWrite = try writer.generateDefaultCurationContents(fromSymbol: "Something", depthLimit: depthLimit)
            
            // In this test bundle there's one symbol per level and the target symbol is always included.
            let expectedFileCount = min(1, depthLimit ?? .max) + 1
            XCTAssertEqual(contentsToWrite.count, expectedFileCount)
            
            XCTAssertEqual(contentsToWrite[url.appendingPathComponent("SameNames/Something.md")], """
            # ``/SameNames/Something``
            
            <!-- The content below this line is auto-generated and is redundant. You should either incorporate it into your content above this line or delete it. -->
            
            ## Topics
            
            ### Structures
            
            - ``Something``
            
            ### Enumerations
            
            - ``SomethingElse``
            """)
            
            if expectedFileCount > 1 {
                XCTAssertEqual(contentsToWrite[url.appendingPathComponent("SameNames/Something/Something.md")], """
                # ``/SameNames/Something/Something``
                
                <!-- The content below this line is auto-generated and is redundant. You should either incorporate it into your content above this line or delete it. -->
                
                ## Topics
                
                ### Enumerations
                
                - ``SomethingElse``
                """)
            }
        }
        
        // From a specific "leaf" symbol with no curation
        for depthLimit in depthLevelsToTest {
            let contentsToWrite = try writer.generateDefaultCurationContents(fromSymbol: "Something/Something/SomethingElse", depthLimit: depthLimit)
            
            XCTAssert(contentsToWrite.isEmpty, "The specified symbol has no curation to write")
        }
    }
    
    func testSkipsManuallyCuratedPages() throws {
        let (url, _, context) = try testBundleAndContext(copying: "MixedManualAutomaticCuration")
        
        let writer = try XCTUnwrap(GeneratedCurationWriter(context: context, catalogURL: url, outputURL: url))
        let contentsToWrite = try writer.generateDefaultCurationContents()
        
        XCTAssertFalse(contentsToWrite.isEmpty)
        
        // Manually curated pages are skipped in the automatic curation
        XCTAssertEqual(contentsToWrite[url.appendingPathComponent("TopClass.md")], """
        # ``TestBed/TopClass``

        ## Topics

        ### Basics

        - ``age``

        <!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->

        <!-- The content below this line is auto-generated and is redundant. You should either incorporate it into your content above this line or delete it. -->

        ## Topics

        ### Enumerations

        - ``NestedEnum``
        """)
    }
    
    func testAddsCommentForDisambiguatedLinks() throws {
        let (url, _, context) = try testBundleAndContext(copying: "OverloadedSymbols")
        
        let writer = try XCTUnwrap(GeneratedCurationWriter(context: context, catalogURL: url, outputURL: url))
        let contentsToWrite = try writer.generateDefaultCurationContents(fromSymbol: "OverloadedProtocol")
        
        XCTAssertEqual(contentsToWrite.count, 1, "Descendants don't have any curation to write.")
        
        // Manually curated pages are skipped in the automatic curation
        XCTAssertEqual(contentsToWrite[url.appendingPathComponent("ShapeKit/OverloadedProtocol.md")], """
        # ``/ShapeKit/OverloadedProtocol``

        <!-- The content below this line is auto-generated and is redundant. You should either incorporate it into your content above this line or delete it. -->

        ## Topics

        ### Instance Methods

        - ``fourthTestMemberName(test:)-1h173`` <!-- func fourthTestMemberName(test: String) -> Float -->
        - ``fourthTestMemberName(test:)-8iuz7`` <!-- func fourthTestMemberName(test: String) -> Double -->
        - ``fourthTestMemberName(test:)-91hxs`` <!-- func fourthTestMemberName(test: String) -> Int -->
        - ``fourthTestMemberName(test:)-961zx`` <!-- func fourthTestMemberName(test: String) -> String -->
        """)
    }
    
    func testLinksSupportNonPathCharacters() throws {
        let (url, _, context) = try testBundleAndContext(copying: "InheritedOperators")
        
        let writer = try XCTUnwrap(GeneratedCurationWriter(context: context, catalogURL: url, outputURL: url))
        let contentsToWrite = try writer.generateDefaultCurationContents(fromSymbol: "MyNumber")
        
        XCTAssertEqual(contentsToWrite.count, 1, "Descendants don't have any curation to write.")
        
        // Manually curated pages are skipped in the automatic curation
        XCTAssertEqual(contentsToWrite[url.appendingPathComponent("Operators/MyNumber.md")], """
        # ``/Operators/MyNumber``

        <!-- The content below this line is auto-generated and is redundant. You should either incorporate it into your content above this line or delete it. -->

        ## Topics

        ### Operators

        - ``*(_:_:)``
        - ``*=(_:_:)``
        - ``+(_:_:)``
        - ``-(_:_:)``
        - ``<(_:_:)``

        ### Initializers

        - ``init(exactly:)``
        - ``init(integerLiteral:)``

        ### Instance Properties

        - ``magnitude``
        """)
    }
    
    func testCustomOutputLocation() throws {
        let outputURL = URL(fileURLWithPath: "/path/to/somewhere") // Nothing is written to this path in this test
        
        let (url, _, context) = try testBundleAndContext(copying: "MixedLanguageFrameworkWithLanguageRefinements")
          
        let writer = try XCTUnwrap(GeneratedCurationWriter(context: context, catalogURL: url, outputURL: outputURL))
        let contentsToWrite = try writer.generateDefaultCurationContents()
        
        XCTAssertFalse(contentsToWrite.isEmpty)
        
        for fileURL in contentsToWrite.keys {
            XCTAssert(fileURL.path.hasPrefix(outputURL.path))
        }
    }
}
