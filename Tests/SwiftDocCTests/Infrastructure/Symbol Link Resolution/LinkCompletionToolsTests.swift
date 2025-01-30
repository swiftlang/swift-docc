/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@_spi(LinkCompletion) @testable import SwiftDocC

class LinkCompletionToolsTests: XCTestCase {
    func testParsingLinkStrings() {
        func assertParsing(
            _ linkString: String,
            equal expected: [(name: String, disambiguation: LinkCompletionTools.ParsedDisambiguation)],
            file: StaticString = #file,
            line: UInt = #line
        ) {
            let got = LinkCompletionTools.parse(linkString: linkString)
            XCTAssertEqual(got.count, expected.count, "Incorrect number of link components", file: file, line: line)
            for (index, (got, expected)) in zip(got, expected).enumerated() {
                XCTAssertEqual(got.name, expected.name, "Incorrect base name for link component #\(index)", file: file, line: line)
                XCTAssertEqual(got.disambiguation, expected.disambiguation, "Incorrect disambiguation for link component #\(index)", file: file, line: line)
            }
        }
        
        assertParsing("", equal: [])
        
        assertParsing("SomeClass", equal: [
            ("SomeClass", .none),
        ])
        // The leading slash indicate an absolute symbol link
        assertParsing("/SomeModule", equal: [
            ("SomeModule", .none),
        ])
        // Trailing slash
        assertParsing("SomeClass/", equal: [
            ("SomeClass", .none),
        ])
        
        // Disambiguation
        assertParsing("SomeClass-class", equal: [
            ("SomeClass", .kindAndOrHash(kind: "class", hash: nil)),
        ])
        assertParsing("SomeClass-swift.class", equal: [
            ("SomeClass", .kindAndOrHash(kind: "class", hash: nil)),
        ])
        assertParsing("SomeClass-p2kr1", equal: [
            ("SomeClass", .kindAndOrHash(kind: nil, hash: "p2kr1")),
        ])
        
        // Slash in symbol names
        assertParsing("Something//=(_:_:)", equal: [
            ("Something", .none),
            ("/=(_:_:)", .none),
        ])
        assertParsing("Something/operator/=", equal: [
            ("Something", .none),
            ("operator/=", .none),
        ])
        
        // Type signature disambiguation
        assertParsing("doSomething(with:and:)->()", equal: [
            ("doSomething(with:and:)", .typeSignature(parameterTypes: nil, returnTypes: [])),
        ])
        assertParsing("doSomething(with:and:)->_", equal: [
            ("doSomething(with:and:)", .typeSignature(parameterTypes: nil, returnTypes: ["_"])),
        ])
        assertParsing("doSomething(with:and:)->Bool", equal: [
            ("doSomething(with:and:)", .typeSignature(parameterTypes: nil, returnTypes: ["Bool"])),
        ])
        assertParsing("doSomething(with:and:)->(Int,_,Double)", equal: [
            ("doSomething(with:and:)", .typeSignature(parameterTypes: nil, returnTypes: ["Int", "_", "Double"])),
        ])
        assertParsing("doSomething(with:and:)-(_,_)", equal: [
            ("doSomething(with:and:)", .typeSignature(parameterTypes: ["_", "_"], returnTypes: nil)),
        ])
        assertParsing("doSomething(with:and:)-(String,_)", equal: [
            ("doSomething(with:and:)", .typeSignature(parameterTypes: ["String", "_"], returnTypes: nil)),
        ])
        assertParsing("doSomething()-()", equal: [
            ("doSomething()", .typeSignature(parameterTypes: [], returnTypes: nil)),
        ])
        assertParsing("doSomething(with:and:)-(String,_)->Bool", equal: [
            ("doSomething(with:and:)", .typeSignature(parameterTypes: ["String", "_"], returnTypes: ["Bool"])),
        ])
    }
    
