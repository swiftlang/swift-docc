/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

package import Foundation

enum ZipFileDataSourceError: Error {
  case outOfRange
}

package class ZipFileDataSource: ZipFileSource {
  let data: Data

  package var length: Int { return data.count }

  package init(data: Data) {
    self.data = data
  }

  package func read(from offset: Int, into span: inout OutputRawSpan) throws {
    if offset < 0 || offset > data.count {
      throw ZipFileDataSourceError.outOfRange
    }

    span.withUnsafeMutableBytes { (buffer, count: inout Int) -> () in
      count = min(buffer.count, data.count - offset)
      data.copyBytes(to: buffer.baseAddress!.assumingMemoryBound(to: UInt8.self),
                     from: offset..<offset+count)
    }
  }

  package func close() throws {
    // Nothing to do
  }
}
