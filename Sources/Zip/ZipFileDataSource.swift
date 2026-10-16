/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation

enum ZipFileDataSourceError: Error {
  case outOfRange
}

public class ZipFileDataSource: ZipFileSource {
  let data: Data

  public var length: Int { return data.count }

  public init(data: Data) {
    self.data = data
  }

  public func read(from offset: Int, into span: inout OutputRawSpan) throws {
    if offset < 0 || offset > data.count {
      throw ZipFileDataSourceError.outOfRange
    }

    span.withUnsafeMutableBytes { (buffer, count: inout Int) -> () in
      count = min(buffer.count, data.count - offset)
      data.copyBytes(to: buffer.baseAddress!.assumingMemoryBound(to: UInt8.self),
                     from: offset..<offset+count)
    }
  }

  public func close() throws {
    // Nothing to do
  }
}
