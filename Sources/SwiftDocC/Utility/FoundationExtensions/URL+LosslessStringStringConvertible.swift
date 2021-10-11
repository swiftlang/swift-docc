/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

// TODO: This extension should be removed as soon as is possible without breaking dependencies (73223789)
extension URL: LosslessStringConvertible {
    @available(*, deprecated, message: "Please use Foundation's 'URL.init?(string: String)' instead.")
    public init?(_ description: String) {
        self.init(string: description)
    }
 }
