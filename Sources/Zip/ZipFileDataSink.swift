/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation

public enum ZipFileDataSinkError: Error {
  case badOffset
}

public class ZipFileDataSink: ZipFileSink {
  public var data: Data

  public var canSeek: Bool { true }
  
  private var pos: Int

  public init() {
    data = Data()
    pos = 0
  }

  public func tell() throws -> Int? {
    return pos
  }

  public func seek(_ pos: Int) throws {
    if pos < 0 || pos > data.count {
      throw ZipFileDataSinkError.badOffset
    }
    self.pos = pos
  }

  public func write(_ bytes: RawSpan) throws {
    let rangeToReplace = pos..<min(pos + bytes.byteCount, data.count)
    bytes.withUnsafeBytes { buffer in
      data.replaceSubrange(rangeToReplace, with: buffer)
    }
    pos += bytes.byteCount
  }
}