    func testFilteringSymbols() {
        let symbol = LinkCompletionTools.SymbolInformation(kind: "func.op", symbolIDHash: "vt1x", parameterTypes: ["Int", "String"], returnTypes: ["Bool"])
        
        XCTAssert(symbol.matches(.none))
        XCTAssert(symbol.matches(.kindAndOrHash(kind: "func.op", hash: nil)))
        XCTAssert(symbol.matches(.kindAndOrHash(kind: nil, hash: "vt1x")))
        XCTAssert(symbol.matches(.kindAndOrHash(kind: "func.op", hash: "vt1x")))
        XCTAssert(symbol.matches(.typeSignature(parameterTypes: ["_", "_"], returnTypes: ["_"])))
        XCTAssert(symbol.matches(.typeSignature(parameterTypes: ["_", "_"], returnTypes: ["Bool"])))
        XCTAssert(symbol.matches(.typeSignature(parameterTypes: ["Int", "_"], returnTypes: ["_"])))
        XCTAssert(symbol.matches(.typeSignature(parameterTypes: ["_", "String"], returnTypes: ["_"])))
        XCTAssert(symbol.matches(.typeSignature(parameterTypes: ["Int", "String"], returnTypes: ["_"])))
        XCTAssert(symbol.matches(.typeSignature(parameterTypes: ["Int", "String"], returnTypes: ["Bool"])))
        
        XCTAssertFalse(symbol.matches(.kindAndOrHash(kind: "method", hash: nil)))
        XCTAssertFalse(symbol.matches(.kindAndOrHash(kind: nil, hash: "pfi6")))
        XCTAssertFalse(symbol.matches(.typeSignature(parameterTypes: [], returnTypes: [])))
        XCTAssertFalse(symbol.matches(.typeSignature(parameterTypes: ["_"], returnTypes: ["_"])))
        XCTAssertFalse(symbol.matches(.typeSignature(parameterTypes: ["_"], returnTypes: ["_", "_"])))
        XCTAssertFalse(symbol.matches(.typeSignature(parameterTypes: ["Bool", "_"], returnTypes: ["_"])))
        XCTAssertFalse(symbol.matches(.typeSignature(parameterTypes: ["_", "Bool"], returnTypes: ["_"])))
        XCTAssertFalse(symbol.matches(.typeSignature(parameterTypes: ["_", "_"], returnTypes: ["Int"])))
        XCTAssertFalse(symbol.matches(.typeSignature(parameterTypes: ["String", "Int"], returnTypes: ["Bool"])))
    }
    
    func testUSRHashing() {
        for id in ["some", "unique", "symbol", "identifiers"] {
            XCTAssertEqual(LinkCompletionTools.SymbolInformation.hash(uniqueSymbolID: id), id.stableHashString)
        }
    }
    
    func testSuggestDisambiguation() {
        let enumCase = LinkCompletionTools.SymbolInformation(kind: "enum.case", symbolIDHash: "lhk2x", parameterTypes: nil, returnTypes: nil)
        let property = LinkCompletionTools.SymbolInformation(kind: "property", symbolIDHash: "j56x", parameterTypes: nil, returnTypes: nil)
        
        XCTAssertEqual(LinkCompletionTools.suggestedDisambiguation(forCollidingSymbols: [enumCase]), [""])
        XCTAssertEqual(LinkCompletionTools.suggestedDisambiguation(forCollidingSymbols: [property]), [""])
        
        XCTAssertEqual(LinkCompletionTools.suggestedDisambiguation(forCollidingSymbols: [
            enumCase, property
        ]), [
            "-enum.case", "-property"
        ])
        
        let operator1 = LinkCompletionTools.SymbolInformation(kind: "func.op", symbolIDHash: "vt1x", parameterTypes: ["Int", "String"], returnTypes: ["Bool"])
        let operator2 = LinkCompletionTools.SymbolInformation(kind: "func.op", symbolIDHash: "pfi6", parameterTypes: ["Wrapped", "Wrapped"], returnTypes: ["Wrapped"])
        let method = LinkCompletionTools.SymbolInformation(kind: "method", symbolIDHash: "w7ti9", parameterTypes: ["Int", "String"], returnTypes: [])
        
        XCTAssertEqual(LinkCompletionTools.suggestedDisambiguation(forCollidingSymbols: [
            operator1, operator2, method,
        ]), [
            "->Bool", "->Wrapped", "-method",
        ])
        
        var operator3 = operator1
        operator3.symbolIDHash = "da50"
        
        XCTAssertEqual(LinkCompletionTools.suggestedDisambiguation(forCollidingSymbols: [
            operator1, operator2, operator3,
        ]), [
            "-vt1x", "->Wrapped", "-da50",
        ])
        
        operator3.parameterTypes = ["Int", "Double"]
        
        XCTAssertEqual(LinkCompletionTools.suggestedDisambiguation(forCollidingSymbols: [
            operator1, operator2, operator3,
        ]), [
            "-(_,String)", "->Wrapped", "-(_,Double)",
        ])
    }
    
    func testSuggestingBothParameterAndReturnTypesInTheSameDisambiguation() {
        let overloads = [
            (parameters: ["Int"],  returns: []),      // (Int)  -> Void
            (parameters: ["Bool"], returns: []),      // (Bool) -> Void
            (parameters: ["Int"],  returns: ["Int"]), // (Int)  -> Int
        ].map {
            LinkCompletionTools.SymbolInformation(
                kind: "func",
                symbolIDHash: "\($0)".stableHashString,
                parameterTypes: $0.parameters,
                returnTypes: $0.returns
            )
        }
        
        XCTAssertEqual(LinkCompletionTools.suggestedDisambiguation(forCollidingSymbols: overloads), [
            "-(Int)->()", // Only parameter type would be ambiguous with 3rd overload & only return type would be ambiguous with 2nd overload.
            "-(Bool)",    // The only overload with a `Bool` value
            "->_",        // The only overload that returns something
        ])
    }
}
