/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
@testable import Zip

// MARK: - Test helpers

/// Builds a zip archive in memory using `ZipFileWriter` and returns the resulting bytes.
private func makeZipData(
    comment: String? = nil,
    allowZip64: Bool = false,
    build: (ZipFileWriter<ZipFileDataSink>) throws -> Void
) throws -> Data {
    let sink = ZipFileDataSink()
    let writer = ZipFileWriter(sink: sink, comment: comment, allowZip64: allowZip64)
    try build(writer)
    try writer.close()
    return sink.data
}

/// Feeds `data` to a `withFile` generator closure, optionally split into multiple
/// chunks, to exercise both single-shot and multi-call writes.
private func writeChunks(
    _ write: (RawSpan) throws -> Void,
    _ data: Data,
    chunkSize: Int? = nil
) throws {
    if data.isEmpty { return }
    let size = chunkSize ?? data.count
    var index = data.startIndex
    while index < data.endIndex {
        let chunkEnd = data.index(index, offsetBy: size, limitedBy: data.endIndex) ?? data.endIndex
        let chunk = data[index..<chunkEnd]
        try chunk.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            try write(buffer.bytes)
        }
        index = chunkEnd
    }
}

/// Reads an entire `ZipFileReader.File` into memory.
private func readAll(_ file: ZipFileReader<ZipFileDataSource>.File) throws -> Data {
    var result = Data()
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 8192, alignment: 16)
    defer { buffer.deallocate() }
    while result.count < file.length {
        var span = OutputRawSpan(buffer: buffer, initializedCount: 0)
        try file.read(into: &span)
        if span.byteCount == 0 { break }
        result.append(contentsOf: buffer[0..<span.byteCount])
    }
    return result
}

/// Deterministic pseudo-random (i.e. incompressible) data, for exercising DEFLATE
/// on data that won't shrink much.
private func pseudoRandomData(count: Int, seed: UInt64 = 0x1234_5678_9abc_def0) -> Data {
    var state = seed
    var bytes = [UInt8]()
    bytes.reserveCapacity(count)
    for _ in 0..<count {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        bytes.append(UInt8(truncatingIfNeeded: state >> 33))
    }
    return Data(bytes)
}

/// A `ZipFileSink` that cannot seek, forcing `ZipFileWriter` down its
/// data-descriptor (streaming) code path instead of patching sizes in place.
private final class StreamingSink: ZipFileSink {
    private(set) var data = Data()
    var canSeek: Bool { false }
    func tell() throws -> Int? { nil }
    func seek(_ pos: Int) throws { fatalError("StreamingSink cannot seek") }
    func write(_ bytes: RawSpan) throws {
        bytes.withUnsafeBytes { buffer in
            data.append(contentsOf: buffer)
        }
    }
}

/// Hand-builds a minimal zip file consisting only of central directory entries
/// (with dummy sizes/offsets) followed by an end-of-central-directory record.
/// Useful for exercising `readDirectory`'s validation logic without needing
/// real compressed payloads or local headers.
private func buildCentralDirectoryOnlyZip(
    entries: [(name: String, requiredVersion: UInt16, flags: UInt16, compression: UInt16)]
) -> Data {
    var cd = Data()
    func appendU16(_ v: UInt16, to data: inout Data) {
        withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) }
    }
    func appendU32(_ v: UInt32, to data: inout Data) {
        withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) }
    }

    for entry in entries {
        let nameBytes = Array(entry.name.utf8)
        appendU32(0x0201_4b50, to: &cd)  // central directory entry signature
        appendU16(20, to: &cd)  // version made by
        appendU16(entry.requiredVersion, to: &cd)  // version needed to extract
        appendU16(entry.flags, to: &cd)
        appendU16(entry.compression, to: &cd)
        appendU32(0, to: &cd)  // dos time
        appendU32(0, to: &cd)  // crc32
        appendU32(0, to: &cd)  // compressed size
        appendU32(0, to: &cd)  // uncompressed size
        appendU16(UInt16(nameBytes.count), to: &cd)
        appendU16(0, to: &cd)  // extra field length
        appendU16(0, to: &cd)  // comment length
        appendU16(0, to: &cd)  // disk number start
        appendU16(0, to: &cd)  // internal attributes
        appendU32(0, to: &cd)  // external attributes
        appendU32(0, to: &cd)  // local header offset
        cd.append(contentsOf: nameBytes)
    }

    var eocd = Data()
    appendU32(0x0605_4b50, to: &eocd)  // end-of-central-directory signature
    appendU16(0, to: &eocd)  // disk number
    appendU16(0, to: &eocd)  // directory disk
    appendU16(UInt16(entries.count), to: &eocd)  // entries on this disk
    appendU16(UInt16(entries.count), to: &eocd)  // entries in total
    appendU32(UInt32(cd.count), to: &eocd)  // central directory size
    appendU32(0, to: &eocd)  // central directory offset (it's right at the start)
    appendU16(0, to: &eocd)  // comment length

    return cd + eocd
}

