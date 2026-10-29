/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

package enum PathParser {
    package typealias LinkAndArchiveID = (link: Substring, archiveID: Substring?)
    
    /// Splits a documentation link into its "link" and optional "archive ID"
    ///
    /// For example, an absolute link string like `"doc://com.example/ModuleName/SymbolName#HeaderName"` will be split into:
    /// ```
    /// (
    ///   link:      "/ModuleName/SymbolName#HeaderName",
    ///   archiveID: "com.example"
    /// )
    /// ```
    /// and and link string without an archiveID like `"doc:ModuleName/SymbolName#HeaderName"` will be split into:
    /// ```
    /// (
    ///   link:      "/ModuleName/SymbolName#HeaderName",
    ///   archiveID: nil
    /// )
    /// ```
    ///
    /// If you want to parser the link into its components you can pass it to ``/SwiftDocC/PathHierarchy/PathParser/parse(path:)``
    ///
    /// - Parameters:
    ///   - documentationLink: The documentation link string with a "doc:" prefix.
    /// - Returns: The split archive ID and link substrings; or `nil` if the documentation link string doesn't have a "doc:" prefix.
    package static func split(documentationLink: String) -> LinkAndArchiveID? {
        // Check if the string already has contiguous UTF8 storage and run a faster, more low-level implementation.
        let fastPath: LinkAndArchiveID?? = documentationLink.utf8.withContiguousStorageIfAvailable {
            let buffer = UnsafeRawBufferPointer($0)
            let count = buffer.count
            
            guard count > 4 /* "doc:" */, let pointer = buffer.baseAddress, pointer.hasASCIIPrefix("doc:") else {
                // If the string doesn't start with "doc:" it isn't a documentation link.
                return nil
            }
            var offset = 4
            
            guard count > 6, pointer.hasASCIIPrefix("//", byteOffset: offset) else {
                // If the string doesn't start with "doc://" it doesn't contain an archive ID and the rest of the string is the link.
                let index = documentationLink.utf8.index(documentationLink.startIndex, offsetBy: offset)
                return (link: documentationLink[index...], archiveID: nil)
            }
            offset &+= 2
            
            // We know that this is an absolute documentation link; with an archive ID, a "/" character, and a link:
            //
            //    doc://?????????/??????
            //          ╰───┬───╯╰──┬╌╌╌
            //         archiveID   link
            let archiveIDStartIndex = documentationLink.utf8.index(documentationLink.startIndex, offsetBy: offset)
            
            // To try to find the next "/" character---that separates the "archive ID" from the "link"---as fast as possible, we check 8 bytes at a time as long as we can.
            let slashSearchPattern: UInt64 = 0x01_01_01_01_01_01_01_01 &* UInt64( UInt8(ascii: "/") )
            while count &- 8 >= offset {
                let bytes = pointer.loadUnaligned(fromByteOffset: offset, as: UInt64.self)
                let isSlash = ByteMatches(bytes, slashSearchPattern)
                
                guard isSlash.hasMatches else {
                    offset &+= 8
                    continue
                }
                
                offset &+= isSlash.numberOfLeadingNonMatches
                
                // We found the separator between the archive ID and the link
                let index = documentationLink.utf8.index(documentationLink.startIndex, offsetBy: offset)
                return (link: documentationLink[index...], archiveID: documentationLink[archiveIDStartIndex..<index])
            }
            
            // If haven't found the "/" yet, we have to check the last few bytes one-by-one to avoid reading out-of-bounds.
            while count >= offset {
                guard pointer.load(fromByteOffset: offset, as: UInt8.self) == .init(ascii: "/") else {
                    offset &+= 1
                    continue
                }
                
                // We found the separator between the archive ID and the link
                let index = documentationLink.utf8.index(documentationLink.startIndex, offsetBy: offset)
                return (link: documentationLink[index...], archiveID: documentationLink[archiveIDStartIndex..<index])
            }
            
            // We reached the end of the text without finding the separator. This link is only an archive ID (with an empty link text).
            let index = documentationLink.endIndex
            return (link: documentationLink[index...], archiveID: documentationLink[archiveIDStartIndex..<index])
        }
        if let fastPath {
            return fastPath
        }
        
        // If the string didn't have contiguous UTF8 storage for some reason we fallback to a slower implementation.
        
        guard documentationLink.hasPrefix("doc:") else {
            // If the string doesn't start with "doc:" it isn't a documentation link
            return nil
        }
        
        var remaining = documentationLink.dropFirst(4 /* "doc:" */)
        guard remaining.hasPrefix("//") else {
            // If the string doesn't start with "doc://" it doesn't contain an archive ID and the rest of the string is the link
            return (link: remaining, archiveID: nil)
        }
        
        remaining = remaining.dropFirst(2)
        let index = remaining.firstIndex(of: "/") ?? remaining.endIndex
        
        return (link: remaining[index...], archiveID: remaining[..<index])
    }
}
