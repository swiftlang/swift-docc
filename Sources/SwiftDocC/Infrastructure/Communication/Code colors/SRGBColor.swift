/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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
    
    #if canImport(UIKit)
    
    /// Creates a new instance from the given `UIColor`.
    public init?(from uiColor: UIColor) {
        guard let components = uiColor.cgColor.components, components.count >= 4 else { return nil }
        
        self.red = UInt8(Double(components[0]) * 255.0)
        self.green = UInt8(Double(components[1]) * 255.0)
        self.blue = UInt8(Double(components[2]) * 255.0)
        self.alpha = Double(components[3])
    }
    
    #elseif canImport(AppKit)
    
    /// Creates a new instance from the given `NSColor`.
    public init?(from nsColor: NSColor) {
        // The normalization factor this initializer uses to convert between NSColor and sRGB
        // color spaces as described by
        // <https://developer.apple.com/library/content/qa/qa1576/_index.html>.
        let normalizationFactor = 255.99999
        
        guard let color = nsColor.usingColorSpace(.sRGB) else { return nil }
        
        self.red = UInt8(Double(color.redComponent) * normalizationFactor)
        self.green = UInt8(Double(color.greenComponent) * normalizationFactor)
        self.blue = UInt8(Double(color.blueComponent) * normalizationFactor)
        self.alpha = Double(color.alphaComponent)
    }
    #endif
}
