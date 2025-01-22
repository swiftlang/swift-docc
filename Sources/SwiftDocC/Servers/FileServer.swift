/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
#if os(Windows)
import WinSDK
#endif

fileprivate let slashCharSet = CharacterSet(charactersIn: "/")

/**
 FileServer is a struct simulating a web server behavior to serve files.
 It is useful to interface a custom schema with `WKWebView` via `WKURLSchemeHandler` or
 `WebView` via a custom `URLProtocol`.
 */
public class FileServer {
    
    /// The base URL of the server. Example: `http://www.example.com`.
    public let baseURL: URL
    
    /// The list of providers from which files are served.
    private var providers: [String: FileServerProvider] = [:]
    
    /**
     Initialize a FileServer instance with a base URL.
     - parameter baseURL: The base URL to use.
     */
    public init(baseURL: URL) {
        self.baseURL = baseURL.absoluteURL
    }
    
    
    
    /// Registers a `FileServerProvider` to a `FileServer` objects which can be used to provide content
    /// to a local web page served by local content.
    /// - Parameters:
    ///   - provider: An object conforming to `FileServerProvider`.
    ///   - subPath: The sub-path in which the `FileServerProvider` will be queried for content.
    /// - Returns: A boolean indicating if the registration succeeded or not.
    @discardableResult
    public func register(provider: FileServerProvider, subPath: String = "/") -> Bool {
        guard !subPath.isEmpty else { return false }
        let trimmed = subPath.trimmingCharacters(in: slashCharSet)
        providers[trimmed] = provider
        return true
    }
    
    /**
     Returns the data for a given URL.
     */
    public func data(for url: URL) -> Data? {
        let providerKey = providers.keys.sorted { (l, r) -> Bool in
            l.count > r.count
            }.filter { (path) -> Bool in
                return url.path.trimmingCharacters(in: slashCharSet).hasPrefix(path)
            }.first ?? "" //in case missing an exact match, get the root one
        guard let provider = providers[providerKey] else {
            fatalError("A provider has not been passed to a FileServer.")
        }
        return provider.data(for: url.path.trimmingCharacters(in: slashCharSet).removingPrefix(providerKey))
    }
    
    /**
     Returns a tuple with a response and the given data.
     - Parameter request: The request coming from a web client.
     - Returns: The response and data which are going to be served to the client.
     */
    public func response(to request: URLRequest) -> (URLResponse, Data?) {
        guard let url = request.url else {
            return (HTTPURLResponse(url: baseURL, statusCode: 400, httpVersion: "HTTP/1.1", headerFields: nil)!, nil)
        }
        var data: Data? = nil
        let response: URLResponse
        
        let mimeType: String

        // We need to make sure that the path extension is for an actual file and not a symbol name which is a false positive
        // like: "'...(_:)-6u3ic", that would be recognized as filename with the extension "(_:)-6u3ic". (rdar://71856738)
        if url.pathExtension.isAlphanumeric && !url.lastPathComponent.isSwiftEntity {
            data = self.data(for: url)
            mimeType = FileServer.mimeType(for: url.pathExtension)
        } else { // request is for a path, we need to fake a redirect here
            if url.pathComponents.isEmpty {
                xlog("Tried to load an invalid URL: \(url.absoluteString).\nFalling back to serve index.html.")
            }
            mimeType = "text/html"
            data = self.data(for: baseURL.appendingPathComponent("/index.html"))
        }
        
        if let data {
            response = URLResponse(url: url, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: nil)
        } else {
            response = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        }
        
        return (response, data)
    }
    
    /// Returns the MIME type based on file extension, best guess.
    internal static func mimeType(for ext: String) -> String {
        // RFC 2046 states in section 4.5.1:
        // The "octet-stream" subtype is used to indicate that a body contains arbitrary binary data.
        // https://stackoverflow.com/questions/1176022/unknown-file-type-mime
        let defaultMimeType = "application/octet-stream"
        
        #if os(macOS)
        
        return UTType(filenameExtension: ext)?.preferredMIMEType ?? defaultMimeType

        #elseif os(Windows)

        return ".\(ext)".withCString(encodedAs: UTF16.self) {
            var pwszMimeOut: UnsafeMutablePointer<WCHAR>?
            guard FindMimeFromData(nil, $0, nil, 0, nil, DWORD(FMFD_URLASFILENAME), &pwszMimeOut, 0) >= 0,
                    let pwszMimeOut else {
                return defaultMimeType
            }
            defer { CoTaskMemFree(pwszMimeOut) }
            return String(decodingCString: pwszMimeOut, as: UTF16.self)
        }

        #else
        
        let mimeTypes = [
            "html": "text/html",
            "htm": "text/html",
            "css": "text/css",
            "png": "image/png",
            "jpeg": "image/jpeg",
            "jpg": "image/jpeg",
            "svg": "image/svg+xml",
            "gif": "image/gif",
            "js": "application/javascript",
            "json": "application/json"]
        
        return mimeTypes[ext] ?? defaultMimeType
        
        #endif
    }
}