/// Finds the byte offset of the nth central directory entry signature in `data`.
private func offsetOfCentralDirectoryEntry(in data: Data, occurrence: Int = 0) -> Int {
    let signature: [UInt8] = [0x50, 0x4b, 0x01, 0x02]
    var found = 0
    var index = data.startIndex
    while index <= data.endIndex - signature.count {
        if data[index] == signature[0], data[index + 1] == signature[1],
            data[index + 2] == signature[2], data[index + 3] == signature[3]
        {
            if found == occurrence { return index }
            found += 1
        }
        index += 1
    }
    fatalError("no central directory entry found")
}

// MARK: - Round-trip tests

@Test func writeAndReadSingleFile() throws {
    let content = Data("Hello, swift-zip!".utf8)
    let date = Date(timeIntervalSince1970: 1_700_000_000)

    let zipData = try makeZipData { writer in
        try writer.withFile(named: "hello.txt", date: date) { write in
            try writeChunks(write, content)
        }
    }

    let reader = try ZipFileReader(source: ZipFileDataSource(data: zipData))

    #expect(reader.fileExists(atPath: "hello.txt"))
    #expect(!reader.directoryExists(atPath: "hello.txt"))

    let file = try reader.open(path: "hello.txt")
    #expect(file.name == "hello.txt")
    #expect(file.length == content.count)
    #expect(try readAll(file) == content)
    #expect(abs(file.timestamp.timeIntervalSince(date)) < 1)
}

@Test func writeAndReadNestedDirectories() throws {
    let zipData = try makeZipData { writer in
        try writer.addDirectory(named: "docs")
        try writer.withFile(named: "docs/readme.txt") { write in
            try writeChunks(write, Data("readme".utf8))
        }
        try writer.withFile(named: "docs/sub/deep.txt") { write in
            try writeChunks(write, Data("deep".utf8))
        }
        try writer.withFile(named: "top.txt") { write in
            try writeChunks(write, Data("top".utf8))
        }
    }

    let reader = try ZipFileReader(source: ZipFileDataSource(data: zipData))

    #expect(reader.directoryExists(atPath: "docs"))
    #expect(reader.directoryExists(atPath: "docs/sub"))  // implicitly created, no addDirectory call
    #expect(reader.fileExists(atPath: "docs/readme.txt"))
    #expect(reader.fileExists(atPath: "docs/sub/deep.txt"))
    #expect(reader.fileExists(atPath: "top.txt"))

    #expect(!reader.fileExists(atPath: "docs"))
    #expect(!reader.directoryExists(atPath: "top.txt"))
    #expect(!reader.fileExists(atPath: "nonexistent"))
    #expect(!reader.directoryExists(atPath: "nonexistent"))

    #expect(try readAll(reader.open(path: "docs/readme.txt")) == Data("readme".utf8))
    #expect(try readAll(reader.open(path: "docs/sub/deep.txt")) == Data("deep".utf8))
    #expect(try readAll(reader.open(path: "top.txt")) == Data("top".utf8))
}

@Test func emptyFileRoundTrips() throws {
    let zipData = try makeZipData { writer in
        try writer.withFile(named: "empty.txt") { _ in }
    }

    let reader = try ZipFileReader(source: ZipFileDataSource(data: zipData))
    let file = try reader.open(path: "empty.txt")
    #expect(file.length == 0)
    #expect(try readAll(file).isEmpty)
}

@Test func largeCompressibleFileRoundTrips() throws {
    // Bigger than the writer/reader's internal 64KB buffers, to exercise
    // multiple compress/flush and refill/inflate cycles.
    let content = Data(repeating: 0x41, count: 500_000)

    let zipData = try makeZipData { writer in
        try writer.withFile(named: "big.txt") { write in
            try writeChunks(write, content, chunkSize: 16384)
        }
    }

    let reader = try ZipFileReader(source: ZipFileDataSource(data: zipData))
    let file = try reader.open(path: "big.txt")
    #expect(file.length == content.count)
    #expect(try readAll(file) == content)
}

@Test func largeIncompressibleFileRoundTrips() throws {
    let content = pseudoRandomData(count: 300_000)

    let zipData = try makeZipData { writer in
        try writer.withFile(named: "random.bin") { write in
            try writeChunks(write, content, chunkSize: 4096)
        }
    }

    let reader = try ZipFileReader(source: ZipFileDataSource(data: zipData))
    let file = try reader.open(path: "random.bin")
    #expect(try readAll(file) == content)
}

