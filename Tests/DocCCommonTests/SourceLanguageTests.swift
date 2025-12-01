/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import DocCCommon
import Testing
import Foundation

struct SourceLanguageTests {
    @Test(arguments: SourceLanguage.knownLanguages)
    func testUsesIDAliasesWhenQueryingFirstKnownLanguage(_ language: SourceLanguage) {
        #expect(SourceLanguage(id: language.id) == language)
        for alias in language.idAliases {
            #expect(SourceLanguage(id: alias) == language, "Unexpectedly found different language for id alias '\(alias)'")
        }
    }
    
    // This test uses mutating SourceLanguage properties which is deprecated.
    // Deprecating the test silences the deprecation warning when running the tests. It doesn't skip the test.
    @available(*, deprecated)
    @Test
    func testHasValueSemanticsForBothKnownAndUnknownLanguages() throws {
        var original = SourceLanguage.swift
        var copy = original
        copy.name = "First"
        #expect(copy.name == "First", "The copy has a modified value")
        #expect(original.name == "Swift", "Modifying one value doesn't change the original")
        
        try assertRoundTripCoding(original)
        try assertRoundTripCoding(copy)
        
        original = .init(name: "Custom", id: "custom")
        copy = original
        copy.name = "Second"
        #expect(copy.name == "Second", "The copy has a modified value")
        #expect(original.name == "Custom", "Modifying one value doesn't change the original")
        
        try assertRoundTripCoding(original)
        try assertRoundTripCoding(copy)
    }
    
    @Test
    func testReusesExistingValuesWhenCreatingLanguages() throws {
        // Creating more than 256 languages would fail if SourceLanguage initializer didn't reuse existing values
        let numberOfIterations = 300 // anything more than `UInt8.max`
        
        for _ in 0...numberOfIterations {
            let knownLanguageByID = SourceLanguage(id: "swift")
            try assertRoundTripCoding(knownLanguageByID)
            #expect(knownLanguageByID.id == "swift")
        }
        
        for _ in 0...numberOfIterations {
            let knownLanguageWithAllInfo = SourceLanguage(name: "Swift", id: "swift", idAliases: [], linkDisambiguationID: nil)
            try assertRoundTripCoding(knownLanguageWithAllInfo)
            #expect(knownLanguageWithAllInfo.id == "swift")
        }
        
        for _ in 0...numberOfIterations {
            let knownLanguageByName = SourceLanguage(name: "Swift")
            try assertRoundTripCoding(knownLanguageByName)
            #expect(knownLanguageByName.id == "swift")
        }
        
        for _ in 0...numberOfIterations {
            let unknownLanguage = SourceLanguage(name: "Custom")
            try assertRoundTripCoding(unknownLanguage)
            #expect(unknownLanguage.id == "custom")
        }
        
        for _ in 0...numberOfIterations {
            let unknownLanguageWithAllInfo = SourceLanguage(name: "Custom", id: "custom", idAliases: ["other", "preferred"], linkDisambiguationID: "preferred")
            try assertRoundTripCoding(unknownLanguageWithAllInfo)
            #expect(unknownLanguageWithAllInfo.name == "Custom")
            #expect(unknownLanguageWithAllInfo.id == "custom")
            #expect(unknownLanguageWithAllInfo.idAliases == ["other", "preferred"])
            #expect(unknownLanguageWithAllInfo.linkDisambiguationID == "preferred")
        }
    }
    
    // This test uses mutating SourceLanguage properties which is deprecated.
    // Deprecating the test silences the deprecation warning when running the tests. It doesn't skip the test.
    @available(*, deprecated)
    @Test
    func testReusesExistingValuesModifyingProperties() {
        // Creating more than 256 languages would fail if SourceLanguage initializer didn't reuse existing values
        let numberOfIterations = 300 // anything more than `UInt8.max`
        
        var language = SourceLanguage.swift
        for iteration in 0...numberOfIterations {
            language.name = iteration.isMultiple(of: 2) ? "Even" : "Odd"
        }
    }
    
    @Test(arguments: [
        (SourceLanguage.swift,      "Swift"),
        (SourceLanguage.objectiveC, "Objective-C"),
        (SourceLanguage.data,       "Data"),
        (SourceLanguage.javaScript, "JavaScript"),
        (SourceLanguage.metal,      "Metal"),
    ])
    func testNameOfKnownLanguage(language: SourceLanguage, matches expectedName: String) {
        // Known languages have their own dedicated implementation that requires two implementation detail values to be consistent.
        #expect(language.name == expectedName)
    }
    
    @Test
    func testSortsSwiftFirstAndThenByID() throws {
        var languages = SourceLanguage.knownLanguages
        #expect(languages.min()?.name == "Swift")
        #expect(languages.sorted().map(\.name) == [
            "Swift",       // swift (always first)
            "Data",        // data
            "JavaScript",  // javascript
            "Metal",       // metal
            "Objective-C", // occ
        ])
        
        languages.append(contentsOf: [
            SourceLanguage(name: "Custom"),
            SourceLanguage(name: "AAA", id: "zzz"), // will sort last
            SourceLanguage(name: "ZZZ", id: "aaa"), // will sort first (after Swift)
        ])
        #expect(languages.min()?.name == "Swift")
        #expect(languages.sorted().map(\.name) == [
            "Swift",       // swift (always first)
            "ZZZ",         // aaa (the AAA/zzz and ZZZ/aaa languages have their names and ids flipped to verify that sorting happens by id)
            "Custom",      // custom
            "Data",        // data
            "JavaScript",  // javascript
            "Metal",       // metal
            "Objective-C", // occ
            "AAA",         // zzz (the AAA/zzz and ZZZ/aaa languages have their names and ids flipped to verify that sorting happens by id)
        ])
    }
    
    private func assertRoundTripCoding(_ original: SourceLanguage, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SourceLanguage.self, from: encoded)
        // Check that both values are equal
        #expect(original == decoded, sourceLocation: sourceLocation)
        
        // Also check that all their properties are equal
        #expect(original.id == decoded.id, sourceLocation: sourceLocation)
        #expect(original.name == decoded.name, sourceLocation: sourceLocation)
        #expect(original.idAliases == decoded.idAliases, sourceLocation: sourceLocation)
        #expect(original.linkDisambiguationID == decoded.linkDisambiguationID, sourceLocation: sourceLocation)
    }
}
