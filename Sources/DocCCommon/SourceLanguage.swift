/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A programming language, for example "Swift" or "Objective-C".
public struct SourceLanguage: Hashable, Codable, Comparable, Sendable {
    /// Using only an 8-bit value as an identifier technically limits a single DocC execution to 256 different languages.
    /// This may sound like a great limitation. However, in practice almost all content deals with either 1 or 2 languages.
    /// There is some known content with 3 languages but beyond that 4 or 5 or more languages is increasingly less common/realistic.
    ///
    /// Thus, in practice it's deemed unrealistic that any content would ever represent symbols from 256 different programming languages.
    /// Note that this limitation only applies to the languages within a single DocC execution and not globally.
    /// Two different DocC executions can each represent 200+ different languages, resulting in a total of 400+ languages together.
    ///
    /// When DocC works with programming languages it's very common to work with a set of languages.
    /// For example, a set can represent a page's list of supported language or it can represent a filter of common languages between to pages.
    /// Because each DocC execution only involves very few unique languages in practice,
    /// having a very small private identifier type allows DocC to pack all the languages it realistically needs into a small (inlineable) value.
    private var _id: UInt8
}

/// The private type that holds the information for each source language
private struct _SourceLanguageInformation: Equatable {
    var name: String
    var id: String
    var idAliases: [String] = []
    var linkDisambiguationID: String
    
    init(name: String, id: String, idAliases: [String] = [], linkDisambiguationID: String? = nil) {
        self.name = name
        self.id = id
        self.idAliases = idAliases
        self.linkDisambiguationID = linkDisambiguationID ?? id
    }
}

// MARK: Known Languages

private let _knownLanguages = [
    // NOTE: The known languages have identifiers that is also their sort order when there are no unknown languages
    
    // Swift
    _SourceLanguageInformation(name: "Swift", id: "swift"),
    
    // Miscellaneous data, that's not a programming language.
    _SourceLanguageInformation(name: "Data", id: "data"),
    
    // JavaScript or another language that conforms to the ECMAScript specification.
    _SourceLanguageInformation(name: "JavaScript", id: "javascript"),
    
    // The Metal programming language.
    _SourceLanguageInformation(name: "Metal", id: "metal"),
    
    // Objective-C, C, and C++
    _SourceLanguageInformation(
        name: "Objective-C",
        id: "occ",
        idAliases: [
            "objective-c",
            "objc",
            "c",   // FIXME: DocC should display C as its own language (https://github.com/swiftlang/swift-docc/issues/169).
            "c++", // FIXME: DocC should display C++ and Objective-C++ as their own languages (https://github.com/swiftlang/swift-docc/issues/767)
            "objective-c++",
            "objc++",
            "occ++",
        ],
        linkDisambiguationID: "c"
    ),
]

private extension SourceLanguage {
    private var _isKnownLanguage: Bool {
        Self._isKnownLanguageID(_id)
    }
    private static func _isKnownLanguageID(_ id: UInt8) -> Bool {
        id < _numberOfKnownLanguages
    }
    
    private static let _numberOfKnownLanguages = UInt8(_knownLanguages.count)
    private static let _maximumNumberOfUnknownLanguages: UInt8 = .max - _numberOfKnownLanguages
}

// Public accessors for known languages
public extension SourceLanguage {
    // NOTE: The known languages have identifiers that is also their sort order when there are no unknown languages
    
    /// The Swift programming language.
    static let swift = SourceLanguage(_id: 0)
    
    /// Miscellaneous data, that's not a programming language.
    ///
    /// For example, use this to represent JSON or XML content.
    static let data = SourceLanguage(_id: 1)
    /// The JavaScript programming language or another language that conforms to the ECMAScript specification.
    static let javaScript = SourceLanguage(_id: 2)
    /// The Metal programming language.
    static let metal = SourceLanguage(_id: 3)
    
    /// The Objective-C programming language.
    static let objectiveC = SourceLanguage(_id: 4)
    
    /// The list of programming languages that are known to DocC.
    static let knownLanguages: [SourceLanguage] = [.swift, .objectiveC, .javaScript, .data, .metal]
}

private let _unknownLanguages = Mutex([_SourceLanguageInformation]())

// MARK: Language properties

private extension SourceLanguage {
    private func _accessInfo() -> _SourceLanguageInformation {
        Self._accessInfo(id: _id)
    }
    
    private static func _accessInfo(id: UInt8) -> _SourceLanguageInformation {
        let (unknownIndex, isKnownLanguage) = id.subtractingReportingOverflow(SourceLanguage._numberOfKnownLanguages)
        return if isKnownLanguage {
            _knownLanguages[Int(id)]
        } else {
            _unknownLanguages.withLock { $0[Int(unknownIndex)] }
        }
    }
    
    private func _accessInfo(withUnlockedUnknownLanguages unknownLanguages: borrowing [_SourceLanguageInformation]) -> _SourceLanguageInformation {
        let (unknownIndex, isKnownLanguage) = _id.subtractingReportingOverflow(SourceLanguage._numberOfKnownLanguages)
        return if isKnownLanguage {
            _knownLanguages[Int(_id)]
        } else {
            unknownLanguages[Int(unknownIndex)]
        }
    }
    