@Test func multipleFilesInOneArchiveAreIndependentlyReadable() throws {
    let files: [(name: String, content: String)] = [
        ("one.txt", "first file"),
        ("two.txt", "second file, a bit longer than the first"),
        ("three.txt", ""),
    ]

    let zipData = try makeZipData { writer in
        for entry in files {
            try writer.withFile(named: entry.name) { write in
                try writeChunks(write, Data(entry.content.utf8))
            }
        }
    }

    let reader = try ZipFileReader(source: ZipFileDataSource(data: zipData))
    for entry in files {
        let file = try reader.open(path: entry.name)
        #expect(try readAll(file) == Data(entry.content.utf8))
    }
}

@Test func unicodeFileNamesRoundTrip() throws {
    let name = "café/☃snowman.txt"
    let content = Data("frozen".utf8)

    let zipData = try makeZipData { writer in
        try writer.withFile(named: name) { write in
            try writeChunks(write, content)
        }
    }

    let reader = try ZipFileReader(source: ZipFileDataSource(data: zipData))
    #expect(reader.directoryExists(atPath: "café"))
    #expect(reader.fileExists(atPath: name))
    #expect(try readAll(reader.open(path: name)) == content)
}

@Test func archiveAndFileCommentsRoundTrip() throws {
    let zipData = try makeZipData(comment: "archive comment") { writer in
        try writer.withFile(named: "a.txt", comment: "file comment") { write in
            try writeChunks(write, Data("a".utf8))
        }
    }

    let reader = try ZipFileReader(source: ZipFileDataSource(data: zipData))
    #expect(reader.comment == "archive comment")
    #expect(reader.item(at: "a.txt")?.comment == "file comment")
}

@Test func streamingNonSeekableWriterRoundTrips() throws {
    let sink = StreamingSink()
    let writer = ZipFileWriter(sink: sink)
    let content = Data(repeating: 0x5a, count: 200_000)

    try writer.withFile(named: "stream.bin") { write in
        try writeChunks(write, content, chunkSize: 8192)
    }
    try writer.addDirectory(named: "streamed-dir")
    try writer.close()

    let reader = try ZipFileReader(source: ZipFileDataSource(data: sink.data))
    #expect(try readAll(reader.open(path: "stream.bin")) == content)
    #expect(reader.directoryExists(atPath: "streamed-dir"))
}

// MARK: - Reader error paths

@Test func openingMissingFileThrowsFileNotFound() throws {
    let zipData = try makeZipData { writer in
        try writer.withFile(named: "a.txt") { write in
            try writeChunks(write, Data("a".utf8))
        }
    }
    let reader = try ZipFileReader(source: ZipFileDataSource(data: zipData))

    do {
        _ = try reader.open(path: "missing.txt")
        Issue.record("expected fileNotFound to be thrown")
    } catch ZipFileError.fileNotFound(let path) {
        #expect(path == "missing.txt")
    }
}

@Test func openingDirectoryAsFileThrows() throws {
    let zipData = try makeZipData { writer in
        try writer.addDirectory(named: "docs")
    }
    let reader = try ZipFileReader(source: ZipFileDataSource(data: zipData))

    do {
        _ = try reader.open(path: "docs")
        Issue.record("expected itemIsADirectory to be thrown")
    } catch ZipFileError.itemIsADirectory(let path) {
        #expect(path == "docs")
    }
}

@Test func unsupportedCompressionMethodThrowsOnOpen() throws {
    var zipData = try makeZipData { writer in
        try writer.withFile(named: "a.bin") { write in
            try writeChunks(write, Data(repeating: 1, count: 100))
        }
    }

    // Corrupt the compression method recorded in the central directory entry
    // (the local header is left untouched, since `open` trusts the central
    // directory's copy).
    let entryOffset = offsetOfCentralDirectoryEntry(in: zipData)
    zipData[entryOffset + 10] = 99
    zipData[entryOffset + 11] = 0

    let reader = try ZipFileReader(source: ZipFileDataSource(data: zipData))
    do {
        _ = try reader.open(path: "a.bin")
        Issue.record("expected unsupportedCompression to be thrown")
    } catch ZipFileError.unsupportedCompression(let path) {
        #expect(path == "a.bin")
    }
}

@Test func emptyDataThrowsNoCentralDirectory() throws {
    do {
        _ = try ZipFileReader(source: ZipFileDataSource(data: Data()))
        Issue.record("expected noCentralDirectory to be thrown")
    } catch ZipFileError.noCentralDirectory {
        // expected
    }
}

