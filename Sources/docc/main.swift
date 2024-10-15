/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if os(macOS) || os(Linux) || os(Android) || os(Windows)
import SwiftDocCUtilities

Docc.main()
#else
fatalError("Command line interface supported only on macOS, Linux and Windows platforms.")
#endif
