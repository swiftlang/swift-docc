/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/


/// Represents a code color-customization point for clients.
///
/// A key defines a code-listing component that renderers use for syntax highlighting.
///
/// - Note: Preference keys are backed by strings, so you can add new keys without breaking the public API.
public struct CodeColorsPreferenceKey: Hashable, Codable {
    private var rawValue: String
    
    /// Initializes a code color-preference key from a raw value.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    /// The background color key for the code area.
    public static let background = CodeColorsPreferenceKey(rawValue: "background")

    /// The color key renderers use for highlighted lines.
    public static let lineHighlight = CodeColorsPreferenceKey(rawValue: "lineHighlight")
    
    /// The color key renderers use for plain text.
    public static let text = CodeColorsPreferenceKey(rawValue: "text")
    
    /// The color key renderers use for keywords.
    public static let keyword = CodeColorsPreferenceKey(rawValue: "keyword")
    
    /// The color key renderers use of identifiers.
    public static let identifier = CodeColorsPreferenceKey(rawValue: "identifier")
    
    /// The color key renderers use for parameter names.
    public static let parameterName = CodeColorsPreferenceKey(rawValue: "parameterName")
    
    /// The color key renderers use for number literals.
    public static let numberLiteral = CodeColorsPreferenceKey(rawValue: "numberLiteral")
    
    /// The color key renderers use for string literals.
    public static let stringLiteral = CodeColorsPreferenceKey(rawValue: "stringLiteral")
    
    /// The color key renderers use for type annotations.
    public static let typeAnnotation = CodeColorsPreferenceKey(rawValue: "typeAnnotation")
    
    /// The color key renderers use for selected text.
    public static let selection = CodeColorsPreferenceKey(rawValue: "selection")
    
    /// The color key renderers use for documentation comments.
    public static let docComment = CodeColorsPreferenceKey(rawValue: "docComment")
    
    /// The color key renderers use for documentation comment fields.
    public static let docCommentField = CodeColorsPreferenceKey(rawValue: "docCommentField")
    
    /// The color key renderers use for comments.
    public static let comment = CodeColorsPreferenceKey(rawValue: "comment")
    
    /// The color key renderers use for URLs in comments.
    public static let commentURL = CodeColorsPreferenceKey(rawValue: "commentURL")
    
    /// The color key renderers use for keywords in build configuration code.
    public static let buildConfigKeyword = CodeColorsPreferenceKey(rawValue: "buildConfigKeyword")
    
    /// The color key renderers use for identifiers in build configuration code.
    public static let buildConfigId = CodeColorsPreferenceKey(rawValue: "buildConfigId")
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }
}