@Test func minimalEmptyArchiveReadsWithNoEntries() throws {
    let data = buildCentralDirectoryOnlyZip(entries: [])
    #expect(data.count == 22)  // a bare end-of-central-directory record

    let reader = try ZipFileReader(source: ZipFileDataSource(data: data))
    #expect(reader.comment == nil)
    #expect(!reader.fileExists(atPath: "anything"))
    #expect(!reader.directoryExists(atPath: "anything"))
}

@Test func unsupportedVersionThrows() throws {
    let data = buildCentralDirectoryOnlyZip(
        entries: [(name: "a.txt", requiredVersion: 63, flags: 0, compression: 0)])

    do {
        _ = try ZipFileReader(source: ZipFileDataSource(data: data))
        Issue.record("expected unsupportedVersion to be thrown")
    } catch ZipFileError.unsupportedVersion(let version) {
        #expect(version == 63)
    }
}

@Test func duplicateEntryThrows() throws {
    let data = buildCentralDirectoryOnlyZip(entries: [
        (name: "dup.txt", requiredVersion: 20, flags: 0, compression: 0),
        (name: "dup.txt", requiredVersion: 20, flags: 0, compression: 0),
    ])

    do {
        _ = try ZipFileReader(source: ZipFileDataSource(data: data))
        Issue.record("expected duplicateEntry to be thrown")
    } catch ZipFileError.duplicateEntry(let name) {
        #expect(name == "dup.txt")
    }
}

// MARK: - Zip64 support

private struct ZipDirEntrySpec {
    var name: String
    var requiredVersion: UInt16 = 20
    var flags: UInt16 = 0
    var compression: UInt16 = 0
    var compressedSize: UInt32 = 0
    var uncompressedSize: UInt32 = 0
    var diskNumberStart: UInt16 = 0
    var localHeaderOffset: UInt32 = 0
    var extra: Data = Data()
}

private func appendU16(_ v: UInt16, to data: inout Data) {
    withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) }
}
private func appendU32(_ v: UInt32, to data: inout Data) {
    withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) }
}
private func appendU64(_ v: UInt64, to data: inout Data) {
    withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) }
}

/// Hand-builds a central directory (no EOCD) from entries that may carry
/// explicit sizes/offset/disk-start and arbitrary extra-field bytes, for
/// testing Zip64 extra-field parsing.
private func buildZip64CentralDirectory(entries: [ZipDirEntrySpec]) -> Data {
    var cd = Data()
    for entry in entries {
        let nameBytes = Array(entry.name.utf8)
        appendU32(0x0201_4b50, to: &cd)  // central directory entry signature
        appendU16(20, to: &cd)  // version made by
        appendU16(entry.requiredVersion, to: &cd)
        appendU16(entry.flags, to: &cd)
        appendU16(entry.compression, to: &cd)
        appendU32(0, to: &cd)  // dos time
        appendU32(0, to: &cd)  // crc32
        appendU32(entry.compressedSize, to: &cd)
        appendU32(entry.uncompressedSize, to: &cd)
        appendU16(UInt16(nameBytes.count), to: &cd)
        appendU16(UInt16(entry.extra.count), to: &cd)
        appendU16(0, to: &cd)  // comment length
        appendU16(entry.diskNumberStart, to: &cd)
        appendU16(0, to: &cd)  // internal attributes
        appendU32(0, to: &cd)  // external attributes
        appendU32(entry.localHeaderOffset, to: &cd)
        cd.append(contentsOf: nameBytes)
        cd.append(entry.extra)
    }
    return cd
}

/// Builds a 0x0001 Zip64 Extended Information extra field. Only the
/// supplied (non-nil) subfields are included, in the spec-mandated fixed
/// order: uncompressed size, compressed size, header offset, disk start.
private func zip64ExtraField(
    uncompressedSize: UInt64? = nil,
    compressedSize: UInt64? = nil,
    headerOffset: UInt64? = nil,
    diskStart: UInt32? = nil
) -> Data {
    var payload = Data()
    if let uncompressedSize { appendU64(uncompressedSize, to: &payload) }
    if let compressedSize { appendU64(compressedSize, to: &payload) }
    if let headerOffset { appendU64(headerOffset, to: &payload) }
    if let diskStart { appendU32(diskStart, to: &payload) }

    var field = Data()
    appendU16(0x0001, to: &field)
    appendU16(UInt16(payload.count), to: &field)
    field.append(payload)
    return field
}

