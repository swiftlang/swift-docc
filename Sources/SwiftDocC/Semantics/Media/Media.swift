/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A base class for a piece of media, such as an image or video.
public class Media: Semantic {
    /// A reference to the source file for the media item.
    public let source: ResourceReference
    
    /// Creates a new semantic object that represents a piece of media.
    /// 
    /// - Parameter source: A reference to the source file for the media item.
    init(source: ResourceReference) {
        self.source = source
    }
    
    enum Semantics {
        enum Source: DirectiveArgument {
            public static let argumentName = "source"
        }
        enum Poster: DirectiveArgument {
            public static var argumentName = "poster"
        }
        enum Alt: DirectiveArgument {
            static let argumentName = "alt"
        }
    }
}
