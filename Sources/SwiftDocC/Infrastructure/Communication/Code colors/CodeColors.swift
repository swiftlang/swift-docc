/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A collection of colors that a renderer uses to highlight code.
public struct CodeColors: Equatable {

    /// The content color customizations for this collection.
    public var colors = [CodeColorsPreferenceKey: SRGBColor]()
    
    /// The color the renderer uses for code area backgrounds.
    public var background: SRGBColor? {
        get { return colors[.background] }
        set { colors[.background] = newValue }
    }
    
    /// The color the renderer uses for highlighted lines.
    public var lineHighlight: SRGBColor? {
        get { return colors[.lineHighlight] }
        set { colors[.lineHighlight] = newValue }
    }
    
    /// The color the renderer uses for plain text.
    public var text: SRGBColor? {
        get { return colors[.text] }
        set { colors[.text] = newValue }
    }
    
    /// The color the renderer uses for keywords.
    public var keyword: SRGBColor? {
        get { return colors[.keyword] }
        set { colors[.keyword] = newValue }
    }
    
    /// The color the renderer uses for identifiers.
    public var identifier: SRGBColor? {
        get { return colors[.identifier] }
        set { colors[.identifier] = newValue }
    }
    
    /// The color the renderer uses for parameter names.
    public var parameterName: SRGBColor? {
        get { return colors[.parameterName] }
        set { colors[.parameterName] = newValue }
    }
    
    /// The color the renderer uses for number literals.
    public var numberLiteral: SRGBColor? {
        get { return colors[.numberLiteral] }
        set { colors[.numberLiteral] = newValue }
    }
    
    /// The color the renderer uses for string literals.
    public var stringLiteral: SRGBColor? {
        get { return colors[.stringLiteral] }
        set { colors[.stringLiteral] = newValue }
    }
    
    /// The color the renderer uses for type annotations.
    public var typeAnnotation: SRGBColor? {
        get { return colors[.typeAnnotation] }
        set { colors[.typeAnnotation] = newValue }
    }
    
    /// The color the renderer uses for documentation comments.
    public var docComment: SRGBColor? {
        get { return colors[.docComment] }
        set { colors[.docComment] = newValue }
    }
    
    /// The color the renderer uses for documentation comment fields.
    public var docCommentField: SRGBColor? {
        get { return colors[.docCommentField] }
        set { colors[.docCommentField] = newValue }
    }
    
    /// The color the renderer uses for comments.
    public var comment: SRGBColor? {
        get { return colors[.comment] }
        set { colors[.comment] = newValue }
    }
    
    /// The color the renderer uses for URLs in comments.
    public var commentURL: SRGBColor? {
        get { return colors[.commentURL] }
        set { colors[.commentURL] = newValue }
    }
    
    /// The color the renderer uses for keywords in build configuration code.
    public var buildConfigKeyword: SRGBColor? {
        get { return colors[.buildConfigKeyword] }
        set { colors[.buildConfigKeyword] = newValue }
    }
    
    /// The color the renderer uses for identifiers in build-configuration code.
    public var buildConfigId: SRGBColor? {
        get { return colors[.buildConfigId] }
        set { colors[.buildConfigId] = newValue }
    }
    
    /// Creates a collection of colors given key-color pairs.
    public init(colors: [CodeColorsPreferenceKey: SRGBColor] = [:]) {
        self.colors = colors
    }
    
