/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import DocCCommon
import Testing
import Foundation

struct SmallSourceLanguageSetTests {
    @Test
    func testBehavesSameAsSet() {
        var tiny = SmallSourceLanguageSet()
        var real = Set<SourceLanguage>()
        
        #expect(tiny.isEmpty == real.isEmpty)
        #expect(tiny.count   == real.count)
        #expect(tiny.min()   == real.min())
        #expect(tiny.first   == real.first)
        for language in SourceLanguage.knownLanguages {
            #expect(tiny.contains(language) == real.contains(language))
        }
        
        // Add known languages
        #expect(tiny.insert(.swift)       == real.insert(.swift))
        #expect(tiny.insert(.swift)       == real.insert(.swift))
        #expect(tiny.insert(.objectiveC)  == real.insert(.objectiveC))
        #expect(tiny.remove(.swift)       == real.remove(.swift))
        #expect(tiny.remove(.swift)       == real.remove(.swift))
        #expect(tiny.update(with: .swift) == real.update(with: .swift))
        
        #expect(tiny.update(with: .swift)      == real.update(with: .swift))
        #expect(tiny.update(with: .objectiveC) == real.update(with: .objectiveC))
        #expect(tiny.update(with: .data)       == real.update(with: .data))
        
        #expect(tiny.isEmpty == real.isEmpty)
        #expect(tiny.count   == real.count)
        #expect(tiny.min()   == real.min())
        for language in SourceLanguage.knownLanguages {
            #expect(tiny.contains(language) == real.contains(language))
        }
        
        // Add unknown languages
        for language in [
            SourceLanguage(name: "Custom"),
            SourceLanguage(name: "AAA", id: "zzz" /* will sort last */),
            SourceLanguage(name: "ZZZ", id: "aaa" /* will sort first (after Swift) */),
        ] {
            #expect(tiny.update(with: language) == real.update(with: language))
            #expect(tiny.contains(language)     == real.contains(language))
            #expect(tiny.remove(language)       == real.remove(language))
            #expect(tiny.remove(language)       == real.remove(language))
            #expect(tiny.contains(language)     == real.contains(language))
            #expect(tiny.insert(language)       == real.insert(language))
            #expect(tiny.contains(language)     == real.contains(language))
            #expect(tiny.update(with: language) == real.update(with: language))
            #expect(tiny.contains(language)     == real.contains(language))
        }
        
        #expect(tiny.isEmpty == real.isEmpty)
        #expect(tiny.count   == real.count)
        #expect(tiny.min()   == real.min())
        for language in SourceLanguage.knownLanguages {
            #expect(tiny.contains(language) == real.contains(language))
        }
        
        // Set operations
        #expect(real.intersection([]) == [])
        #expect(tiny.intersection([]) == [])
        #expect(real.union([]) == real)
        #expect(tiny.union([]) == tiny)
        #expect(real.symmetricDifference([]) == real)
        #expect(tiny.symmetricDifference([]) == tiny)
        
        #expect(    real.intersection(Set(                   SourceLanguage.knownLanguages))
             == Set(tiny.intersection(SmallSourceLanguageSet(SourceLanguage.knownLanguages)) ))
        #expect(    real.union(Set(                   SourceLanguage.knownLanguages))
             == Set(tiny.union(SmallSourceLanguageSet(SourceLanguage.knownLanguages)) ))
        #expect(    real.symmetricDifference(Set(                   SourceLanguage.knownLanguages))
             == Set(tiny.symmetricDifference(SmallSourceLanguageSet(SourceLanguage.knownLanguages)) ))
    }
    
    @Test
    func testSortsSwiftFirstAndThenByID() {
        var languages = SmallSourceLanguageSet(SourceLanguage.knownLanguages)
        #expect(languages.min()?.name == "Swift")
        #expect(languages.count == 5)
        #expect(languages.sorted().map(\.name) == [
            "Swift",       // swift (always first)
            "Data",        // data
            "JavaScript",  // javascript
            "Metal",       // metal
            "Objective-C", // occ
        ])
        
        for language in SourceLanguage.knownLanguages {
            #expect(languages.insert(language).inserted == false)
        }
        
        // Add unknown languages
        #expect(languages.insert(SourceLanguage(name: "Custom")).inserted == true)
        #expect(languages.insert(SourceLanguage(name: "AAA", id: "zzz" /* will sort last */)).inserted == true)
        #expect(languages.insert(SourceLanguage(name: "ZZZ", id: "aaa" /* will sort first (after Swift) */)).inserted == true)
        
        #expect(languages.min()?.name == "Swift")
        #expect(languages.count == 8)
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
        
        for language in SourceLanguage.knownLanguages {
            #expect(languages.remove(language) != nil)
            #expect(languages.remove(language) == nil)
        }
        
        #expect(languages.min()?.name == "ZZZ")
        #expect(languages.count == 3)
        #expect(languages.sorted().map(\.name) == [
            "ZZZ",         // aaa (the AAA/zzz and ZZZ/aaa languages have their names and ids flipped to verify that sorting happens by id)
            "Custom",      // custom
            "AAA",         // zzz (the AAA/zzz and ZZZ/aaa languages have their names and ids flipped to verify that sorting happens by id)
        ])
        
        languages.insert(.swift)
        
        #expect(languages.min()?.name == "Swift")
        #expect(languages.count == 4)
        #expect(languages.sorted().map(\.name) == [
            "Swift",       // swift (always first)
            "ZZZ",         // aaa (the AAA/zzz and ZZZ/aaa languages have their names and ids flipped to verify that sorting happens by id)
            "Custom",      // custom
            "AAA",         // zzz (the AAA/zzz and ZZZ/aaa languages have their names and ids flipped to verify that sorting happens by id)
        ])
    }
    
    @Test
    func testIsSameSizeAsUInt64() {
        #expect(MemoryLayout<SmallSourceLanguageSet>.size      == MemoryLayout<UInt64>.size)
        #expect(MemoryLayout<SmallSourceLanguageSet>.stride    == MemoryLayout<UInt64>.stride)
        #expect(MemoryLayout<SmallSourceLanguageSet>.alignment == MemoryLayout<UInt64>.alignment)
    }
}
