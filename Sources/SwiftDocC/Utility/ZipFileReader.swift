/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
internal import ZLib

public protocol ZipFileSource {
    /// The length of the source
    var length: Int { get }

    /// Read a fixed-width integer, in little-endian order
    func read<T: FixedWidthInteger>(from offset: Int, as: T.Type) throws -> T

    /// Read a UTF-8 string
    func read(from offset: Int, asStringOfLength: Int) throws -> String

    /// Read data from the source
    func read(from offset: Int, into: inout OutputRawSpan) throws

    /// Close the source
    func close() throws
}

/// A ZipFileReader can be used to read data from a .zip file.
public class ZipFileReader<S: ZipFileSource>: @unchecked Sendable {

    var source: S

    class Item: CustomStringConvertible {
        var headerOffset: Int?

        var name: String
        var date: Date
        var comment: String?

        var flags: UInt16
        var compression: UInt16
        var crc32: UInt32
        var compressedSize: Int
        var uncompressedSize: Int

        enum Kind {
            case file
            case directory([String: Item])
        }

        var kind: Kind

        init(
            headerOffset: Int?, name: String, date: Date, comment: String?,
            flags: UInt16, compression: UInt16, crc32: UInt32,
            compressedSize: Int, uncompressedSize: Int,
            kind: Kind
        ) {
            self.headerOffset = headerOffset
            self.name = name
            self.date = date
            self.comment = comment
            self.flags = flags
            self.compression = compression
            self.crc32 = crc32
            self.compressedSize = compressedSize
            self.uncompressedSize = uncompressedSize
            self.kind = kind
        }

        var description: String {
            return description(indent: 0)
        }

        func description(indent: Int) -> String {
            let spaces = String(repeating: " ", count: indent * 2)
            var result = "\(date)\t\(uncompressedSize)\t\(spaces)\(name)"
            if case .directory(let children) = kind {
                for (_, value) in children {
                    result.append("\n")
                    result.append(value.description(indent: indent + 1))
                }
            }
            return result
        }

        var isDirectory: Bool {
            switch kind {
            case .directory: return true
            case .file: return false
            }
        }

        var isFile: Bool {
            switch kind {
            case .directory: return false
            case .file: return true
            }
        }
    }

    var comment: String? = nil
    var root = Item(
        headerOffset: nil,
        name: "/",
        date: Date.now,
        comment: nil,
        flags: 0,
        compression: 0,
        crc32: 0,
        compressedSize: 0,
        uncompressedSize: 0,
        kind: .directory([:])
    )

    public init(source: S) throws {
        self.source = source
        try readDirectory()
    }

    deinit {
        do {
            try source.close()
        } catch {
            print("error closing ZipFileSource: \(error)")
        }
    }

    // Locate the End of Central Directory record by scanning backwards
    // from the end of the file.
    func findEndOfCentralDirectory() throws -> Int? {
        let toRead = min(source.length, 65536)
        if toRead < 22 {
            return nil
        }

        let buffer = UnsafeMutableRawBufferPointer.allocate(
            byteCount: toRead,
            alignment: 16
        )
        defer {
            buffer.deallocate()
        }

        var span = OutputRawSpan(buffer: buffer, initializedCount: 0)

        // Read the last 64KB of the file, then search backwards for the
        // central directory signature.
        try source.read(from: source.length - toRead, into: &span)

        if span.byteCount != toRead {
            throw ZipFileError.readOffEndOfSource
        }

        var pos = toRead - 22
        while pos >= 0 {
            let ch = span.bytes.unsafeLoad(fromByteOffset: pos, as: UInt8.self)
            switch ch {
            case 0x50:  // 'P'
                if span.bytes.unsafeLoad(fromByteOffset: pos + 1, as: UInt8.self) == 0x4b
                    && span.bytes.unsafeLoad(fromByteOffset: pos + 2, as: UInt8.self) == 0x05
                    && span.bytes.unsafeLoad(fromByteOffset: pos + 3, as: UInt8.self) == 0x06
                {
                    return source.length - toRead + pos
                }
                pos -= 4
            case 0x4b:  // 'K'
                pos -= 1
            case 0x05:
                pos -= 2
            case 0x06:
                pos -= 3
            default:
                pos -= 4
            }
        }

        return nil
    }