    private mutating func _addOrFindExisting(unknownLanguage: _SourceLanguageInformation, withUnlockedUnknownLanguages unknownLanguages: inout [_SourceLanguageInformation]) {
        self._id = Self._addingOrFindingExisting(unknownLanguageInfo: unknownLanguage, withUnlockedUnknownLanguages: &unknownLanguages)
    }
    
    private static func _addingOrFindingExisting(unknownLanguageInfo: _SourceLanguageInformation, withUnlockedUnknownLanguages unknownLanguages: inout [_SourceLanguageInformation]) -> UInt8 {
        if let existingIndex = unknownLanguages.firstIndex(of: unknownLanguageInfo) {
            return _languageID(unknownLanguageIndex: existingIndex)
        } else {
            unknownLanguages.append(unknownLanguageInfo)
            return _languageID(unknownLanguageIndex: unknownLanguages.count - 1)
        }
    }
    
    private static func _languageID(unknownLanguageIndex: Int) -> UInt8 {
        precondition(unknownLanguageIndex < _maximumNumberOfUnknownLanguages, """
        Unexpectedly created more than 256 different programming languages in a single DocC execution. \
        This is considered highly unlikely in real content and is possibly caused by some programming bug that is frequently modifying existing source languages.
        """)
        return _numberOfKnownLanguages + UInt8(clamping: unknownLanguageIndex)
    }
}

// Public accessors for each language property
public extension SourceLanguage {
    /// The display name of the programming language.
    var name: String {
        get {  _accessInfo().name }
        @available(*, deprecated, message: "Create a new source language using 'init(name:id:idAliases:linkDisambiguationID:)' instead. This deprecated API will be removed after 6.4 is released.")
        set {
            // Modifying a language in any way create a new entry. This is generally discouraged because it easily creates a situation where language ID strings aren't globally unique anymore
            _unknownLanguages.withLock { unknownLanguages in
                var copy = _accessInfo(withUnlockedUnknownLanguages: unknownLanguages)
                copy.name = newValue
                _addOrFindExisting(unknownLanguage: copy, withUnlockedUnknownLanguages: &unknownLanguages)
            }
        }
    }
    /// A globally unique identifier for the language.
    var id: String {
        get {  _accessInfo().id }
        @available(*, deprecated, message: "Create a new source language using 'init(name:id:idAliases:linkDisambiguationID:)' instead. This deprecated API will be removed after 6.4 is released.")
        set {
            // Modifying a language in any way create a new entry. This is generally discouraged because it easily creates a situation where language ID strings aren't globally unique anymore
            _unknownLanguages.withLock { unknownLanguages in
                var copy = _accessInfo(withUnlockedUnknownLanguages: unknownLanguages)
                copy.id = newValue
                _addOrFindExisting(unknownLanguage: copy, withUnlockedUnknownLanguages: &unknownLanguages)
            }
        }
    }
    /// Aliases for the language's identifier.
    var idAliases: [String] {
        get {  _accessInfo().idAliases }
        @available(*, deprecated, message: "Create a new source language using 'init(name:id:idAliases:linkDisambiguationID:)' instead. This deprecated API will be removed after 6.4 is released.")
        set {
            // Modifying a language in any way create a new entry. This is generally discouraged because it easily creates a situation where language ID strings aren't globally unique anymore
            _unknownLanguages.withLock { unknownLanguages in
                var copy = _accessInfo(withUnlockedUnknownLanguages: unknownLanguages)
                copy.idAliases = newValue
                _addOrFindExisting(unknownLanguage: copy, withUnlockedUnknownLanguages: &unknownLanguages)
            }
        }
    }
    /// The identifier to use for link disambiguation purposes.
    var linkDisambiguationID: String {
        get {  _accessInfo().linkDisambiguationID }
        @available(*, deprecated, message: "Create a new source language using 'init(name:id:idAliases:linkDisambiguationID:)' instead. This deprecated API will be removed after 6.4 is released.")
        set {
            // Modifying a language in any way create a new entry. This is generally discouraged because it easily creates a situation where language ID strings aren't globally unique anymore
            _unknownLanguages.withLock { unknownLanguages in
                var copy = _accessInfo(withUnlockedUnknownLanguages: unknownLanguages)
                copy.linkDisambiguationID = newValue
                _addOrFindExisting(unknownLanguage: copy, withUnlockedUnknownLanguages: &unknownLanguages)
            }
        }
    }
}

// MARK: Creating languages

// Public initializers
public extension SourceLanguage {
    /// Creates a new language with a given name and identifier.
    /// - Parameters:
    ///   - name: The display name of the programming language.
    ///   - id: A globally unique identifier for the language.
    ///   - idAliases: Aliases for the language's identifier.
    ///   - linkDisambiguationID: The identifier to use for link disambiguation purposes.
    init(name: String, id: String, idAliases: [String] = [], linkDisambiguationID: String? = nil) {
        let newInfo = _SourceLanguageInformation(name: name, id: id, idAliases: idAliases, linkDisambiguationID: linkDisambiguationID)
        
        // Before creating a new language, check if there is one that matches all the information
        if let existing = Self._knownLanguage(withIdentifier: id), newInfo == Self._accessInfo(id: existing._id) {
            self = existing
            return
        }
        
        self._id = _unknownLanguages.withLock { unknownLanguages in
            Self._addingOrFindingExisting(
                unknownLanguageInfo: .init(name: name, id: id, idAliases: idAliases, linkDisambiguationID: linkDisambiguationID),
                withUnlockedUnknownLanguages: &unknownLanguages
            )
        }
    }
    
