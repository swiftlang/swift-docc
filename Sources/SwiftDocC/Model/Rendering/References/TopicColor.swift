/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A custom authored color that can be associated with a documentation topic.
public struct TopicColor: Codable, Hashable {
    /// An integer value between `0` and `255` that represents the
    /// amount of red in the color.
    public let red: Int
    
    /// An integer value between `0` and `255` that represents the
    /// amount of green in the color.
    public let green: Int
    
    /// An integer value between `0` and `255` that represents the
    /// amount of blue in the color.
    public let blue: Int
    
    /// A floating-point value between `0.0` and `1.0` that
    /// represents the opacity of the color.
    public let opacity: Double
    
    /// Create a new topic color with the given color channel values.
    public init(red: Int, green: Int, blue: Int, opacity: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }
}
