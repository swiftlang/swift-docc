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
import SwiftDocC
import XCTest

class SRGBColorTests: XCTestCase {
    #if canImport(AppKit) || canImport(UIKit)
    func testInitializeFromSystemColor() {
        #if canImport(UIKit)
        let systemColor = UIColor(red: 0.21, green: 0.35, blue: 0.64, alpha: 0.74)
        #elseif canImport(AppKit)
        let systemColor = NSColor(red: 0.21, green: 0.35, blue: 0.64, alpha: 0.74)
        #endif
        
        let srgbColor = SRGBColor(from: systemColor)
        
        XCTAssertEqual(srgbColor?.red, 53)
        XCTAssertEqual(srgbColor?.green, 89)
        XCTAssertEqual(srgbColor?.blue, 163)
        XCTAssertEqual(srgbColor?.alpha, 0.74)
    }
    #endif
}