    /// Finds the programming language that matches a given identifier, or creates a new one if it finds no existing language.
    /// - Parameter id: The identifier of the programming language.
    init(id: String) {
        if let known = Self._knownLanguage(withIdentifier: id) {
            self = known
        } else {
            self._id = _unknownLanguages.withLock { unknownLanguages in
                Self._addingOrFindingExisting(unknownLanguageInfo: .init(name: id, id: id), withUnlockedUnknownLanguages: &unknownLanguages)
            }
        }
    }
    
    /// Finds the programming language that matches a given display name, or creates a new one if it finds no existing language.
    ///
    /// - Parameter name: The display name of the programming language.
    init(name: String) {
        let id = name.lowercased()
        if let knownLanguage = Self.knownLanguage(withName: name) ?? Self._knownLanguage(withIdentifier: id) {
            self = knownLanguage
        } else {
            self._id = _unknownLanguages.withLock { unknownLanguages in
                Self._addingOrFindingExisting(unknownLanguageInfo: .init(name: name, id: id), withUnlockedUnknownLanguages: &unknownLanguages)
            }
        }
    }
    
    /// Finds the programming language that matches a given display name.
    ///
    /// If the language name doesn't match any known language, this initializer returns `nil`.
    ///
    /// - Parameter knownLanguageName: The display name of the programming language.
    init?(knownLanguageName: String) {
        if let knownLanguage = Self.knownLanguage(withName: knownLanguageName) {
            self = knownLanguage
        } else {
            return nil
        }
    }
    
    /// Finds the programming language that matches a given identifier.
    ///
    /// If the language identifier doesn't match any known language, this initializer returns `nil`.
    ///
    /// - Parameter knownLanguageIdentifier: The identifier name of the programming language.
    init?(knownLanguageIdentifier: String) {
        if let knownLanguage = Self._knownLanguage(withIdentifier: knownLanguageIdentifier) {
            self = knownLanguage
        } else {
            return nil
        }
    }
    
    private static func knownLanguage(withName name: String) -> SourceLanguage? {
        switch name.lowercased() {
            case "swift":       .swift
            case "objective-c": .objectiveC
            case "javascript":  .javaScript
            case "data":        .data
            case "metal":       .metal
            default:            nil
        }
    }
    
    private static func _knownLanguage(withIdentifier id: String) -> SourceLanguage? {
        switch id.lowercased() {
            case "swift":      .swift
            case "occ", "objc", "objective-c",
                 "c", // FIXME: DocC should display C as its own language (https://github.com/swiftlang/swift-docc/issues/169).
                 "occ++", "objc++", "objective-c++", "c++": // FIXME: DocC should display C++ and Objective-C++ as their own languages (https://github.com/swiftlang/swift-docc/issues/767)
                                .objectiveC
            case "javascript":  .javaScript
            case "data":        .data
            case "metal":       .metal
            default:            nil
        }
    }
}

// MARK: Conformances

extension SourceLanguage {
    private enum CodingKeys: CodingKey {
        case name, id, idAliases, linkDisambiguationID
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let name = try container.decode(String.self, forKey: .name)
        let id = try container.decode(String.self, forKey: .id)
        let idAliases = try container.decodeIfPresent([String].self, forKey: .idAliases) ?? []
        let linkDisambiguationID = try container.decodeIfPresent(String.self, forKey: .linkDisambiguationID)
        
        self.init(name: name, id: id, idAliases: idAliases, linkDisambiguationID: linkDisambiguationID)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let info = _accessInfo()
        
        try container.encode(info.name, forKey: .name)
        try container.encode(info.id, forKey: .id)
        if !info.idAliases.isEmpty {
            try container.encode(info.idAliases, forKey: .idAliases)
        }
        try container.encode(info.linkDisambiguationID, forKey: .linkDisambiguationID)
    }
}

public extension SourceLanguage {
    static func == (lhs: SourceLanguage, rhs: SourceLanguage) -> Bool {
        lhs._id == rhs._id || lhs._accessInfo() == rhs._accessInfo()
    }
}

public extension SourceLanguage {
    static func < (lhs: SourceLanguage, rhs: SourceLanguage) -> Bool {
        // Sort Swift before other languages.
        if lhs == .swift {
            true
        } else if rhs == .swift {
            false
        }
        
        else if lhs._isKnownLanguage, rhs._isKnownLanguage {
            // If both languages are known, their `_id` is also their sort order
            lhs._id < rhs._id
        } else {
            // Otherwise, sort by ID (a string) for a stable order.
            lhs.id < rhs.id
        }
    }
}