/**
 A protocol used for serving content to a `FileServer`. The data can then come from multiple sources such as:
 - disk
 - remote source
 - in memory storage
 
 This abstraction lets a `FileServer` provide content from multiple types of sources at the same time.
 */
public protocol FileServerProvider {
    /**
     Retrieve the data linked to a given path based on the `baseURL`.
     
     - parameter path: The path.
     - returns: The data matching the url, if possible.
     */
    func data(for path: String) -> Data?
}

public class FileSystemServerProvider: FileServerProvider {
    
    private(set) var directoryURL: URL
    
    public init?(directoryPath: String) {
        guard FileManager.default.directoryExists(atPath: directoryPath) else {
            return nil
        }
        self.directoryURL = URL(fileURLWithPath: directoryPath)
    }
    
    public func data(for path: String) -> Data? {
        let finalURL = directoryURL.appendingPathComponent(path)
        return try? Data(contentsOf: finalURL)
    }
    
}

public class MemoryFileServerProvider: FileServerProvider {
    
    /// Files to serve based on relative path.
    private var files = [String: Data]()
    
    public init() {}
    
    
    /// Add a file to the file server.
    ///
    /// - Parameters:
    ///   - path: The path to the file.
    ///   - data: The data for that file.
    /// - Returns: `true` if the file was added successfully.
    @discardableResult
    public func addFile(path: String, data: Data) -> Bool {
        guard !path.isEmpty else { return false }
        var trimmed = path.trimmingCharacters(in: slashCharSet)
        #if os(Windows)
        trimmed = trimmed.replacingOccurrences(of: #"/"#, with: #"\"#)
        #endif
        files[trimmed] = data
        return true
    }
    
    /// Retrieve the data that the server serves for the given path.
    ///
    /// - Parameter path: The path to a file served by the server.
    /// - Returns: The data for that file, if server by the server. Otherwise, `nil`.
    public func data(for path: String) -> Data? {
        var trimmed = path.trimmingCharacters(in: slashCharSet)
        #if os(Windows)
        trimmed = trimmed.replacingOccurrences(of: #"/"#, with: #"\"#)
        #endif
        return files[trimmed]
    }
    
    /// Adds files from the `source` directory to the `destination` directory in the file server.
    ///
    /// - Parameters:
    ///   - source: The source directory to add files from.
    ///   - destination: The destination directory in the file server to add the files to.
    ///   - recursive: Whether or not to recursively add files from the source directory.
    public func addFiles(inFolder source: String, inSubPath destination: String = "", recursive: Bool = true) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: source, isDirectory: &isDirectory) else { return }
        guard isDirectory.boolValue else { return }
        
        let trimmedSubPath = destination.trimmingCharacters(in: slashCharSet)
        let enumerator = FileManager.default.enumerator(atPath: source)!
        
        for file in enumerator {
            guard let file = file as? String else { fatalError("Enumerator returned an unexpected type.") }
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: source).appendingPathComponent(file)) else { continue }
            if recursive == false && file.contains("/") { continue } // skip if subfolder and recursive is disabled
            addFile(path: "/\(trimmedSubPath)/\(file)", data: data)
        }
    }
    
    /// Remove all files served by the server.
    public func removeAllFiles() {
        files.removeAll()
    }
    
    /// Removes all files served by the server matching a given subpath.
    ///
    /// - Parameter directory: The path to a directory to remove
    public func removeAllFiles(in directory: String) {
        var trimmed = directory.trimmingCharacters(in: slashCharSet)
        #if os(Windows)
        trimmed = trimmed.appending(#"\"#)
        #else
        trimmed = trimmed.appending(#"/"#)
        #endif
        for key in files.keys where key.hasPrefix(trimmed) {
            files.removeValue(forKey: key)
        }
    }
    
}

/// Checks whether the given string is a known entity definition which might interfere with the rendering engine while dealing with URLs.
fileprivate func isKnownEntityDefinition(_ identifier: String) -> Bool {
    return SymbolGraph.Symbol.KindIdentifier.isKnownIdentifier(identifier)
}

fileprivate extension String {
    
    /// Removes the prefix of a string.
    func removingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else { return self }
        return String(dropFirst(prefix.count))
    }


    /// Check that a given string is alphanumeric.
    var isAlphanumeric: Bool {
        return !self.isEmpty && self.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil
    }
    
    /// Check that a given string is a Swift entity definition.
    var isSwiftEntity: Bool {
        let swiftEntityPattern = #"(?<=\-)swift\..*"#
        if let range = range(of: swiftEntityPattern, options: .regularExpression, range: nil, locale: nil) {
            let entityCheck = String(self[range])
            return isKnownEntityDefinition(entityCheck)
        }
        return false
    }
}
