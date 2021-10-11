/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A set of functions providing support for constructing human language phrases
/// for use alongside code documentation.
protocol LanguageConstructible {    
    /// Returns all the separators to insert between items of a list.
    func listSeparators(itemsCount: Int, listType: NativeLanguage.ListType) -> [String]
}

/// A structure allowing for adding further languages in the future.
public struct NativeLanguage {
    enum ListType {
        /// Signifies a list of alternative options, e.g. "One or two".
        case options
        
        /// Signifies a list of union items, e.g. "One and two".
        case union
    }
    
    static let english = EnglishLanguage()
}