    // If a Zip64 End of Central Directory Locator immediately precedes the
    // standard EOCD record, it points to a Zip64 End of Central Directory
    // Record whose 64-bit central directory size/offset unconditionally
    // replace the standard EOCD's own (possibly-sentineled) 32-bit values.
    func resolveZip64EndOfCentralDirectory(
        eocdOffset: Int, cdSize: Int, cdOffset: Int
    ) throws -> (offset: Int, size: Int) {
        guard eocdOffset >= 20 else {
            return (cdOffset, cdSize)
        }

        let locatorOffset = eocdOffset - 20
        let locatorSignature = try source.read(from: locatorOffset, as: UInt32.self)
        if locatorSignature != 0x0706_4b50 /* PK<06><07> */ {
            return (cdOffset, cdSize)
        }

        let zip64EocdOffset = Int(try source.read(from: locatorOffset + 8, as: UInt64.self))

        let zip64Signature = try source.read(from: zip64EocdOffset, as: UInt32.self)
        if zip64Signature != 0x0606_4b50 /* PK<06><06> */ {
            throw ZipFileError.badZip64Record(at: zip64EocdOffset)
        }

        let sizeOfRemainingRecord = try source.read(from: zip64EocdOffset + 4, as: UInt64.self)
        if sizeOfRemainingRecord < 44 {
            throw ZipFileError.badZip64Record(at: zip64EocdOffset)
        }

        let zip64CdSize = Int(try source.read(from: zip64EocdOffset + 40, as: UInt64.self))
        let zip64CdOffset = Int(try source.read(from: zip64EocdOffset + 48, as: UInt64.self))

        return (zip64CdOffset, zip64CdSize)
    }

