/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A convenience structure to represent an external identifier of a symbol.
public enum ExternalIdentifier {
    
    /// An external identifier represented by a symbol's USR.
    case usr(_ usr: String)
    
    /// Returns the hashed identifier.
    public var hash: String {
        switch self {
        case .usr(let usr):
            let fnv = usr.fnv1()
            // Encode in base 36.
            return String(fnv, radix: 36, uppercase: false)
        }
    }
}
