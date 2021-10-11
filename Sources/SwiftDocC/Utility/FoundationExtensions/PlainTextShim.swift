/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/**
 This shim exists to allow rdar://70891131 to be implemented before rdar://72911560 without
 breaking tools that depend on SwiftDocC.
 */

public extension String {
    var plainText: String {
        return self
    }
}
