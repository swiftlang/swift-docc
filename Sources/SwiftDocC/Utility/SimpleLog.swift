/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if canImport(os)
import os.log

func xlog(_ message: String) {
    if #available(OSX 10.12, iOS 10.0, *) {
        os_log("%s", message)
    } else {
        xlog_fallback(message)
    }
}
#else
func xlog(_ message: String) {
    xlog_fallback(message)
}
#endif

fileprivate func xlog_fallback(_ message: String) {
}
