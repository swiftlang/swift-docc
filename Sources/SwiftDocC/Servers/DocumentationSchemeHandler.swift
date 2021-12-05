/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

#if canImport(WebKit)
import WebKit

@available(*, deprecated, renamed: "DocumentationSchemeHandler")
public typealias TopicReferenceSchemeHandler = DocumentationSchemeHandler
public class DocumentationSchemeHandler: NSObject {
    
    public typealias FallbackResponseHandler = (URLRequest) -> (URLResponse, Data)?
    
    // The schema to support the documentation.
    public static let scheme = "doc"
    public static var fullScheme: String {
        return "\(scheme)://"
    }
    
    /// Fallback handler is called if the response data is nil.
    public var fallbackHandler: FallbackResponseHandler?
    
    /// The `FileServer` instance for serving content.
    var fileServer: FileServer
    
    /// The default file provider to serve content from memory.
    var memoryProvider = MemoryFileServerProvider()
    
    /**
     Initializes a `DocumentationSchemeHandler` with content coming from a folder.
     */
    public init(withTemplateURL templateURL:URL) {
        fileServer = FileServer(baseURL: URL(string: DocumentationSchemeHandler.fullScheme)!)
        let templateProvider = FileSystemServerProvider(directoryPath: templateURL.path)!
        fileServer.register(provider: templateProvider)
        fileServer.register(provider: memoryProvider, subPath: "/data")
    }
    
    public override init() {
        fileServer = FileServer(baseURL: URL(string: DocumentationSchemeHandler.fullScheme)!)
        fileServer.register(provider: memoryProvider)
    }
    
    /// Adds the data to the FileServer.
    public func setData(data: [String: Data]) {
        memoryProvider.removeAllFiles()
        
        for (key, value) in data {
            memoryProvider.addFile(path: key, data: value)
        }
    }
    
    /// Set the template files of the renderer.
    public func setTemplate(files: [String: Data]) {
        for (key, value) in files {
            memoryProvider.addFile(path: key, data: value)
        }
    }
    
    /// Loads the template from an existing path on disk.
    public func loadTemplate(from path: String) {
        memoryProvider.addFiles(inFolder: path)
    }
    
    /// Returns a response to a given request.
    public func response(to request: URLRequest) -> (URLResponse, Data?) {
        var (response, data) = fileServer.response(to: request)
        if data == nil, let fallbackHandler = fallbackHandler,
            let (fallbackResponse, fallbackData) = fallbackHandler(request) {
            response = fallbackResponse
            data = fallbackData
        }
        return (response, data)
    }
}

// MARK: WKURLSchemeHandler protocol
extension DocumentationSchemeHandler: WKURLSchemeHandler {

    public func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let (response, data) = self.response(to: urlSchemeTask.request)
        urlSchemeTask.didReceive(response)
        if let data = data {
            urlSchemeTask.didReceive(data)
        }
        urlSchemeTask.didFinish()
    }
    
    public func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // TODO: add handler for a stop
    }

}

#endif