/// Appends a standard EOCD record to `cd`, optionally preceded by a Zip64
/// EOCD record + locator carrying the true cdSize/cdOffset, in which case
/// the standard EOCD's own corresponding fields are sentineled.
private func appendEndOfCentralDirectory(to cd: Data, entryCount: Int, zip64: Bool) -> Data {
    var result = cd
    if zip64 {
        appendU32(0x0606_4b50, to: &result)  // Zip64 EOCD record signature
        appendU64(44, to: &result)  // size of remaining record
        appendU16(45, to: &result)  // version made by
        appendU16(45, to: &result)  // version needed to extract
        appendU32(0, to: &result)  // number of this disk
        appendU32(0, to: &result)  // disk with start of CD
        appendU64(UInt64(entryCount), to: &result)  // entries on this disk
        appendU64(UInt64(entryCount), to: &result)  // entries in total
        appendU64(UInt64(cd.count), to: &result)  // size of CD
        appendU64(0, to: &result)  // offset of start of CD

        appendU32(0x0706_4b50, to: &result)  // Zip64 EOCD locator signature
        appendU32(0, to: &result)  // disk with start of Zip64 EOCD
        appendU64(UInt64(cd.count), to: &result)  // offset of Zip64 EOCD record
        appendU32(1, to: &result)  // total number of disks
    }

    appendU32(0x0605_4b50, to: &result)  // EOCD signature
    appendU16(0, to: &result)  // disk number
    appendU16(0, to: &result)  // directory disk
    appendU16(zip64 ? 0xFFFF : UInt16(entryCount), to: &result)
    appendU16(zip64 ? 0xFFFF : UInt16(entryCount), to: &result)
    appendU32(zip64 ? 0xFFFF_FFFF : UInt32(cd.count), to: &result)
    appendU32(zip64 ? 0xFFFF_FFFF : 0, to: &result)  // cd offset (always 0 here)
    appendU16(0, to: &result)  // comment length
    return result
}

@Test func zip64ExtraFieldResolvesLargeSizesAndOffset() throws {
    let bigUncompressed: UInt64 = 5_000_000_000
    let bigCompressed: UInt64 = 4_000_000_000
    let bigOffset: UInt64 = 4_294_967_296  // one past UInt32.max

    let extra = zip64ExtraField(
        uncompressedSize: bigUncompressed, compressedSize: bigCompressed, headerOffset: bigOffset)

    let cd = buildZip64CentralDirectory(entries: [
        ZipDirEntrySpec(
            name: "big.bin", compressedSize: 0xFFFF_FFFF, uncompressedSize: 0xFFFF_FFFF,
            localHeaderOffset: 0xFFFF_FFFF, extra: extra)
    ])
    let data = appendEndOfCentralDirectory(to: cd, entryCount: 1, zip64: false)

    let reader = try ZipFileReader(source: ZipFileDataSource(data: data))
    #expect(reader.item(at: "big.bin")?.uncompressedSize == Int(bigUncompressed))
    #expect(reader.item(at: "big.bin")?.compressedSize == Int(bigCompressed))
    #expect(reader.item(at: "big.bin")?.headerOffset == Int(bigOffset))
}

@Test func zip64ArchiveLevelEocdIsUsedWhenStandardFieldsAreSentineled() throws {
    let cd = buildZip64CentralDirectory(entries: [
        ZipDirEntrySpec(name: "a.txt"), ZipDirEntrySpec(name: "b.txt"),
    ])
    let data = appendEndOfCentralDirectory(to: cd, entryCount: 2, zip64: true)

    let reader = try ZipFileReader(source: ZipFileDataSource(data: data))
    #expect(reader.fileExists(atPath: "a.txt"))
    #expect(reader.fileExists(atPath: "b.txt"))
}

@Test func zip64RecordBadSignatureThrows() throws {
    let cd = buildZip64CentralDirectory(entries: [ZipDirEntrySpec(name: "a.txt")])
    var data = appendEndOfCentralDirectory(to: cd, entryCount: 1, zip64: true)
    data[cd.count] = 0xFF  // corrupt the Zip64 EOCD record signature

    do {
        _ = try ZipFileReader(source: ZipFileDataSource(data: data))
        Issue.record("expected badZip64Record to be thrown")
    } catch ZipFileError.badZip64Record(let offset) {
        #expect(offset == cd.count)
    }
}

@Test func zip64ExtraFieldTooShortThrows() throws {
    var badField = Data()
    appendU16(0x0001, to: &badField)
    appendU16(4, to: &badField)  // claims 4 bytes, but a size subfield needs 8
    badField.append(contentsOf: [0, 0, 0, 0])

    let cd = buildZip64CentralDirectory(entries: [
        ZipDirEntrySpec(name: "a.txt", uncompressedSize: 0xFFFF_FFFF, extra: badField)
    ])
    let data = appendEndOfCentralDirectory(to: cd, entryCount: 1, zip64: false)

    do {
        _ = try ZipFileReader(source: ZipFileDataSource(data: data))
        Issue.record("expected badDirectoryEntry to be thrown")
    } catch ZipFileError.badDirectoryEntry {
        // expected
    }
}