    /// Creates a collection of colors given the given values.
    /// - Parameters:
    ///   - background: The background color of the code area.
    ///   - text: The color the renderer uses for plain text.
    ///   - keyword: The color the renderer uses for keywords.
    ///   - identifier: The color the renderer uses for identifiers.
    ///   - parameterName: The color the renderer uses for parameter names.
    ///   - numberLiteral: The color the renderer uses for number literals.
    ///   - stringLiteral: The color the renderer uses for string literals.
    ///   - typeAnnotation: The color the renderer uses for type annotations.
    ///   - docComment: The color the renderer uses for documentation comments.
    ///   - docCommentField: The color the renderer uses for documentation comment fields.
    ///   - comment: The color the renderer uses for comments.
    ///   - commentURL: The color the renderer uses for URLs in comments.
    ///   - buildConfigKeyword: The color the renderer uses for keywords in build configuration code.
    ///   - buildConfigId: The color the renderer uses for identifiers in build configuration code.
    public init(
        background: SRGBColor?,
        text: SRGBColor?,
        keyword: SRGBColor?,
        identifier: SRGBColor?,
        parameterName: SRGBColor?,
        numberLiteral: SRGBColor?,
        stringLiteral: SRGBColor?,
        typeAnnotation: SRGBColor?,
        docComment: SRGBColor?,
        docCommentField: SRGBColor?,
        comment: SRGBColor?,
        commentURL: SRGBColor?,
        buildConfigKeyword: SRGBColor?,
        buildConfigId: SRGBColor?
    ) {
        self.background = background
        self.text = text
        self.keyword = keyword
        self.identifier = identifier
        self.parameterName = parameterName
        self.numberLiteral = numberLiteral
        self.stringLiteral = stringLiteral
        self.typeAnnotation = typeAnnotation
        self.docComment = docComment
        self.docCommentField = docCommentField
        self.comment = comment
        self.commentURL = commentURL
        self.buildConfigKeyword = buildConfigKeyword
        self.buildConfigId = buildConfigId
    }
}

// Codable conformance.
extension CodeColors: Codable {
    enum CodingKeys: String, CodingKey {
        case background
        case lineHighlight
        case text
        case keyword
        case identifier
        case parameterName
        case numberLiteral
        case stringLiteral
        case typeAnnotation
        case docComment
        case docCommentField
        case comment
        case commentURL
        case buildConfigKeyword
        case buildConfigId
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.background = try container.decodeIfPresent(SRGBColor.self, forKey: .background)
        self.lineHighlight = try container.decodeIfPresent(SRGBColor.self, forKey: .lineHighlight)
        self.text = try container.decodeIfPresent(SRGBColor.self, forKey: .text)
        self.keyword = try container.decodeIfPresent(SRGBColor.self, forKey: .keyword)
        self.identifier = try container.decodeIfPresent(SRGBColor.self, forKey: .identifier)
        self.parameterName = try container.decodeIfPresent(SRGBColor.self, forKey: .parameterName)
        self.numberLiteral = try container.decodeIfPresent(SRGBColor.self, forKey: .numberLiteral)
        self.stringLiteral = try container.decodeIfPresent(SRGBColor.self, forKey: .stringLiteral)
        self.typeAnnotation = try container.decodeIfPresent(SRGBColor.self, forKey: .typeAnnotation)
        self.docComment = try container.decodeIfPresent(SRGBColor.self, forKey: .docComment)
        self.docCommentField = try container.decodeIfPresent(SRGBColor.self, forKey: .docCommentField)
        self.comment = try container.decodeIfPresent(SRGBColor.self, forKey: .comment)
        self.commentURL = try container.decodeIfPresent(SRGBColor.self, forKey: .commentURL)
        self.buildConfigKeyword = try container.decodeIfPresent(SRGBColor.self, forKey: .buildConfigKeyword)
        self.buildConfigId = try container.decodeIfPresent(SRGBColor.self, forKey: .buildConfigId)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(background, forKey: .background)
        try container.encode(lineHighlight, forKey: .lineHighlight)
        try container.encode(text, forKey: .text)
        try container.encode(keyword, forKey: .keyword)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(parameterName, forKey: .parameterName)
        try container.encode(numberLiteral, forKey: .numberLiteral)
        try container.encode(stringLiteral, forKey: .stringLiteral)
        try container.encode(typeAnnotation, forKey: .typeAnnotation)
        try container.encode(docComment, forKey: .docComment)
        try container.encode(docCommentField, forKey: .docCommentField)
        try container.encode(comment, forKey: .comment)
        try container.encode(commentURL, forKey: .commentURL)
        try container.encode(buildConfigKeyword, forKey: .buildConfigKeyword)
        try container.encode(buildConfigId, forKey: .buildConfigId)
    }
}
