/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import NIO
import NIOHTTP1
import SwiftDocC

fileprivate extension String {
    var fileExtension: String {
        return components(separatedBy: ".").last!.lowercased()
    }
}

private let imageType: (String) -> String = { name in
    switch name.fileExtension {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "svg": return "image/svg+xml"
        case "gif": return "image/gif"
        default: return "application/octet-stream"
    }
}

/// A model to parse a "Range" HTTP header.
struct RangeHeader {
    /// Lower range bound.
    let min: Int
    
    /// Upper range bound.
    let max: Int
    
    init?(_ string: String) {
        guard string.hasPrefix("bytes=") else {
            return nil
        }
        let bounds = string.dropFirst("bytes=".count).split(separator: "-")
        guard bounds.count == 2, let min = Int(bounds[0]), let max = Int(bounds[1]) else {
            return nil
        }
        self.min = min
        self.max = max
    }
}

/// A response handler that serves asset files.
struct FileRequestHandler: RequestHandlerFactory {
    let rootURL: URL
    let fileIO: NonBlockingFileIO

    /// Metadata that pairs file paths with content mime types.
    struct AssetFileMetadata {
        let folderPath: String
        let mimetype: (String) -> String
    }
    
    /// A list of predefined folder paths that are matched to expected content mime types.
    ///
    /// All asset locations the preview server is supposed to serve, along with
    /// a list of file and content types allowed in those locations.
    static let assets: [AssetFileMetadata] = [
        AssetFileMetadata(folderPath: "/data/", mimetype: { _ in "application/json" }),
        AssetFileMetadata(folderPath: "/index/", mimetype: { _ in "application/json" }),
        AssetFileMetadata(folderPath: "/css/", mimetype: { _ in "text/css" }),
        AssetFileMetadata(folderPath: "/js/", mimetype: { _ in "text/javascript" }),
        AssetFileMetadata(folderPath: "/fonts/", mimetype: { name in
            switch name.fileExtension {
                case "eot": return "application/vnd.ms-fontobject"
                case "otf": return "font/otf"
                case "woff": return "font/woff"
                case "woff2": return "font/woff2"
                default: return "application/octet-stream"
            }
        }),
        AssetFileMetadata(folderPath: "/images/", mimetype: imageType),
        AssetFileMetadata(folderPath: "/img/", mimetype: imageType),
        AssetFileMetadata(folderPath: "/videos/", mimetype: { name in
            switch name.fileExtension {
            case "mpg": return "video/mpg"
            case "m4", "mp4", "m4v": return "video/mp4"
            case "mov": return "video/quicktime"
            case "avi": return "video/x-msvideo"
            default: return "application/octet-stream"
            }
        }),
        AssetFileMetadata(folderPath: "/downloads/", mimetype: { name in
            switch name.fileExtension {
            case "zip": return "application/zip"
            default: return "application/octet-stream"
            }
        })
    ]
    
    struct TopLevelAssetFileMetadata {
        let filePath: String
        let mimetype: String
    }
    
    static let topLevelAssets = [
        TopLevelAssetFileMetadata(filePath: "/apple-logo.svg", mimetype: "image/svg+xml"),
        TopLevelAssetFileMetadata(filePath: "/favicon.ico", mimetype: "image/x-icon"),
        TopLevelAssetFileMetadata(filePath: "/theme-settings.js", mimetype: "text/javascript"),
        TopLevelAssetFileMetadata(filePath: "/theme-settings.json", mimetype: "application/json"),
    ]
    
    /// Returns a Boolean value that indicates whether the given path is located inside an asset folder.
    static func isAssetPath(_ path: String) -> Bool {
        return matchingAssetMetadata(path) != nil
            || matchingTopLevelAssetMetadata(path) != nil
    }
    
    private static func matchingAssetMetadata(_ path: String) -> AssetFileMetadata? {
        return assets.first(where: { metadata -> Bool in
            return path.unicodeScalars.starts(with: metadata.folderPath.unicodeScalars)
        })
    }
    
    private static func matchingTopLevelAssetMetadata(_ path: String) -> TopLevelAssetFileMetadata? {
        return topLevelAssets.first(where: { metadata -> Bool in
            return path == metadata.filePath
        })
    }
    
    func create<ChannelHandler: ChannelInboundHandler>(channelHandler: ChannelHandler) -> RequestHandler
        where ChannelHandler.OutboundOut == HTTPServerResponsePart {

            return { ctx, head in
                // Guards for a valid URL request
                guard let components = URLComponents(string: head.uri) else { throw RequestError(status: .badRequest) }
                
                // Guard that the path is authorized for serving assets
                let mimetype: String
                if let assetMetadata = FileRequestHandler.matchingAssetMetadata(components.path) {
                    mimetype = assetMetadata.mimetype(components.path)
                } else if let topLevelAssetMetadata = FileRequestHandler.matchingTopLevelAssetMetadata(components.path) {
                    mimetype = topLevelAssetMetadata.mimetype
                } else {
                    throw RequestError(status: .unauthorized)
                }
                
                let fileURL = self.rootURL.appendingPathComponent(components.path.removingLeadingSlash)

                // Discard requests to components starting with a period or referring to the user directory
                guard components.path.components(separatedBy: "/")
                    .allSatisfy({ !$0.hasPrefix(".") && $0 != "~" }) else { throw RequestError(status: .unauthorized) }

                var data: Data
                let totalLength: Int
                
                // Read the file contents
                do {
                    data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
                    totalLength = data.count
                } catch {
                    throw RequestError(status: .notFound)
                }

                // Add Range header if neccessary
                var headers = HTTPHeaders()
                let range = head.headers["Range"].first.flatMap(RangeHeader.init)
                if let range = range {
                    data = data.subdata(in: Range<Data.Index>(uncheckedBounds: (lower: range.min, upper: range.max+1)))
                    headers.add(name: "Content-Range", value: "bytes \(range.min)-\(range.max)/\(totalLength)")
                    headers.add(name: "Accept-Ranges", value: "bytes")
                }
                
                // Write the response to the output channel
                var content = ctx.channel.allocator.buffer(capacity: totalLength)
                content.writeBytes(data)

                headers.add(name: "Content-Length", value: "\(data.count)")
                headers.add(name: "Content-Type", value: mimetype)

                // No caching of live preview
                headers.add(name: "Cache-Control", value: "no-store, no-cache, must-revalidate, post-check=0, pre-check=0")
                headers.add(name: "Pragma", value: "no-cache")
                
                let responseHead = HTTPResponseHead(matchingRequestHead: head, status: range != nil ? .partialContent : .ok, headers: headers)
                
                ctx.write(channelHandler.wrapOutboundOut(.head(responseHead)), promise: nil)
                ctx.write(channelHandler.wrapOutboundOut(.body(.byteBuffer(content))), promise: nil)
            }
    }
}