@Test func zip64SentinelWithoutExtraFieldThrows() throws {
    let cd = buildZip64CentralDirectory(entries: [
        ZipDirEntrySpec(name: "a.txt", uncompressedSize: 0xFFFF_FFFF)  // no extra field at all
    ])
    let data = appendEndOfCentralDirectory(to: cd, entryCount: 1, zip64: false)

    do {
        _ = try ZipFileReader(source: ZipFileDataSource(data: data))
        Issue.record("expected badDirectoryEntry to be thrown")
    } catch ZipFileError.badDirectoryEntry {
        // expected
    }
}

// MARK: - Zip64 writer support

/// Reads a little-endian integer directly out of `data` at a given byte offset.
private func readLE<T: FixedWidthInteger>(_ data: Data, at offset: Int, as: T.Type) -> T {
    var value: T = 0
    withUnsafeMutableBytes(of: &value) { dest in
        for i in 0..<MemoryLayout<T>.size {
            dest[i] = data[data.startIndex + offset + i]
        }
    }
    return T(littleEndian: value)
}

/// Finds the first occurrence of `signature` in `data`, scanning forward from `start`.
private func firstOffset(of signature: [UInt8], in data: Data, from start: Int = 0) -> Int? {
    var index = data.startIndex + start
    while index <= data.endIndex - signature.count {
        if (0..<signature.count).allSatisfy({ data[index + $0] == signature[$0] }) {
            return index
        }
        index += 1
    }
    return nil
}

/// Feeds `totalCount` repetitions of `byte` to a `withFile` generator closure in
/// bounded chunks, without ever materializing the whole thing as one `Data`.
private func writeRepeatingByte(
    _ write: (RawSpan) throws -> Void,
    byte: UInt8,
    totalCount: Int,
    chunkSize: Int = 1 << 20
) throws {
    guard totalCount > 0 else { return }
    let allocated = min(chunkSize, totalCount)
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: allocated, alignment: 16)
    defer { buffer.deallocate() }
    buffer.initializeMemory(as: UInt8.self, repeating: byte)

    var remaining = totalCount
    while remaining > 0 {
        let n = min(allocated, remaining)
        if n == allocated {
            try write(buffer.bytes)
        } else {
            let rebased = UnsafeMutableRawBufferPointer(rebasing: buffer[0..<n])
            try write(rebased.bytes)
        }
        remaining -= n
    }
}

/// Reads an entire (potentially huge) all-zero `File` back in bounded chunks,
/// without ever materializing the whole thing as one `Data`. Compares each
/// chunk against a zero-filled reference in bulk (via `Data`'s optimized
/// equality), rather than a per-byte closure, since the latter is orders of
/// magnitude slower for multi-gigabyte content in a debug build.
private func verifyAllZero(_ file: ZipFileReader<ZipFileDataSource>.File, expectedLength: Int) throws {
    #expect(file.length == expectedLength)
    let chunkSize = 1 << 20
    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: chunkSize, alignment: 16)
    defer { buffer.deallocate() }
    let zeroChunk = Data(count: chunkSize)

    var totalRead = 0
    while totalRead < file.length {
        var span = OutputRawSpan(buffer: buffer, initializedCount: 0)
        try file.read(into: &span)
        if span.byteCount == 0 { break }
        let chunk = Data(bytesNoCopy: buffer.baseAddress!, count: span.byteCount, deallocator: .none)
        #expect(chunk == zeroChunk.prefix(span.byteCount))
        totalRead += span.byteCount
    }
    #expect(totalRead == expectedLength)
}

@Test func zip64DisabledIsByteIdenticalToBaseline() throws {
    let content = Data("some content".utf8)
    let zipData = try makeZipData { writer in  // allowZip64 defaults to false
        try writer.withFile(named: "a.txt") { write in
            try writeChunks(write, content)
        }
    }

    // Local header extra length must remain 9 (no reserved Zip64 slot).
    #expect(readLE(zipData, at: 28, as: UInt16.self) == 9)
    // No Zip64 EOCD locator anywhere (would only appear when needed).
    #expect(firstOffset(of: [0x50, 0x4b, 0x06, 0x07], in: zipData) == nil)

    let reader = try ZipFileReader(source: ZipFileDataSource(data: zipData))
    #expect(try readAll(reader.open(path: "a.txt")) == content)
}

