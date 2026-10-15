/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
internal import ZLib

public struct ZLibError: Error {
    var message: String
}

public protocol ZipFileSink {
    var canSeek: Bool { get }

    /// Return the current position in the stream, or nil if not seekable
    func tell() throws -> Int?

    /// Seek to a location in the stream
    func seek(_ pos: Int) throws

    /// Write a fixed-width integer, in little-endian order
    func write<T: FixedWidthInteger>(_ x: T) throws

    /// Write a UTF-8 string
    func write(_ s: String) throws

    /// Write bytes
    func write(_ bytes: RawSpan) throws

    /// Close (optional)
    func close() throws
}

/// A ZipFileWriter can be used to generate a .zip file.
///
/// This generates UTF-8 zip files. By default (`allowZip64: false`), an
/// individual file whose compressed or uncompressed size doesn't fit in 32
/// bits causes `withFile` to throw `ZipFileError.fileTooLarge` rather than
/// produce a corrupt archive. Pass `allowZip64: true` to support such
/// files: every entry then reserves a small (20 byte) Zip64 slot in its
/// local header up front, since the local header is committed to the
/// stream before an entry's final size is known.
///
/// Central directory and end-of-central-directory records automatically
/// use Zip64 formatting whenever needed (more than 65535 entries, or an
/// archive whose central directory itself is larger than 4GB, or -- when
/// `allowZip64` is enabled -- an oversized individual file), regardless of
/// the `allowZip64` setting: that setting only concerns whether an
/// individual oversized file is accepted at all.
public class ZipFileWriter<S: ZipFileSink> {

    var sink: S
    var comment: String?
    let allowZip64: Bool

    struct FileInfo {
        var headerOffset: Int

        var name: String
        var date: Date
        var comment: String?

        var crc32: UInt32
        var compressedSize: Int
        var uncompressedSize: Int
    }

    var files: [FileInfo] = []
    var bytesWritten = 0
    private var buffer: UnsafeMutableRawBufferPointer

    public init(sink: consuming S, comment: String? = nil, allowZip64: Bool = false) {
        self.sink = sink
        self.comment = comment
        self.allowZip64 = allowZip64
        buffer = UnsafeMutableRawBufferPointer.allocate(
            byteCount: 65536,
            alignment: 16
        )
    }

    deinit {
        buffer.deallocate()
    }

    public func addDirectory(
        named name: String,
        date: Date = .now,
        comment: String? = nil
    ) throws {
        try withFile(named: name + "/", date: date, comment: comment) { _ in }
    }

