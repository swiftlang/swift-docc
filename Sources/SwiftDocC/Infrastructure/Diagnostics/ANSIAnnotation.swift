/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

struct ANSIAnnotation {
    enum Color: UInt8 {
        case normal = 0
        case red = 31
        case green = 32
        case yellow = 33
        case `default` = 39
    }
    
    enum Trait: UInt8 {
        case normal = 0
        case bold = 1
        case italic = 3
    }
    
    private var color: Color
    private var trait: Trait
    
    /// The textual representation of the annotation.
    private var code: String {
        "\u{001B}[\(trait.rawValue);\(color.rawValue)m"
    }
    
    init(color: Color, trait: Trait = .normal) {
        self.color = color
        self.trait = trait
    }
    
    func applied(to message: String) -> String {
        "\(code)\(message)\(ANSIAnnotation.normal.code)"
    }
    
    static var normal: ANSIAnnotation {
        self.init(color: .normal, trait: .normal)
    }
    
    /// Annotation used for highlighting source text.
    static var sourceHighlight: ANSIAnnotation {
        ANSIAnnotation(color: .green, trait: .bold)
    }
    /// Annotation used for highlighting source suggestion.
    static var sourceSuggestionHighlight: ANSIAnnotation {
        ANSIAnnotation(color: .default, trait: .bold)
    }
}
