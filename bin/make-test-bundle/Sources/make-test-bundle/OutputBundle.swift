/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

let envURL = URL(fileURLWithPath: "/usr/bin/env")
extension String: Error {}

/// A bundle and its belonging documentation.
class OutputBundle {
    // MARK: Configuration
    
    let name = "TestFramework"
    let defaultImports = "import Foundation"
    
    let outputURL: URL
    let docsURL: URL
    let imagesURL: URL
    let sourceURL: URL

    let sizeFactor: UInt

    // MARK: Model
    var topLevelImages = WrappingEnumerator<ImageFile>()
    var topLevelProtocols = WrappingEnumerator<ProtocolNode>()
    var topLevelStructs = WrappingEnumerator<StructNode>()
    var topLevelEnums = WrappingEnumerator<EnumNode>()
    var topLevelFuns = WrappingEnumerator<MethodNode>()
    
    // MARK: Methods
    
    /// Initializes a new framework and a docs bundle.
    init(outputURL originalOutputURL: URL, sizeFactor: UInt) {
        self.outputURL = originalOutputURL.appendingPathComponent(name)
        self.docsURL = outputURL.appendingPathComponent("Docs.docc")
        self.imagesURL = docsURL.appendingPathComponent("images")
        self.sourceURL = outputURL.appendingPathComponent("Sources").appendingPathComponent(name)
        self.sizeFactor = sizeFactor
    }
    
    /// Creates the output folder and initializes a package inside.
    func createOutputDirectory() throws {
        // Create output folder.
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: false, attributes: nil)
        
