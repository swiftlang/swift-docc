/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension DocumentationWorkspaceDataProvider where Self: FileSystemProvider {
    public func catalogs(options: CatalogDiscoveryOptions) throws -> [DocumentationCatalog] {
        return try catalogsInTree(fileSystem, options: options)
    }
    
    /// Recursively traverses the file system, searching for documentation catalogs.
    ///
    /// - Parameters:
    ///   - root: The directory in which to search for documentation catalogs.
    ///   - options: Configuration that controls how the provider discovers documentation catalogs.
    /// - Throws: A ``WorkspaceError`` if one of the found documentation catalog directories is an invalid documentation catalog.
    /// - Returns: A list of all the catalogs that the provider discovered in the file system.
    private func catalogsInTree(_ root: FSNode, options: CatalogDiscoveryOptions) throws -> [DocumentationCatalog] {
        var catalogs: [DocumentationCatalog] = []
        
        guard case .directory(let rootDirectory) = root else {
            preconditionFailure("Expected directory object at path '\(root.url.absoluteString)'.")
        }
        
        if DocumentationCatalogFileTypes.isDocumentationCatalog(rootDirectory.url) {
            catalogs.append(try createCatalog(rootDirectory, rootDirectory.children, options: options))
        } else {
            // Recursively descend when the current root directory isn't a documentation catalog.
            for child in rootDirectory.children {
                if case .directory = child {
                    try catalogs.append(contentsOf: catalogsInTree(child, options: options))
                }
            }
        }
        
        return catalogs
    }
    
    /// Creates a documentation catalog from the content in a given documentation catalog directory.
    /// - Parameters:
    ///   - directory: The documentation catalog directory.
    ///   - catalogChildren: The top-level files and directories in the documentation catalog directory.
    ///   - options: Configuration that controls how the provider discovers documentation catalogs.
    /// - Throws: A ``WorkspaceError`` if the content is an invalid documentation catalog or
    ///           a ``DocumentationCatalog/PropertyListError`` error if the catalog's Info.plist file is invalid.
    /// - Returns: The new documentation catalog.
    private func createCatalog(_ directory: FSNode.Directory, _ catalogChildren: [FSNode], options: CatalogDiscoveryOptions) throws -> DocumentationCatalog {
        let info: DocumentationCatalog.Info
        
        var infoPlistData: Data?
        if let infoPlistRef = findInfoPlist(catalogChildren) {
            infoPlistData = try contentsOfURL(infoPlistRef.url)
        }
        info = try DocumentationCatalog.Info(from: infoPlistData, catalogDiscoveryOptions: options)
        
        let markupFiles = findMarkupFiles(catalogChildren, recursive: true).map { $0.url }
        let miscResources = findNonMarkupFiles(catalogChildren, recursive: true).map { $0.url }
        let symbolGraphFiles = findSymbolGraphFiles(catalogChildren, recursive: true).map { $0.url } + options.additionalSymbolGraphFiles

        let customHeader = findCustomHeader(catalogChildren)?.url
        let customFooter = findCustomFooter(catalogChildren)?.url
        
        return DocumentationCatalog(info: info, symbolGraphURLs: symbolGraphFiles, markupURLs: markupFiles, miscResourceURLs: miscResources, customHeader: customHeader, customFooter: customFooter)
    }
    
    /// Performs a shallow search for the first Info.plist file in the given list of files and directories.
    /// - Parameter catalogChildren: The list of files and directories to check.
    /// - Returns: The first Info.plist file, or `nil` if none of the files is an Info.plist file.
    private func findInfoPlist(_ catalogChildren: [FSNode]) -> FSNode.File? {
        return catalogChildren.firstFile { DocumentationCatalogFileTypes.isInfoPlistFile($0.url) }
    }
    
    /// Finds all the symbol-graph files in the given list of files and directories.
    /// - Parameters:
    ///   - catalogChildren: The list of files and directories to check.
    ///   - recursive: If `true`, this function will recursively check the files of all directories in the array. If `false`, it will ignore all directories.
    /// - Returns: A list of all the symbol-graph files.
    private func findSymbolGraphFiles(_ catalogChildren: [FSNode], recursive: Bool) -> [FSNode.File] {
        return catalogChildren.files(recursive: recursive) { DocumentationCatalogFileTypes.isSymbolGraphFile($0.url) }
    }
    
    /// Finds all the markup files in the given list of files and directories.
    /// - Parameters:
    ///   - catalogChildren: The list of files and directories to check.
    ///   - recursive: If `true`, this function will recursively check the files of all directories in the array. If `false`, it will ignore all directories.
    /// - Returns: A list of all the markup files.
    private func findMarkupFiles(_ catalogChildren: [FSNode], recursive: Bool) -> [FSNode.File] {
        return catalogChildren.files(recursive: recursive) { DocumentationCatalogFileTypes.isMarkupFile($0.url) }
    }
    
    /// Finds all the non-markup files in the given list of files and directories.
    /// - Parameters:
    ///   - catalogChildren: The list of files and directories to check.
    ///   - recursive: If `true`, this function will recursively check the files of all directories in the array. If `false`, it will ignore all directories.
    /// - Returns: A list of all the non-markup files.
    private func findNonMarkupFiles(_ catalogChildren: [FSNode], recursive: Bool) -> [FSNode.File] {
        return catalogChildren.files(recursive: recursive) { !DocumentationCatalogFileTypes.isMarkupFile($0.url) }
    }

    private func findCustomHeader(_ catalogChildren: [FSNode]) -> FSNode.File? {
        return catalogChildren.firstFile { DocumentationCatalogFileTypes.isCustomHeader($0.url) }
    }

    private func findCustomFooter(_ catalogChildren: [FSNode]) -> FSNode.File? {
        return catalogChildren.firstFile { DocumentationCatalogFileTypes.isCustomFooter($0.url) }
    }
}