    public func withFile(
        named name: String,
        date: Date = .now,
        comment: String? = nil,
        generate: ((RawSpan) throws -> Void) throws -> Void
    ) throws {
        let headerOffset = bytesWritten

        // max compression, UTF-8 name, length at end if not seekable
        let flags: UInt16 = sink.canSeek ? 0x802 : 0x80a

        // Write the local header
        try sink.write(UInt32(0x0403_4b50))  // PK<03><04>
        // Version (Windows Explorer doesn't like us using 4.5 unless we're using Zip64)
        try sink.write(UInt16(allowZip64 ? 45 : 20))
        try sink.write(flags)  // max compression, UTF-8 name
        try sink.write(UInt16(8))  // DEFLATE compression
        try sink.write(date.dosFileTime)  // last modified time

        let crcPos = try sink.tell()
        try sink.write(UInt32(0))  // CRC32
        try sink.write(UInt32(0))  // Compressed size
        try sink.write(UInt32(0))  // Uncompressed size

        try sink.write(UInt16(name.utf8.count))  // Filename length
        try sink.write(UInt16(allowZip64 ? 29 : 9))  // Extra field length

        bytesWritten += 30

        // Filename
        try sink.write(name)

        bytesWritten += name.utf8.count

        // Extra field
        try sink.write(UInt16(0x5455))  // UT - Extended Timestamp
        try sink.write(UInt16(5))  // Size
        try sink.write(UInt8(1))  // Only modification time
        try sink.write(Int32(date.timeIntervalSince1970))

        bytesWritten += 9

        // Extra field: reserved Zip64 slot. Always both sizes together --
        // the local-header form of the Zip64 extra field has no
        // independent per-field presence, unlike the central directory's.
        // For a seekable sink this is patched below with the real sizes
        // once known. For a non-seekable sink it's never patched (and
        // stays zeroed): its mere presence is itself the signal, for a
        // sequential reader, that the trailing data descriptor uses
        // 8-byte fields.
        var zip64ExtraPos: Int? = nil
        if allowZip64 {
            zip64ExtraPos = try sink.tell()
            try sink.write(UInt16(0x0001))  // Zip64 extended information
            try sink.write(UInt16(16))  // Size: two 8-byte subfields
            try sink.write(UInt64(0))  // Uncompressed size (placeholder)
            try sink.write(UInt64(0))  // Compressed size (placeholder)

            bytesWritten += 20
        }

        // Compress the data and update the CRC
        var crc = crc32_z(0, nil, 0)
        var stream = z_stream()

        stream.zalloc = nil
        stream.zfree = nil
        stream.opaque = nil

        stream.next_out = buffer.baseAddress!.assumingMemoryBound(to: Bytef.self)
        stream.avail_out = uInt(buffer.count)
        if deflateInit2(&stream, 9, Z_DEFLATED, -15, 8, Z_DEFAULT_STRATEGY) != Z_OK {
            throw ZLibError(message: String(cString: stream.msg!))
        }

        try generate { (data: RawSpan) throws -> Void in
            if data.byteCount == 0 {
                return
            }
            try data.withUnsafeBytes { inbuf in
                // Update CRC
                crc = crc32_z(crc, inbuf.baseAddress, inbuf.count)

                // Compress this chunk
                stream.next_in = UnsafeMutablePointer(
                    mutating:
                        inbuf.baseAddress!.assumingMemoryBound(to: Bytef.self)
                )
                stream.avail_in = uInt(inbuf.count)

                while stream.avail_in != 0 {
                    let ret = deflate(&stream, Z_NO_FLUSH)

                    if ret == Z_STREAM_ERROR {
                        throw ZLibError(message: String(cString: stream.msg!))
                    }

                    if stream.avail_out == 0 {
                        try sink.write(buffer.bytes)
                        bytesWritten += buffer.count
                        stream.next_out = buffer.baseAddress!.assumingMemoryBound(to: Bytef.self)
                        stream.avail_out = uInt(buffer.count)
                    }
                }
            }
        }

        while true {
            let ret = deflate(&stream, Z_FINISH)
            if ret != Z_OK && ret != Z_BUF_ERROR && ret != Z_STREAM_END {
                throw ZLibError(message: String(cString: stream.msg!))
            }

            let toFlush = buffer.count - Int(stream.avail_out)
            try sink.write(buffer.bytes.extracting(first: toFlush))
            bytesWritten += toFlush
            stream.next_out = buffer.baseAddress!.assumingMemoryBound(to: Bytef.self)
            stream.avail_out = uInt(buffer.count)

            if ret == Z_STREAM_END {
                break
            }
        }

        let ret = deflateEnd(&stream)
        if ret != Z_OK {
            throw ZLibError(message: String(cString: stream.msg!))
        }

        // A size of exactly UInt32.max is itself the Zip64 sentinel value,
        // so it must be treated as "doesn't fit" too -- hence >=, not >.
        let zip64SizeThreshold = UInt(UInt32.max)
        let needsZip64Sizes =
            stream.total_out >= zip64SizeThreshold || stream.total_in >= zip64SizeThreshold

        if !allowZip64 && needsZip64Sizes {
            throw ZipFileError.fileTooLarge(name)
        }

        // Now update the CRC, compressed and uncompressed sizes, *or*
        // write the data descriptor if this stream is not seekable.
        let currentPos = try sink.tell()
        if let crcPos {
            // Seekable: patch the fixed 4-byte local header fields in
            // place, independently sentineling each if it doesn't fit. If
            // a Zip64 slot was reserved, always mirror the true 64-bit
            // sizes there too -- redundant when the standard fields
            // already hold real values, but harmless, since a conformant
            // reader only consults a Zip64 subfield when the corresponding
            // standard field is sentineled.
            try sink.seek(crcPos)
            try sink.write(UInt32(crc))
            try sink.write(
                stream.total_out >= zip64SizeThreshold
                    ? UInt32(0xFFFF_FFFF) : UInt32(stream.total_out))
            try sink.write(
                stream.total_in >= zip64SizeThreshold
                    ? UInt32(0xFFFF_FFFF) : UInt32(stream.total_in))

            if let zip64ExtraPos {
                try sink.seek(zip64ExtraPos + 4)  // skip past the tag(2)+size(2) prefix
                try sink.write(UInt64(stream.total_in))  // Uncompressed size
                try sink.write(UInt64(stream.total_out))  // Compressed size
            }

            if allowZip64 && !needsZip64Sizes {
                // We optimistically claimed version 4.5 above; this entry
                // didn't actually need it, so patch it back down.
                try sink.seek(crcPos - 10)
                try sink.write(UInt16(20))
            }

            try sink.seek(currentPos!)
        } else {
            // Non-seekable: write the trailing data descriptor. Its size
            // fields are 8 bytes wide whenever this writer allows Zip64,
            // regardless of *this* entry's actual size -- every entry
            // reserved a Zip64 marker in its local header in that case,
            // and that marker's presence (not this entry's real size) is
            // what a streaming reader uses to decide the descriptor's
            // field width.
            try sink.write(UInt32(0x0807_4b50))  // PK<07><08>
            try sink.write(UInt32(crc))
            if allowZip64 {
                try sink.write(UInt64(stream.total_out))
                try sink.write(UInt64(stream.total_in))
                bytesWritten += 24  // 4 sig + 4 crc + 8 + 8
            } else {
                try sink.write(UInt32(stream.total_out))
                try sink.write(UInt32(stream.total_in))
                bytesWritten += 16  // 4 sig + 4 crc + 4 + 4
            }
        }

        // Add all of this to the list of files
        files.append(
            FileInfo(
                headerOffset: headerOffset,
                name: name,
                date: date,
                comment: comment,
                crc32: UInt32(crc),
                compressedSize: Int(stream.total_out),
                uncompressedSize: Int(stream.total_in)
            ))
    }

