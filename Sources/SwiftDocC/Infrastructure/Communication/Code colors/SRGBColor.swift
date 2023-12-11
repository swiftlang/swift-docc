/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A color in the sRGB color space, with normalized components.
public struct SRGBColor: Codable, Equatable {
    /// The normalized red component of the color.
    public var red: UInt8
    /// The normalized green component of the color.
    public var green: UInt8
    /// The normalized blue component of the color.
    public var blue: UInt8
    /// The alpha component of the color.
    public var alpha: Double
    
    /// Creates a color value given individual RGBA values.
    /// - Parameters:
    ///   - red: The normalized red component of the color.
    ///   - green: The normalized green component of the color.
    ///   - blue: The normalized blue component of the color.
    ///   - alpha: The alpha component of the color.
    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}
