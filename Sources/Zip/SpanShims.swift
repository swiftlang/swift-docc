/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

// This repository can't use the standard library's `Span` types yet, but the
// vendored Zip sources are written in terms of `RawSpan` and `OutputRawSpan`.
//
// These minimal, pointer-backed stand-ins provide only the API surface the Zip
// code uses. Declarations in this module shadow the standard library's, so no
// other source file needs to change.
//
// To go back to the real types, delete this file (and its entry in
// Sources/Zip/CMakeLists.txt).

/// A stand-in for the standard library's `RawSpan`.
package struct RawSpan {
  let start: UnsafeRawPointer?
  package let byteCount: Int

  init(start: UnsafeRawPointer?, byteCount: Int) {
    self.start = start
    self.byteCount = byteCount
  }

  package func withUnsafeBytes<R>(
    _ body: (UnsafeRawBufferPointer) throws -> R
  ) rethrows -> R {
    try body(UnsafeRawBufferPointer(start: start, count: byteCount))
  }

  package func unsafeLoad<T>(fromByteOffset offset: Int, as type: T.Type) -> T {
    start!.loadUnaligned(fromByteOffset: offset, as: type)
  }

  package func extracting(first maxLength: Int) -> RawSpan {
    precondition(maxLength >= 0 && maxLength <= byteCount, "Length out of bounds")
    return RawSpan(start: start, byteCount: maxLength)
  }
}

/// A stand-in for the standard library's `OutputRawSpan`.
package struct OutputRawSpan {
  let buffer: UnsafeMutableRawBufferPointer
  package private(set) var byteCount: Int

  package init(buffer: UnsafeMutableRawBufferPointer, initializedCount: Int) {
    precondition(initializedCount >= 0 && initializedCount <= buffer.count, "Count out of bounds")
    self.buffer = buffer
    self.byteCount = initializedCount
  }

  /// The initialized portion of the buffer.
  package var bytes: RawSpan {
    RawSpan(start: buffer.baseAddress, byteCount: byteCount)
  }

  /// Calls `body` with the whole buffer and an in/out count of initialized bytes.
  package mutating func withUnsafeMutableBytes<R>(
    _ body: (UnsafeMutableRawBufferPointer, inout Int) throws -> R
  ) rethrows -> R {
    var count = byteCount
    defer { byteCount = count }
    let result = try body(buffer, &count)
    precondition(count >= 0 && count <= buffer.count, "Count out of bounds")
    return result
  }
}

extension UnsafeRawBufferPointer {
  var bytes: RawSpan {
    RawSpan(start: baseAddress, byteCount: count)
  }
}

extension UnsafeMutableRawBufferPointer {
  var bytes: RawSpan {
    RawSpan(start: baseAddress.map { UnsafeRawPointer($0) }, byteCount: count)
  }
}
