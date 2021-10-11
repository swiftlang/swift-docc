/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A reference to a file resource.
///
/// File resources are used, for example, to display the contents of a source code file in a Tutorial's step.
public struct FileReference: RenderReference {
    /// The type of this file reference.
    ///
    /// This value is always `.file`.
    public var type: RenderReferenceType = .file
    
    /// The identifier of this reference.
    public var identifier: RenderReferenceIdentifier
    
    /// The name of the file.
    public var fileName: String
    
    /// The type of the file, typically represented by its file extension.
    public var fileType: String
    
    /// The syntax for the content in the file, for example "swift".
    ///
    /// You can use this value to identify the syntax of the content. This would allow, for example, a renderer to perform syntax highlighting of the file's content.
    public var syntax: String
    
    /// The line-by-line contents of the file.
    public var content: [String]
    
    /// The line highlights for this file.
    public var highlights: [LineHighlighter.Highlight] = []
    
    /// Creates a new file reference.
    ///
    /// - Parameters:
    ///   - identifier: The identifier for this file reference.
    ///   - fileName: The name of the references file.
    ///   - fileType: The type of file, typically represented by its file extension.
    ///   - syntax: The syntax of the file's content.
    ///   - content: The line-by-line contents of the file.
    public init(identifier: RenderReferenceIdentifier, fileName: String, fileType: String, syntax: String, content: [String]) {
        self.identifier = identifier
        self.fileName = fileName
        self.fileType = fileType
        self.syntax = syntax
        self.content = content
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        type = try values.decode(RenderReferenceType.self, forKey: .type)
        identifier = try values.decode(RenderReferenceIdentifier.self, forKey: .identifier)
        fileName = try values.decode(String.self, forKey: .fileName)
        fileType = try values.decode(String.self, forKey: .fileType)
        syntax = try values.decode(String.self, forKey: .syntax)
        content = try values.decode([String].self, forKey: .content)
        highlights = try values.decodeIfPresent([LineHighlighter.Highlight].self, forKey: .highlights) ?? []
    }
}

/// A reference to a type of file.
///
/// This is not a reference to a specific file, but rather to a type of file. Use a file type reference together with a file reference to display an icon for that file type
/// alongside the content of that file. For example, a property list file icon alongside the content of a specific property list file.
public struct FileTypeReference: RenderReference {
    public var type: RenderReferenceType = .fileType
    
    /// The identifier of this reference.
    public var identifier: RenderReferenceIdentifier
    
    /// The display name of the file type.
    public var displayName: String
    
    /// The icon for this file type, encoded in Base64.
    public var iconBase64: Data
    
    /// Creates a new file type reference.
    /// - Parameters:
    ///   - identifier: The identifier of this reference.
    ///   - displayName: The display name of the file type.
    ///   - iconBase64: The icon for this file type, encoded in Base64.
    public init(identifier: RenderReferenceIdentifier, displayName: String, iconBase64: Data) {
        self.identifier = identifier
        self.displayName = displayName
        self.iconBase64 = iconBase64
    }
}
