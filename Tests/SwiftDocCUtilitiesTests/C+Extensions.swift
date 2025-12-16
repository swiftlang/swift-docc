/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
#if os(Windows)
import ucrt
#elseif os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD)
import Glibc
#else
import Darwin
#endif

internal func SetEnvironmentVariable(_ key: String, _ value: String) {
#if os(Windows)
    _ = key.withCString(encodedAs: UTF16.self) { key in
        value.withCString(encodedAs: UTF16.self) { value in
            _wputenv_s(key, value)
        }
    }
#else
    setenv(key, value, 1)
#endif
}

internal func UnsetEnvironmentVariable(_ key: String) {
#if os(Windows)
    _ = key.withCString(encodedAs: UTF16.self) { key in
        "".withCString(encodedAs: UTF16.self) { value in
            _wputenv_s(key, value)
        }
    }
#else
    unsetenv(key)
#endif
}
