/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest

// This file exists to shadow `FileManager.temporaryDirectory` in unit tests to warn about potentially referencing a shared location if multiple checkouts run tests at the same time in Swift CI.

extension FileManager {
    
    @available(*, deprecated, message: "Use `createTemporaryDirectory` instead in unit tests to avoid referencing a shared location in Swift CI.")
    var temporaryDirectory: URL {
        XCTFail("Use `createTemporaryDirectory` instead in unit tests to avoid referencing a shared location in Swift CI.")
        return URL(fileURLWithPath: Foundation.NSTemporaryDirectory())
    }
}