    func readDirectory() throws {
        guard let eocdOffset = try findEndOfCentralDirectory() else {
            throw ZipFileError.noCentralDirectory
        }

        // Read the end-of-central-directory block
        let signature = try source.read(from: eocdOffset, as: UInt32.self)
        if signature != 0x0605_4b50 /* PK<05><06> */ {
            throw ZipFileError.noCentralDirectory
        }

        let disk = try source.read(from: eocdOffset + 4, as: UInt16.self)
        let directoryDisk = try source.read(from: eocdOffset + 6, as: UInt16.self)
        let entriesOnDisk = try source.read(from: eocdOffset + 8, as: UInt16.self)
        let totalEntries = try source.read(from: eocdOffset + 10, as: UInt16.self)

        if disk != directoryDisk || entriesOnDisk != totalEntries {
            throw ZipFileError.spannedArchivesNotSupported
        }

        let cdSize = Int(try source.read(from: eocdOffset + 12, as: UInt32.self))
        let cdOffset = Int(try source.read(from: eocdOffset + 16, as: UInt32.self))

        let resolvedDirectory = try resolveZip64EndOfCentralDirectory(
            eocdOffset: eocdOffset, cdSize: cdSize, cdOffset: cdOffset)

        let commentLength = try source.read(from: eocdOffset + 20, as: UInt16.self)

        if commentLength > 0 {
            comment = try source.read(
                from: eocdOffset + 22,
                asStringOfLength: Int(commentLength))
        }

        // Now read the central directory
        var pos = resolvedDirectory.offset
        while pos < resolvedDirectory.offset + resolvedDirectory.size {
            let entryPos = pos
            let signature = try source.read(from: pos, as: UInt32.self)
            if signature != 0x0201_4b50 /* PK<01><02> */ {
                throw ZipFileError.badDirectoryEntry(at: pos)
            }

            // let madeByVersion = try source.read(from: pos + 4, as: UInt16.self)
            let requiredVersion = try source.read(from: pos + 6, as: UInt16.self)

            if requiredVersion > 45 {
                throw ZipFileError.unsupportedVersion(requiredVersion)
            }

            let flags = try source.read(from: pos + 8, as: UInt16.self)
            let compression = try source.read(from: pos + 10, as: UInt16.self)
            let dosFileTime = try source.read(from: pos + 12, as: UInt32.self)
            let crc32 = try source.read(from: pos + 16, as: UInt32.self)
            let compressedSize32 = try source.read(from: pos + 20, as: UInt32.self)
            let uncompressedSize32 = try source.read(from: pos + 24, as: UInt32.self)
            let nameLength = Int(try source.read(from: pos + 28, as: UInt16.self))
            let extraLength = Int(try source.read(from: pos + 30, as: UInt16.self))
            let commentLength = Int(try source.read(from: pos + 32, as: UInt16.self))
            let diskNumberStart = try source.read(from: pos + 34, as: UInt16.self)
            //let internalAttrs = try source.read(from: pos + 36, as: UInt16.self)
            //let externalAttrs = try source.read(from: pos + 38, as: UInt32.self)
            let localHeaderOffset32 = try source.read(from: pos + 42, as: UInt32.self)
            var timestamp: Date = Date(dosFileTime: dosFileTime)

            // Zip64: each of these fields can independently be sentineled to
            // 0xFFFFFFFF/0xFFFF, with the real 64-bit value recovered below
            // from a 0x0001 extra field. Disk start isn't otherwise used
            // (spanned archives aren't supported), but must still be
            // consulted to know whether the extra field's fixed-order
            // subfields include it.
            let needsZip64UncompressedSize = uncompressedSize32 == 0xFFFF_FFFF
            let needsZip64CompressedSize = compressedSize32 == 0xFFFF_FFFF
            let needsZip64HeaderOffset = localHeaderOffset32 == 0xFFFF_FFFF
            let needsZip64DiskStart = diskNumberStart == 0xFFFF

            var resolvedUncompressedSize = Int(uncompressedSize32)
            var resolvedCompressedSize = Int(compressedSize32)
            var resolvedHeaderOffset = Int(localHeaderOffset32)

            var foundZip64UncompressedSize = false
            var foundZip64CompressedSize = false
            var foundZip64HeaderOffset = false

            pos += 46

            let name = try source.read(from: pos, asStringOfLength: nameLength)

            pos += nameLength

            let extraEnd = pos + extraLength
            while pos < extraEnd {
                let tag = try source.read(from: pos, as: UInt16.self)
                let size = Int(try source.read(from: pos + 2, as: UInt16.self))

                // UT - Extended Timestamp
                if tag == 0x5455 && size >= 5 {
                    let flags = try source.read(from: pos + 4, as: UInt8.self)
                    if (flags & 1) != 0 {
                        let unixTimestamp = try source.read(from: pos + 5, as: Int32.self)
                        timestamp = Date(
                            timeIntervalSince1970:
                                TimeInterval(unixTimestamp))
                    }
                }

                // Zip64 Extended Information Extra Field. Subfields appear,
                // in this fixed order, only for the standard fields that
                // were sentineled above.
                if tag == 0x0001 {
                    var subPos = pos + 4
                    let subEnd = pos + 4 + size

                    if needsZip64UncompressedSize {
                        guard subPos + 8 <= subEnd else {
                            throw ZipFileError.badDirectoryEntry(at: entryPos)
                        }
                        resolvedUncompressedSize = Int(try source.read(from: subPos, as: UInt64.self))
                        foundZip64UncompressedSize = true
                        subPos += 8
                    }
                    if needsZip64CompressedSize {
                        guard subPos + 8 <= subEnd else {
                            throw ZipFileError.badDirectoryEntry(at: entryPos)
                        }
                        resolvedCompressedSize = Int(try source.read(from: subPos, as: UInt64.self))
                        foundZip64CompressedSize = true
                        subPos += 8
                    }
                    if needsZip64HeaderOffset {
                        guard subPos + 8 <= subEnd else {
                            throw ZipFileError.badDirectoryEntry(at: entryPos)
                        }
                        resolvedHeaderOffset = Int(try source.read(from: subPos, as: UInt64.self))
                        foundZip64HeaderOffset = true
                        subPos += 8
                    }
                    if needsZip64DiskStart {
                        guard subPos + 4 <= subEnd else {
                            throw ZipFileError.badDirectoryEntry(at: entryPos)
                        }
                        // Spanned archives aren't supported, so the value
                        // itself is unused, but it must still be consumed to
                        // keep the fixed-order block fully accounted for.
                        subPos += 4
                    }

                    if subPos != subEnd {
                        throw ZipFileError.badDirectoryEntry(at: entryPos)
                    }
                }

                if extraEnd - pos < size {
                    throw ZipFileError.badDirectoryEntry(at: entryPos)
                }
                pos += size + 4
            }

            // Every sentineled field must have actually been resolved by a
            // 0x0001 block; a sentinel with no matching Zip64 extra field is
            // a malformed entry.
            if (needsZip64UncompressedSize && !foundZip64UncompressedSize)
                || (needsZip64CompressedSize && !foundZip64CompressedSize)
                || (needsZip64HeaderOffset && !foundZip64HeaderOffset)
            {
                throw ZipFileError.badDirectoryEntry(at: entryPos)
            }

            pos = extraEnd

            var comment: String? = nil
            if commentLength > 0 {
                comment = try source.read(
                    from: pos,
                    asStringOfLength: commentLength)
                pos += commentLength
            }

            let isDirectory = name.hasSuffix("/")

            var pieces = name.split(separator: "/")
            let filename = String(pieces.removeLast())
            var parent = root
            for piece in pieces.map({ String($0) }) {
                guard case .directory(var contents) = parent.kind else {
                    throw ZipFileError.badPathInDirectory(name)
                }

                if let child = contents[piece] {
                    switch child.kind {
                    case .file:
                        throw ZipFileError.badPathInDirectory(name)
                    case .directory:
                        break
                    }

                    parent = child
                } else {
                    // We create directories where they don't exist, since the order
                    // of items in the directory is undefined.
                    let child = Item(
                        headerOffset: nil,
                        name: piece,
                        date: Date.now,
                        comment: nil,
                        flags: 0,
                        compression: 0,
                        crc32: 0,
                        compressedSize: 0,
                        uncompressedSize: 0,
                        kind: .directory([:])
                    )

                    contents[piece] = child
                    parent.kind = .directory(contents)

                    parent = child
                }
            }

            let newItem: Item
            if isDirectory {
                newItem = Item(
                    headerOffset: resolvedHeaderOffset,
                    name: filename,
                    date: timestamp,
                    comment: comment,
                    flags: flags,
                    compression: compression,
                    crc32: crc32,
                    compressedSize: resolvedCompressedSize,
                    uncompressedSize: resolvedUncompressedSize,
                    kind: .directory([:])
                )
            } else {
                newItem = Item(
                    headerOffset: resolvedHeaderOffset,
                    name: filename,
                    date: timestamp,
                    comment: comment,
                    flags: flags,
                    compression: compression,
                    crc32: crc32,
                    compressedSize: resolvedCompressedSize,
                    uncompressedSize: resolvedUncompressedSize,
                    kind: .file
                )
            }

            if case .directory(var contents) = parent.kind {
                if let existingItem = contents[filename] {
                    if !isDirectory {
                        throw ZipFileError.duplicateEntry(name)
                    }
                    if case .file = existingItem.kind {
                        throw ZipFileError.duplicateEntry(name)
                    }

                    newItem.kind = existingItem.kind
                }
                contents[filename] = newItem
                parent.kind = .directory(contents)
            }
        }
    }