        // Create docs folder
        try FileManager.default.createDirectory(at: docsURL, withIntermediateDirectories: false, attributes: nil)
        try FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: false, attributes: nil)
        
        // Initialize package
        try runTask(envURL, directory: outputURL, arguments: ["swift", "package", "init"])
    }
    
    /// Create the output bundle's content.
    func createContent() throws {
        // Images
        topLevelImages.items = try createImages(imagesURL: imagesURL)
        
        // Protocols
        topLevelProtocols.items = try createProtocols()
        try createDocExtensions(paths: topLevelProtocols.items.map({ $0.name }))
        
        // Structs
        topLevelStructs.items = try createStructs()
        try createDocExtensions(paths: topLevelStructs.items.map({ $0.name }))
        
        // Enums
        topLevelEnums.items = try createEnums()
        try createDocExtensions(paths: topLevelEnums.items.map({ $0.name }))
        
        // Functions
        topLevelFuns.items = try createFuncs()
        
        print("------------------")
        print("\(ImageFile.counter) images.")
        print("\(ProtocolNode.counter) protocols.")
        print("\(StructNode.counter) structs.")
        print("\(EnumNode.counter) enums.")
        print("\(MethodNode.counter) functions.")
        print("\(PropertyNode.counter) properties.")
        print("\(MarkupFile.counter) markup files.")
        print("------------------")
    }
    
    /// Creates markup files for the symbols with given paths.
    private func createDocExtensions(paths: [String]) throws {
        print("Creating documentation markup files.")
        var module = MarkupFile(kind: .docExt(name), bundle: self)
        try module.source().write(to: docsURL.appendingPathComponent(module.fileName), atomically: true, encoding: .utf8)
        
        for path in paths {
            var ext = MarkupFile(kind: .docExt("\(name)/\(path)"), bundle: self)
            try ext.source().write(to: docsURL.appendingPathComponent(ext.fileName), atomically: true, encoding: .utf8)

            for var supplemental in ext.collectedArticles {
                try supplemental.source().write(to: docsURL.appendingPathComponent(supplemental.fileName), atomically: true, encoding: .utf8)
            }
        }
    }

    private func createFuncs() throws -> [MethodNode] {
        print("Creating functions.")
        
        var result = [MethodNode]()
        for i in (0 ..< sizeFactor) {
            let fileURL = sourceURL.appendingPathComponent("Func\(i).swift")
            let file = SwiftFile(imports: defaultImports)
            file.append {
                let fun = MethodNode(kind: .instance, level: .public, bundle: self)
                result.append(fun)
                return fun.source()
            }
            try file.write(to: fileURL)
        }
        return result
    }

    private func createEnums() throws -> [EnumNode] {
        print("Creating enums.")
        
        var result = [EnumNode]()
        for i in (0 ..< sizeFactor) {
            let fileURL = sourceURL.appendingPathComponent("Enum\(i).swift")
            let file = SwiftFile(imports: defaultImports)
            file.append {
                let enumeration = EnumNode(nested: [.struct, .method], parentPath: "\(name)", bundle: self)
                result.append(enumeration)

                defer {
                    for var ext in enumeration.collectedExtensions {
                        try! ext.source().write(to: docsURL.appendingPathComponent(ext.fileName), atomically: true, encoding: .utf8)
                        for var supplemental in ext.collectedArticles {
                            try! supplemental.source().write(to: docsURL.appendingPathComponent(supplemental.fileName), atomically: true, encoding: .utf8)
                        }
                    }
                }
                return enumeration.source()
            }
            try file.write(to: fileURL)
        }
        return result
    }

    private func createStructs() throws -> [StructNode] {
        print("Creating structs.")
        
        var result = [StructNode]()
        for i in (0 ..< sizeFactor) {
            let fileURL = sourceURL.appendingPathComponent("Struct\(i).swift")
            let file = SwiftFile(imports: defaultImports)
            file.append {
                let structure = StructNode(nested: [.struct, .enum, .method, .property], implements: [topLevelProtocols.next(), topLevelProtocols.next()], parentPath: "\(name)", bundle: self)
                result.append(structure)
                
                defer {
                    for var ext in structure.collectedExtensions {
                        try! ext.source().write(to: docsURL.appendingPathComponent(ext.fileName), atomically: true, encoding: .utf8)
                        for var supplemental in ext.collectedArticles {
                            try! supplemental.source().write(to: docsURL.appendingPathComponent(supplemental.fileName), atomically: true, encoding: .utf8)
                        }
                    }
                }
                
                return structure.source()
            }
            try file.write(to: fileURL)
        }
        return result
    }

    private func createProtocols() throws -> [ProtocolNode] {
        print("Creating protocols.")
        
        var result = [ProtocolNode]()
        for i in (0 ..< sizeFactor) {
            let fileURL = sourceURL.appendingPathComponent("Protocol\(i).swift")
            let file = SwiftFile(imports: defaultImports)
            file.append {
                let proto = ProtocolNode(nested: [.method, .property], parentPath: "\(name)", bundle: self)
                result.append(proto)

                defer {
                    for var ext in proto.collectedExtensions {
                        try! ext.source().write(to: docsURL.appendingPathComponent(ext.fileName), atomically: true, encoding: .utf8)
                        for var supplemental in ext.collectedArticles {
                            try! supplemental.source().write(to: docsURL.appendingPathComponent(supplemental.fileName), atomically: true, encoding: .utf8)
                        }
                    }
                }
                
                var source = proto.source()
                source += proto.extension()
                return source
            }
            try file.write(to: fileURL)
        }
        return result
    }

    /// Creates image files in the given output folder.
    private func createImages(imagesURL: URL) throws -> [ImageFile] {
        print("Creating image files.")
        
        return try (0..<sizeFactor)
            .map { _ -> ImageFile in
                let image = ImageFile()
                let imageURL = imagesURL.appendingPathComponent(image.name)
                try image.write(to: imageURL)
                return image
            }
    }
    
    private let bytesInMB = 1048576
    
    func summary() -> String? {
        guard let enumerator = FileManager.default.enumerator(
                at: outputURL,
                includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
                options: .skipsHiddenFiles,
                errorHandler: nil) else { return nil }
            
        var bytes: UInt64 = 0
        var count = 0
        for case let url as URL in enumerator {
            count += 1
            bytes += UInt64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        
        let size = Double(bytes) / Double(bytesInMB)
        return String(format: "%i files (%.2fMB)", count, size)
    }
    
    func createSymbolGraph() throws {
        // Build the package
        print("Building \(name)...")
        try runTask(envURL, directory: outputURL, arguments: ["swift", "build"])
        
        // Find SDK path
        let sdkPath = try runTask(envURL, arguments: ["xcrun", "--sdk", "macosx", "--show-sdk-path"])

        let swiftInfo = try JSONDecoder().decode(
            SwiftTarget.self,
            from: try runTask(envURL, directory: outputURL, arguments: [
                "swiftc",
                "-print-target-info"
            ]).data(using: .utf8)!)
        
        // Extract the package symbol graph
        print("Extracting symbol graph...")
        try runTask(envURL, directory: outputURL, arguments: [
            "swift",
            "symbolgraph-extract",
            "-module-name",
            name,
            "-target",
            swiftInfo.target.triple,
            "-I",
            outputURL.path.appending("/.build/debug"),
            "-sdk",
            sdkPath,
            "-output-dir",
            docsURL.path
        ])
    }
    
    struct BundleInfoPlist: Encodable {
        let CFBundleName: String
        let CFBundleDisplayName: String
        let CFBundleIdentifier: String
        let CFBundleVersion: String
    }
    
    func createInfoPlist() throws {
        print("Creating Info.plist ...")
        let plist = BundleInfoPlist(CFBundleName: "TestFramework", CFBundleDisplayName: "TestFramework", CFBundleIdentifier: "org.swift.TestFramework", CFBundleVersion: "0.1.0")
        let data = try PropertyListEncoder().encode(plist)
        try data.write(to: docsURL.appendingPathComponent("Info.plist"))
    }
}

extension OutputBundle {
    @discardableResult
    fileprivate func runTask(_ url: URL, directory: URL? = nil, arguments: [String] = [], environment: [String: String] = [:]) throws -> String {

        let task = Process()
        task.currentDirectoryURL = directory
        task.executableURL = url
        task.arguments = arguments
        task.environment = ProcessInfo.processInfo.environment.merging(environment, uniquingKeysWith: +)
        let stdout = Pipe()
        task.standardOutput = stdout
        try task.run()
        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            throw "Exit status (\(task.terminationStatus)) \(task.terminationReason)"
        }
        
        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: outputData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
