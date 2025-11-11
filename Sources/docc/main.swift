/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if os(macOS) || os(Linux) || os(Android) || os(Windows) || os(FreeBSD)
import CommandLine

await Task {
    await Docc.main()
}.value
#else
fatalError("Command line interface supported only on macOS, Linux and Windows platforms.")
#endif