@Test func zip64EnabledReservesTwentyByteLocalExtraField() throws {
    let content = Data("hi".utf8)
    let zipData = try makeZipData(allowZip64: true) { writer in
        try writer.withFile(named: "a.txt") { write in
            try writeChunks(write, content)
        }
    }

    let nameLength = Int(readLE(zipData, at: 26, as: UInt16.self))
    let extraLength = Int(readLE(zipData, at: 28, as: UInt16.self))
    #expect(extraLength == 29)

    // The UT timestamp block occupies the first 9 bytes of the extra field;
    // the reserved Zip64 block follows.
    let zip64TagOffset = 30 + nameLength + 9
    #expect(readLE(zipData, at: zip64TagOffset, as: UInt16.self) == 0x0001)
    #expect(readLE(zipData, at: zip64TagOffset + 2, as: UInt16.self) == 16)
    #expect(readLE(zipData, at: zip64TagOffset + 4, as: UInt64.self) == UInt64(content.count))
    #expect(readLE(zipData, at: zip64TagOffset + 12, as: UInt64.self) > 0)  // compressed size

    // The standard fields still hold the real (small) values, not sentinels,
    // since this file doesn't actually need Zip64.
    #expect(readLE(zipData, at: 22, as: UInt32.self) == UInt32(content.count))
    #expect(readLE(zipData, at: 18, as: UInt32.self) != 0xFFFF_FFFF)

    let reader = try ZipFileReader(source: ZipFileDataSource(data: zipData))
    #expect(try readAll(reader.open(path: "a.txt")) == content)
}

@Test func zip64EnabledNonSeekableUsesEightByteDescriptor() throws {
    let content = Data("hello streaming".utf8)
    let sink = StreamingSink()
    let writer = ZipFileWriter(sink: sink, allowZip64: true)
    try writer.withFile(named: "a.txt") { write in
        try writeChunks(write, content)
    }
    try writer.close()

    let zipData = sink.data
    let nameLength = Int(readLE(zipData, at: 26, as: UInt16.self))
    let extraLength = Int(readLE(zipData, at: 28, as: UInt16.self))
    #expect(extraLength == 29)

    // Standard local header size fields are always 0 for a data-descriptor entry.
    #expect(readLE(zipData, at: 18, as: UInt32.self) == 0)
    #expect(readLE(zipData, at: 22, as: UInt32.self) == 0)

    let dataStart = 30 + nameLength + extraLength
    guard let descriptorOffset = firstOffset(of: [0x50, 0x4b, 0x07, 0x08], in: zipData, from: dataStart)
    else {
        Issue.record("data descriptor not found")
        return
    }

    // The rest of the file is: this file's central directory entry (no
    // Zip64 needed, since it's small) + the standard EOCD (no comment, no
    // Zip64 needed, since there's only one small entry).
    let cdEntrySize = 46 + "a.txt".utf8.count + 9
    let eocdSize = 22
    let expectedDescriptorLength = zipData.count - (cdEntrySize + eocdSize) - descriptorOffset
    #expect(expectedDescriptorLength == 24)  // 4 sig + 4 crc + 8 + 8

    let reader = try ZipFileReader(source: ZipFileDataSource(data: zipData))
    #expect(try readAll(reader.open(path: "a.txt")) == content)
}

@Test func zip64EnabledRoundTripsFileAtUInt32MaxBoundarySeekable() throws {
    let size = Int(UInt32.max)
    let zipData = try makeZipData(allowZip64: true) { writer in
        try writer.withFile(named: "big.bin") { write in
            try writeRepeatingByte(write, byte: 0, totalCount: size)
        }
    }

    let reader = try ZipFileReader(source: ZipFileDataSource(data: zipData))
    try verifyAllZero(reader.open(path: "big.bin"), expectedLength: size)
}

@Test func zip64EnabledRoundTripsFileAtUInt32MaxBoundaryNonSeekable() throws {
    let size = Int(UInt32.max)
    let sink = StreamingSink()
    let writer = ZipFileWriter(sink: sink, allowZip64: true)
    try writer.withFile(named: "big.bin") { write in
        try writeRepeatingByte(write, byte: 0, totalCount: size)
    }
    try writer.close()

    let reader = try ZipFileReader(source: ZipFileDataSource(data: sink.data))
    try verifyAllZero(reader.open(path: "big.bin"), expectedLength: size)
}

@Test func zip64DisabledThrowsForFileAtUInt32MaxBoundary() throws {
    let size = Int(UInt32.max)
    let sink = ZipFileDataSink()
    let writer = ZipFileWriter(sink: sink)  // allowZip64 defaults to false

    do {
        try writer.withFile(named: "big.bin") { write in
            try writeRepeatingByte(write, byte: 0, totalCount: size)
        }
        Issue.record("expected fileTooLarge to be thrown")
    } catch ZipFileError.fileTooLarge(let name) {
        #expect(name == "big.bin")
    }
}

