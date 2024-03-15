/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SymbolKit

/// A section that contains an type's possible values.
public struct PossibleValuesSection {
    public static var title: String {
        return "Possible Values"
    }
    
    /// The list of possible values.
    public var documentedValues: [PossibleValue]
    
    /// The list of defined values for the symbol.
    public var definedValues: [SymbolGraph.AnyScalar]
}