    public func close() throws {
        // max compression, UTF-8 name, length at end if not seekable
        let flags: UInt16 = sink.canSeek ? 0x802 : 0x80a
        let centralDirectoryOffset = bytesWritten
        let zip64SizeThreshold = Int(UInt32.max)

        // Write the central directory
        for file in files {
            // A size/offset of exactly UInt32.max is itself the Zip64
            // sentinel value, so it must be treated as "doesn't fit" too --
            // hence >=, not >. This is decided independently per field: a
            // small file located past the 4GB mark in a huge archive can
            // need only its header offset sentineled, for instance.
            let needsZip64UncompressedSize = file.uncompressedSize >= zip64SizeThreshold
            let needsZip64CompressedSize = file.compressedSize >= zip64SizeThreshold
            let needsZip64HeaderOffset = file.headerOffset >= zip64SizeThreshold
            let needsZip64 =
                needsZip64UncompressedSize || needsZip64CompressedSize || needsZip64HeaderOffset

            try sink.write(UInt32(0x0201_4b50))  // PK<01><02>
            try sink.write(needsZip64 ? UInt16(45) : UInt16(20))  // version made by
            try sink.write(needsZip64 ? UInt16(45) : UInt16(20))  // version needed
            try sink.write(flags)  // max compression, UTF-8 name
            try sink.write(UInt16(8))  // DEFLATE compression
            try sink.write(file.date.dosFileTime)  // last modified time
            try sink.write(file.crc32)  // CRC32
            try sink.write(
                needsZip64CompressedSize ? UInt32(0xFFFF_FFFF) : UInt32(file.compressedSize))
            try sink.write(
                needsZip64UncompressedSize ? UInt32(0xFFFF_FFFF) : UInt32(file.uncompressedSize))
            try sink.write(UInt16(file.name.utf8.count))  // Filename length

            // Zip64 extra field: only the subfields that are actually
            // needed, in the reader's fixed order (uncompressed size,
            // compressed size, header offset). Disk start is never needed
            // since spanned archives are never produced.
            let zip64PayloadSize =
                (needsZip64UncompressedSize ? 8 : 0) + (needsZip64CompressedSize ? 8 : 0)
                + (needsZip64HeaderOffset ? 8 : 0)
            let extraLength = 9 + (needsZip64 ? 4 + zip64PayloadSize : 0)
            try sink.write(UInt16(extraLength))  // Extra field length

            if let comment = file.comment {
                try sink.write(UInt16(comment.utf8.count))
            } else {
                try sink.write(UInt16(0))
            }

            try sink.write(UInt16(0))  // Disk number start
            try sink.write(UInt16(0))  // Internal file attributes
            try sink.write(UInt32(0))  // External file attributes
            try sink.write(
                needsZip64HeaderOffset ? UInt32(0xFFFF_FFFF) : UInt32(file.headerOffset))

            bytesWritten += 46

            // Filename
            try sink.write(file.name)

            bytesWritten += file.name.utf8.count

            // Extra field: UT - Extended Timestamp
            try sink.write(UInt16(0x5455))
            try sink.write(UInt16(5))  // Size
            try sink.write(UInt8(1))  // Only modification time
            try sink.write(Int32(file.date.timeIntervalSince1970))

            bytesWritten += 9

            // Extra field: Zip64
            if needsZip64 {
                try sink.write(UInt16(0x0001))
                try sink.write(UInt16(zip64PayloadSize))
                if needsZip64UncompressedSize {
                    try sink.write(UInt64(file.uncompressedSize))
                }
                if needsZip64CompressedSize {
                    try sink.write(UInt64(file.compressedSize))
                }
                if needsZip64HeaderOffset {
                    try sink.write(UInt64(file.headerOffset))
                }

                bytesWritten += 4 + zip64PayloadSize
            }

            // File comment
            if let comment = file.comment {
                try sink.write(comment)

                bytesWritten += comment.utf8.count
            }
        }

        let centralDirectorySize = bytesWritten - centralDirectoryOffset

        let needsZip64EntryCount = files.count >= 0xFFFF
        let needsZip64CdSize = centralDirectorySize >= zip64SizeThreshold
        let needsZip64CdOffset = centralDirectoryOffset >= zip64SizeThreshold
        let needsZip64Eocd = needsZip64EntryCount || needsZip64CdSize || needsZip64CdOffset

        if needsZip64Eocd {
            let zip64EocdOffset = bytesWritten

            try sink.write(UInt32(0x0606_4b50))  // Zip64 EOCD record signature
            try sink.write(UInt64(44))  // size of remaining record (fixed part only)
            try sink.write(UInt16(45))  // version made by
            try sink.write(UInt16(45))  // version needed to extract
            try sink.write(UInt32(0))  // number of this disk
            try sink.write(UInt32(0))  // disk with the start of the central directory
            try sink.write(UInt64(files.count))  // entries on this disk
            try sink.write(UInt64(files.count))  // entries in total
            try sink.write(UInt64(centralDirectorySize))  // size of central directory
            try sink.write(UInt64(centralDirectoryOffset))  // offset of central directory

            bytesWritten += 56

            try sink.write(UInt32(0x0706_4b50))  // Zip64 EOCD locator signature
            try sink.write(UInt32(0))  // disk with the start of the Zip64 EOCD record
            try sink.write(UInt64(zip64EocdOffset))  // offset of Zip64 EOCD record
            try sink.write(UInt32(1))  // total number of disks

            bytesWritten += 20
        }

        // Write the end of central directory record
        try sink.write(UInt32(0x0605_4b50))  // PK<05><06>
        try sink.write(UInt16(0))  // Disk 0
        try sink.write(UInt16(0))  // Directory disk 0
        try sink.write(needsZip64EntryCount ? UInt16(0xFFFF) : UInt16(files.count))
        try sink.write(needsZip64EntryCount ? UInt16(0xFFFF) : UInt16(files.count))
        try sink.write(needsZip64CdSize ? UInt32(0xFFFF_FFFF) : UInt32(centralDirectorySize))
        try sink.write(needsZip64CdOffset ? UInt32(0xFFFF_FFFF) : UInt32(centralDirectoryOffset))

        // Zip file comment
        if let comment {
            try sink.write(UInt16(comment.utf8.count))
            for elt in comment.utf8 {
                try sink.write(elt)
            }
        } else {
            try sink.write(UInt16(0))
        }

        try sink.close()
    }
}

// Provide default implementations of Sink methods
public extension ZipFileSink {
    func write<T: FixedWidthInteger>(_ x: T) throws {
        var maybeSwapped = x.littleEndian
        try withUnsafeBytes(of: &maybeSwapped) {
            try self.write($0.bytes)
        }
    }

    func write(_ s: String) throws {
        var sMutable = s
        try sMutable.withUTF8 {
            try self.write(UnsafeRawBufferPointer($0).bytes)
        }
    }

    func close() throws {
        // Dummy implementation
    }
}
