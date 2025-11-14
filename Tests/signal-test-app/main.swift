/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

//
// Trap signals and exit with a predefined error code.
// Check Tests/SwiftDocCUtilitiesTests/SignalTests.swift for more details.
//

#if os(macOS) || os(Linux) || os(Android)

import Foundation
import SwiftDocCUtilities

Signal.on(Signal.all) { _ in
    print("Signal test app exiting.")
    exit(99)
}

DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
    kill(getpid(), SIGABRT)
}

print("Signal test app running.")
RunLoop.current.run()
exit(0)

#endif
