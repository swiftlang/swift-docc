/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A programming language.
public struct SourceLanguage: Hashable, Codable, Comparable {
    /// The display name of the programming language.
    public var name: String
    /// A globally unique identifier for the language.
    public var id: String
    /// Aliases for the language's identifier.
    public var idAliases: [String] = []
    /// The identifier to use for link disambiguation purposes.
    public var linkDisambiguationID: String

    /// Creates a new language with a given name and identifier.
    /// - Parameters:
    ///   - name: The display name of the programming language.
    ///   - id: A globally unique identifier for the language.
    ///   - idAliases: Aliases for the language's identifier.
    ///   - linkDisambiguationID: The identifier to use for link disambiguation purposes.
    public init(name: String, id: String, idAliases: [String] = [], linkDisambiguationID: String? = nil) {
        self.name = name
        self.id = id
        self.idAliases = idAliases
        self.linkDisambiguationID = linkDisambiguationID ?? id
    }

    /// Finds the programming language that matches a given identifier, or creates a new one if it finds no existing language.
    /// - Parameter id: The identifier of the programming language.
    public init(id: String) {
        switch id {
        case "swift": self = .swift
        case "occ", "objc", "objective-c", "c": self = .objectiveC
        // FIXME: DocC should display C++ and Objective-C++ as their own languages (https://github.com/swiftlang/swift-docc/issues/767)
        case "occ++", "objc++", "objective-c++", "c++": self = .objectiveC
        case "javascript": self = .javaScript
        case "data": self = .data
        case "metal": self = .metal
        default:
            self.name = id
            self.id = id
            self.linkDisambiguationID = id
        }
    }

    /// Finds the programming language that matches a given display name, or creates a new one if it finds no existing language.
    ///
    /// - Parameter name: The display name of the programming language.
    public init(name: String) {
        if let knownLanguage = SourceLanguage.firstKnownLanguage(withName: name) {
            self = knownLanguage
        } else {
            self.name = name
            
            let id = name.lowercased()
            self.id = id
            self.linkDisambiguationID = id
        }
    }
    
    /// Finds the programming language that matches a given display name.
    ///
    /// If the language name doesn't match any known language, this initializer returns `nil`.
    ///
    /// - Parameter knownLanguageName: The display name of the programming language.
    public init?(knownLanguageName: String) {
        if let knownLanguage = SourceLanguage.firstKnownLanguage(withName: knownLanguageName) {
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
    public init?(knownLanguageIdentifier: String) {
        if let knownLanguage = SourceLanguage.firstKnownLanguage(withIdentifier: knownLanguageIdentifier) {
            self = knownLanguage
        } else {
            return nil
        }
    }

    private static func firstKnownLanguage(withName name: String) -> SourceLanguage? {
        SourceLanguage.knownLanguages.first { $0.name.lowercased() == name.lowercased() }
    }
    
    private static func firstKnownLanguage(withIdentifier id: String) -> SourceLanguage? {
        SourceLanguage.knownLanguages.first { knownLanguage in
            ([knownLanguage.id] + knownLanguage.idAliases)
                .map { $0.lowercased() }
                .contains(id)
        }
    }
    
    /// The Swift programming language.
    public static let swift = SourceLanguage(name: "Swift", id: "swift")

    /// The Objective-C programming language.
    public static let objectiveC = SourceLanguage(
        name: "Objective-C",
        id: "occ",
        idAliases: [
            "objective-c",
            "objc",
            "c", // FIXME: DocC should display C as its own language (github.com/swiftlang/swift-docc/issues/169).
            "c++", // FIXME: DocC should display C++ and Objective-C++ as their own languages (https://github.com/swiftlang/swift-docc/issues/767)
            "objective-c++",
            "objc++",
            "occ++",
        ],
        linkDisambiguationID: "c"
    )

    /// The JavaScript programming language or another language that conforms to the ECMAScript specification.
    public static let javaScript = SourceLanguage(name: "JavaScript", id: "javascript")
    /// Miscellaneous data, that's not a programming language.
    ///
    /// For example, use this to represent JSON or XML content.
    public static let data = SourceLanguage(name: "Data", id: "data")
    /// The Metal programming language.
    public static let metal = SourceLanguage(name: "Metal", id: "metal")
    
    /// The list of programming languages that are known to DocC.
    public static var knownLanguages: [SourceLanguage] = [.swift, .objectiveC, .javaScript, .data, .metal]
    
    enum CodingKeys: CodingKey {
        case name
        case id
        case idAliases
        case linkDisambiguationID
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: SourceLanguage.CodingKeys.self)
        
        let name = try container.decode(String.self, forKey: SourceLanguage.CodingKeys.name)
        let id = try container.decode(String.self, forKey: SourceLanguage.CodingKeys.id)
        let idAliases = try container.decodeIfPresent([String].self, forKey: SourceLanguage.CodingKeys.idAliases) ?? []
        let linkDisambiguationID = try container.decodeIfPresent(String.self, forKey: SourceLanguage.CodingKeys.linkDisambiguationID)
        
        self.init(name: name, id: id, idAliases: idAliases, linkDisambiguationID: linkDisambiguationID)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: SourceLanguage.CodingKeys.self)
        
        try container.encode(self.name, forKey: SourceLanguage.CodingKeys.name)
        try container.encode(self.id, forKey: SourceLanguage.CodingKeys.id)
        try container.encodeIfNotEmpty(self.idAliases, forKey: SourceLanguage.CodingKeys.idAliases)
        try container.encode(self.linkDisambiguationID, forKey: SourceLanguage.CodingKeys.linkDisambiguationID)
    }
    
    public static func < (lhs: SourceLanguage, rhs: SourceLanguage) -> Bool {
        // Sort Swift before other languages.
        if lhs == .swift {
            return true
        } else if rhs == .swift {
            return false
        }
        // Otherwise, sort by ID for a stable order.
        return lhs.id < rhs.id
    }
}
