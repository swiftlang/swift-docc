/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A programming language.
public struct SourceLanguage: Hashable, Codable {
    /// The display name of the programming language.
    public var name: String
    /// A globally unique identifier for the language.
    public var id: String
    
    /// Creates a new language with a given name and identifier.
    /// - Parameters:
    ///   - name: The display name of the programming language.
    ///   - id: A globally unique identifier for the language.
    public init(name: String, id: String) {
        self.name = name
        self.id = id
    }
    
    /// Finds the programming language that matches a given identifier, or creates a new one if it finds no existing language.
    /// - Parameter id: The identifier of the programming language.
    public init(id: String) {
        switch id {
        case "swift": self = .swift
        case "occ": self = .objectiveC
        case "javascript": self = .javaScript
        case "data": self = .data
        case "metal": self = .metal
        default:
            self.name = id
            self.id = id
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
            self.id = name.lowercased()
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
        return SourceLanguage.knownLanguages.first { $0.name.lowercased() == name.lowercased() }
    }
    
    private static func firstKnownLanguage(withIdentifier id: String) -> SourceLanguage? {
        return SourceLanguage.knownLanguages.first { $0.id.lowercased() == id.lowercased() }
    }
    
    /// The Swift programming language.
    public static let swift = SourceLanguage(name: "Swift", id: "swift")
    /// The Objective-C programming language.
    public static let objectiveC = SourceLanguage(name: "Objective-C", id: "occ")
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
}