    func normalized(path: String) -> [String]? {
        var normalized: [String] = []
        for piece in path.split(separator: "/") {
            if piece == "." {
                continue
            }
            if piece == ".." {
                if normalized.count == 0 {
                    return nil
                }

                normalized.removeLast()
                continue
            }
            normalized.append(String(piece))
        }
        return normalized
    }

    func item(at path: String) -> Item? {
        guard let normalizedPath = normalized(path: path) else {
            return nil
        }
        var item = root
        for piece in normalizedPath {
            switch item.kind {
            case .directory(let contents):
                guard let newItem = contents[piece] else {
                    return nil
                }
                item = newItem
            case .file:
                return nil
            }
        }
        return item
    }

    public func fileExists(
        atPath path: String,
        isDirectory: UnsafeMutablePointer<ObjCBool>?
    ) -> Bool {
        guard let item = item(at: path) else {
            return false
        }

        if let isDirectory {
            isDirectory.pointee = ObjCBool(item.isDirectory)
        }

        return true
    }

    public func directoryExists(atPath path: String) -> Bool {
        guard let item = item(at: path) else {
            return false
        }

        return item.isDirectory
    }

    public func fileExists(atPath path: String) -> Bool {
        guard let item = item(at: path) else {
            return false
        }

        return item.isFile
    }

    public class File {
        var reader: ZipFileReader
        var stream: z_stream
        var buffer: UnsafeMutableRawBufferPointer?

        var isCompressed: Bool
        var pos: Int
        var end: Int

        private(set) var name: String
        private(set) var length: Int
        private(set) var timestamp: Date

        init(
            reader: ZipFileReader,
            buffer: UnsafeMutableRawBufferPointer?,
            isCompressed: Bool,
            pos: Int, end: Int,
            name: String, length: Int,
            timestamp: Date
        ) {
            self.reader = reader
            self.stream = z_stream()
            self.buffer = buffer
            self.isCompressed = isCompressed
            self.pos = pos
            self.end = end
            self.name = name
            self.length = length
            self.timestamp = timestamp
        }

        deinit {
            if isCompressed {
                inflateEnd(&stream)
            }
            if let buffer {
                buffer.deallocate()
            }
        }

