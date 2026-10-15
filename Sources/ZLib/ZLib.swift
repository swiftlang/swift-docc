@_exported import CZLib

// All of the below are macros in <zlib.h>

public func deflateInit(
  _ stream: z_streamp,
  _ level: CInt
) -> CInt {
  return deflateInit_(stream, level,
                      ZLIB_VERSION, CInt(MemoryLayout<z_stream>.size))
}

public func deflateInit2(
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

public func inflateInit(
  _ stream: z_streamp
) -> CInt {
  return inflateInit_(stream,
                      ZLIB_VERSION, CInt(MemoryLayout<z_stream>.size))
}

public func inflateInit2(
  _ stream: z_streamp,
  _ windowBits: CInt
) -> CInt {
  return inflateInit2_(stream, windowBits,
                       ZLIB_VERSION, CInt(MemoryLayout<z_stream>.size))
}
