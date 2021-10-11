/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension DispatchGroup {
    /// Performs a block asynchronously on the given queue and increases the group counter while running the block.
    /// - Parameters:
    ///   - queue: A queue to run the task on.
    ///   - block: A block of work to perform.
    func async(queue: DispatchQueue, block: @escaping () -> Void) {
        enter()
        queue.async { [unowned self] in
            defer { self.leave() }
            block()
        }
    }
}
