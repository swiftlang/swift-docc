/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension URL {
    /// Returns a copy of the URL with the given fragment component.
    ///
    /// - Parameter fragment: The fragment component of the new URL, or `nil` for no fragment.
    /// - Returns: The URL with the new fragment component.
    func withFragment(_ fragment: String?) -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)!
        components.fragment = fragment
        return components.url!
    }
}
