/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A color that associated with a documentation topic.
public struct TopicColor: Codable, Hashable {
    /// A string identifier for a built-in, standard color.
    ///
    /// This value is expected to be one of the following:
    ///  - term `blue`: A context-dependent blue color.
    ///
    ///  - term `gray`: A context-dependent gray color.
    ///
    ///  - term `green`: A context-dependent orange color.
    ///
    ///  - term `orange`: A context-dependent orange color.
    ///
    ///  - term `purple`: A context-dependent purple color.
    ///
    ///  - term `red`: A context-dependent red color.
    ///
    ///  - term `yellow`: A context-dependent yellow color.
    ///
    public let standardColorIdentifier: String?
    // The color identifier is optional to allow for a future where topic colors
    // can be defined by something besides the standard color identifiers.
    //
    // For example, we may allow fully custom colors in the future and allow
    // for providing some kind of `ColorReference` here.
    
    /// Create a topic color with the given standard color identifier.
    public init(standardColorIdentifier: String) {
        self.standardColorIdentifier = standardColorIdentifier
    }
}