fileprivate extension Array where Element == FSNode {
    /// Returns the first file that matches a given predicate.
    /// - Parameter predicate: A closure that takes a file as its argument and returns a Boolean value indicating whether the file should be returned from this function.
    /// - Throws: Any error that the predicate closure raises.
    /// - Returns: The first file that matches the predicate.
    func firstFile(where predicate: (FSNode.File) throws -> Bool) rethrows -> FSNode.File? {
        for case .file(let file) in self where try predicate(file) {
            return file
        }
        return nil
    }
    
    /// Returns all the files that match s given predicate.
    /// - Parameters:
    ///   - recursive: If `true`, this function will recursively check the files of all directories in the array. If `false`, it will ignore all directories in the array.
    ///   - predicate: A closure that takes a file as its argument and returns a Boolean value indicating whether the file should be included in the returned array.
    /// - Throws: Any error that the predicate closure raises.
    /// - Returns: The first file that matches the predicate.
    func files(recursive: Bool, where predicate: (FSNode.File) throws -> Bool) rethrows -> [FSNode.File] {
        var matches: [FSNode.File] = []
        for node in self {
            switch node {
            case .directory(let directory):
                guard recursive else { break }
                try matches.append(contentsOf: directory.children.files(recursive: true, where: predicate))
            case .file(let file) where try predicate(file):
                matches.append(file)
            case .file:
                break
            }
        }
        
        return matches
    }
}

/// An issue discovering a catalog in a workspace.
enum WorkspaceError: DescribedError {
    /// The catalog was missing an Info.plist file.
    case missingInfoPlist(url: URL)
    /// The root element of the Info.plist file was an array rather than a dictionary.
    case notADictionaryAtRoot(url: URL)
    
    /// A plain-text representation of the error.
    var errorDescription: String {
        switch self {
        case .missingInfoPlist(let url):
            return "A catalog was found in the workspace at '\(url)' but it was missing an Info.plist."
        case .notADictionaryAtRoot(let url):
            return "A catalog was found in the workspace but its Info.plist at '\(url)' was not structured correctly: it contained a root array rather than a root dictionary."
        }
    }
}