        public func read(into span: inout OutputRawSpan) throws {
            if isCompressed {
                guard let buffer else {
                    fatalError("buffer is somehow unset")
                }

                // We're reading and decompressing compressed data
                try span.withUnsafeMutableBytes { (output, count: inout Int) in
                    stream.next_out = output.baseAddress!.assumingMemoryBound(to: Bytef.self)
                    stream.avail_out = uInt(output.count)

                    while stream.avail_out != 0 {
                        if stream.avail_in == 0 {
                            let toRead = min(end - pos, buffer.count)
                            let rebased = UnsafeMutableRawBufferPointer(
                                rebasing:
                                    buffer[0..<toRead]
                            )
                            var span = OutputRawSpan(buffer: rebased, initializedCount: 0)

                            try reader.source.read(from: pos, into: &span)
                            pos += span.byteCount

                            stream.next_in = buffer.baseAddress!.assumingMemoryBound(to: Bytef.self)
                            stream.avail_in = uInt(span.byteCount)
                        }

                        let ret = inflate(&stream, 0)
                        if ret == Z_STREAM_END {
                            break
                        }
                        if ret != Z_OK {
                            throw ZLibError(message: String(cString: stream.msg!))
                        }
                    }

                    count = output.count - Int(stream.avail_out)
                }
            } else {
                // We're reading uncompressed data
                try span.withUnsafeMutableBytes { (output, count: inout Int) in
                    let toRead = min(end - pos, output.count)
                    let rebased = UnsafeMutableRawBufferPointer(
                        rebasing:
                            output[0..<toRead]
                    )
                    var subspan = OutputRawSpan(buffer: rebased, initializedCount: 0)
                    try reader.source.read(from: pos, into: &subspan)
                    count = subspan.byteCount
                    pos += count
                }
            }
        }
    }

    public func open(path: String) throws -> File {
        guard let item = item(at: path) else {
            throw ZipFileError.fileNotFound(path)
        }

        if item.isDirectory {
            throw ZipFileError.itemIsADirectory(path)
        }

        // We don't support encryption, or any compression other than DEFLATE
        if (item.flags & 0xf7f1) != 0
            || (item.compression != 0 && item.compression != 8)
        {
            throw ZipFileError.unsupportedCompression(path)
        }

        // Find the local header
        let pos = item.headerOffset!
        let signature = try source.read(from: pos, as: UInt32.self)
        if signature != 0x0403_4b50 {
            throw ZipFileError.badLocalHeader(for: path)
        }

        let nameLength = try source.read(from: pos + 26, as: UInt16.self)
        let extraFieldLength = try source.read(from: pos + 28, as: UInt16.self)

        // The item's data starts here
        let dataStart = pos + 30 + Int(nameLength) + Int(extraFieldLength)
        let dataEnd = dataStart + item.compressedSize

        if item.compression == 0 {
            return File(
                reader: self, buffer: nil,
                isCompressed: false, pos: dataStart, end: dataEnd,
                name: item.name, length: item.compressedSize,
                timestamp: item.date)
        } else {
            let file = File(
                reader: self,
                buffer: UnsafeMutableRawBufferPointer.allocate(
                    byteCount: 65536, alignment: 16
                ),
                isCompressed: true, pos: dataStart, end: dataEnd,
                name: item.name, length: item.uncompressedSize,
                timestamp: item.date)

            let ret = inflateInit2(&file.stream, -15)
            if ret != Z_OK {
                throw ZLibError(message: String(cString: file.stream.msg!))
            }

            return file
        }
    }
}

extension ZipFileSource {
    /// Read a fixed-width integer, in little-endian order
    public func read<T: FixedWidthInteger>(from offset: Int, as: T.Type) throws -> T {
        return try withUnsafeTemporaryAllocation(
            byteCount: MemoryLayout<T>.size,
            alignment: MemoryLayout<T>.alignment
        ) {
            buffer -> T in

            var output = OutputRawSpan(buffer: buffer, initializedCount: 0)

            try self.read(from: offset, into: &output)

            if output.byteCount < MemoryLayout<T>.size {
                throw ZipFileError.readOffEndOfSource
            }

            return output.bytes.unsafeLoad(fromByteOffset: 0, as: T.self).littleEndian
        }
    }

    /// Read a UTF-8 string
    public func read(from offset: Int, asStringOfLength length: Int) throws -> String {
        return try withUnsafeTemporaryAllocation(byteCount: length, alignment: 1) {
            buffer in

            var output = OutputRawSpan(buffer: buffer, initializedCount: 0)

            try self.read(from: offset, into: &output)

            if output.byteCount != length {
                throw ZipFileError.readOffEndOfSource
            }

            return output.bytes.withUnsafeBytes { bytes in
                return String(decoding: bytes, as: UTF8.self)
            }
        }
    }
}
