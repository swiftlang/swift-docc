/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@_exported import CZLib

// All of the below are macros in <zlib.h>

package func deflateInit(
  _ stream: z_streamp,
  _ level: CInt
) -> CInt {
  return deflateInit_(stream, level,
                      ZLIB_VERSION, CInt(MemoryLayout<z_stream>.size))
}

package func deflateInit2(
  _ stream: z_streamp,
  _ level: CInt,
  _ method: CInt,
  _ windowBits: CInt,
  _ memLevel: CInt,
  _ strategy: CInt
) -> CInt {
  return deflateInit2_(stream, level, method, windowBits, memLevel, strategy,
                       ZLIB_VERSION, CInt(MemoryLayout<z_stream>.size))
}

package func inflateInit(
  _ stream: z_streamp
) -> CInt {
  return inflateInit_(stream,
                      ZLIB_VERSION, CInt(MemoryLayout<z_stream>.size))
}

package func inflateInit2(
  _ stream: z_streamp,
  _ windowBits: CInt
) -> CInt {
  return inflateInit2_(stream, windowBits,
                       ZLIB_VERSION, CInt(MemoryLayout<z_stream>.size))
}