@Test func zip64EocdEmittedWhenEntryCountOverflows() throws {
    let sink = ZipFileDataSink()
    let writer = ZipFileWriter(sink: sink)

    for i in 0..<0xFFFF {
        writer.files.append(
            ZipFileWriter<ZipFileDataSink>.FileInfo(
                headerOffset: 0, name: "f\(i)", date: .now, comment: nil,
                crc32: 0, compressedSize: 0, uncompressedSize: 0))
    }
    try writer.close()

    let data = sink.data
    #expect(firstOffset(of: [0x50, 0x4b, 0x06, 0x06], in: data) != nil)

    guard let eocdOffset = firstOffset(of: [0x50, 0x4b, 0x05, 0x06], in: data) else {
        Issue.record("standard EOCD not found")
        return
    }
    #expect(readLE(data, at: eocdOffset + 8, as: UInt16.self) == 0xFFFF)  // entries on disk
    #expect(readLE(data, at: eocdOffset + 10, as: UInt16.self) == 0xFFFF)  // entries in total

    let reader = try ZipFileReader(source: ZipFileDataSource(data: data))
    #expect(reader.fileExists(atPath: "f0"))
    #expect(reader.fileExists(atPath: "f\(0xFFFF - 1)"))
}

@Test func zip64EocdEmittedWhenCentralDirectoryOffsetOverflows() throws {
    let sink = ZipFileDataSink()
    let writer = ZipFileWriter(sink: sink)

    let fakeOffset = Int(UInt32.max) + 100
    writer.bytesWritten = fakeOffset
    writer.files.append(
        ZipFileWriter<ZipFileDataSink>.FileInfo(
            headerOffset: 0, name: "f", date: .now, comment: nil,
            crc32: 0, compressedSize: 0, uncompressedSize: 0))
    try writer.close()

    let data = sink.data
    guard let zip64RecordOffset = firstOffset(of: [0x50, 0x4b, 0x06, 0x06], in: data) else {
        Issue.record("expected a Zip64 EOCD record")
        return
    }
    #expect(readLE(data, at: zip64RecordOffset + 48, as: UInt64.self) == UInt64(fakeOffset))

    guard let eocdOffset = firstOffset(of: [0x50, 0x4b, 0x05, 0x06], in: data) else {
        Issue.record("standard EOCD not found")
        return
    }
    #expect(readLE(data, at: eocdOffset + 16, as: UInt32.self) == 0xFFFF_FFFF)  // cd offset sentinel
}

// MARK: - Leading slash normalization

@Test func writerStripsLeadingSlash() throws {
    func storedName(_ zipData: Data, atLocalHeaderOffset offset: Int) -> Data {
        let nameLength = Int(readLE(zipData, at: offset + 26, as: UInt16.self))
        return zipData.subdata(in: (offset + 30)..<(offset + 30 + nameLength))
    }

    let zipData = try makeZipData { writer in
        try writer.withFile(named: "/foo.txt") { write in
            try writeChunks(write, Data("hi".utf8))
        }
        try writer.withFile(named: "bar.txt") { write in
            try writeChunks(write, Data("hi".utf8))
        }
        try writer.addDirectory(named: "/mydir")
    }

    #expect(storedName(zipData, atLocalHeaderOffset: 0) == Data("foo.txt".utf8))

    guard let secondOffset = firstOffset(of: [0x50, 0x4b, 0x03, 0x04], in: zipData, from: 4) else {
        Issue.record("expected a second local header")
        return
    }
    #expect(storedName(zipData, atLocalHeaderOffset: secondOffset) == Data("bar.txt".utf8))

    guard
        let thirdOffset = firstOffset(
            of: [0x50, 0x4b, 0x03, 0x04], in: zipData, from: secondOffset + 4)
    else {
        Issue.record("expected a third local header")
        return
    }
    // The trailing slash `addDirectory` adds is kept; only a leading one is stripped.
    #expect(storedName(zipData, atLocalHeaderOffset: thirdOffset) == Data("mydir/".utf8))

    let reader = try ZipFileReader(source: ZipFileDataSource(data: zipData))
    #expect(reader.fileExists(atPath: "foo.txt"))
    #expect(reader.fileExists(atPath: "bar.txt"))
    #expect(reader.directoryExists(atPath: "mydir"))
}

@Test func readerIgnoresLeadingSlashInEntryNames() throws {
    let data = buildCentralDirectoryOnlyZip(entries: [
        (name: "/foo.txt", requiredVersion: 20, flags: 0, compression: 0)
    ])

    let reader = try ZipFileReader(source: ZipFileDataSource(data: data))
    #expect(reader.fileExists(atPath: "foo.txt"))
    #expect(reader.fileExists(atPath: "/foo.txt"))  // leading slash in the query too
}

