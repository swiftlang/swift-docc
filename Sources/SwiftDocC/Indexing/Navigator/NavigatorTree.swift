/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Defines an object that can be represented as raw Data and therefore serialized to/deserialized from disk.
public protocol Serializable: LMDBData, RawRepresentable where RawValue == Data {}

/**
 A `NavigatorTree` is a class holding information about a tree of data that can be navigated using a tree navigator.
 
 A tree is a data structure containing a number of nodes equal or greater than 1. Each node can have multiple children, but only
 one parent and assigning the same node as children of multiple nodes results in a broken data structure. There's no validation
 when adding a node as children to another node.
 
 A tree can get serialized to the disk using the following structure:
 ```
 ┌──────────────┬──────────────┬──────────────────────┐
 │   parentID   │ objectLength │        object        │
 │    UInt32    │    UInt32    │         Data         │
 │  (4 bytes)   │  (4 bytes)   │   (variable size)    │
 └──────────────┴──────────────┴──────────────────────┘
 ```

 The object needs to be conforming to `Serializable` so it can be transformed to raw data and reconstructed back using the same one.
 
 - Note: The `parentID` might be missing if the object is the root, but to avoid creating an exception on the the object structure, its id is set to 0.
 */
public class NavigatorTree {
    
    public enum Error: DescribedError {
        
        /// The navigator tree can't open the file.
        case cannotOpenFile(path: String)

        /// The navigator tree can't create the file.
        case cannotCreateFile(path: String)
        
        /// The navigator tree found invalid data to read.
        case invalidData
        
        public var errorDescription: String {
            switch self {
            case .cannotOpenFile(let path):
                return "Cannot open the file: \(path)"
            case .cannotCreateFile(let path):
                return "Cannot create the file: \(path)"
            case .invalidData:
                return "The serialized data is not a valid navigator node or tree."
            }
        }
    }
    
    /// The root node of the tree.
    public private(set) var root: Node
    
    /// A map holding the mapping from topicIdentifier to the node.
    /// - Note: This has been deprecated as the mapping is expensive to build and the path for creating
    ///         a `ResolvedTopicReference` is not served by the navigator item anymore.
    @available(*, deprecated)
    public private(set) var identifierToNode: [ResolvedTopicReference: Node] = [:]
    
    /// A map holding the mapping from node to the topicIdentifier.
    /// - Note: This has been deprecated as the mapping is expensive to build and the path for creating
    ///         a `ResolvedTopicReference` is not served by the navigator item anymore.
    @available(*, deprecated)
    public private(set) var nodeToIdentifier: [Node: ResolvedTopicReference] = [:]
    
    /// A map holding the mapping from  the numeric identifier to the node.
    public private(set) var numericIdentifierToNode: [UInt32: Node] = [:]
    
    /**
     Initialize a navigator tree with a given root node.
     
     - Parameters:
        - root: The root node of the tree.
        - numericIdentifierToNode: A dictionary containing the mapping from the internal numeric identifier to a node.
     */
    public init(root: Node, numericIdentifierToNode: [UInt32: Node] = [:]) {
        self.root = root
        self.numericIdentifierToNode = numericIdentifierToNode
    }
    
    /**
     Initialize an empty NavigatorTree with a placeholder root.
     */
    public init() {
        // This is a placeholder
        self.root = NavigatorTree.rootNode(bundleIdentifier: NavigatorIndex.UnknownBundleIdentifier)
    }
    
    // Internal class for reading content from disk.
    internal class ReadingCursor {
        let data: Data
        
        var index: UInt32 = 0
        var cursor = 0
        
        init(data: Data) {
            self.data = data
        }
    }
    
    /// The broadcast callback notifies a listener about the latest items loaded from the disk.
    public typealias BroadcastCallback = (_ items: [NavigatorTree.Node], _ isCompleted: Bool, _ error: Error?) -> Void
    
    // A reference to the reading cursor.
    internal var readingCursor: ReadingCursor? = nil
    
    /**
     Read a tree from disk from a given path.
     The read is atomically performed, which means it reads all the content of the file from the disk and process the tree from loaded data.
     
     - Parameters:
        - url: The file URL from which the tree should be read.
        - bundleIdentifier: The bundle identifier used to generate the mapping topicID to node on tree.
        - interfaceLanguages: A set containing the indication about the interface languages a tree contains.
        - timeout: The amount of time we can load a batch of items from data, once the timeout time pass,
                   the reading process will reschedule asynchronously using the given queue.
        - delay: The delay to wait before schedule the next read. Default: 0.01 seconds.
        - queue: The queue to use.
        - presentationIdentifier: Defines if nodes should have a presentation identifier useful in presentation contexts.
        - broadcast: The callback to update get updates of the current process.
     */
    public func read(from url: URL, bundleIdentifier: String? = nil, interfaceLanguages: Set<InterfaceLanguage>, timeout: TimeInterval, delay: TimeInterval = 0.01, queue: DispatchQueue, presentationIdentifier: String? = nil, broadcast: BroadcastCallback?) throws {
        let data = try Data(contentsOf: url)
        let readingCursor = ReadingCursor(data: data)
        self.readingCursor = readingCursor
        
        func __read() {
            let deadline = DispatchTime.now() + timeout
            var processedNodes = [NavigatorTree.Node]()
            
            while readingCursor.cursor < readingCursor.data.count {
                let length = MemoryLayout<UInt32>.stride
                
                let parentID: UInt32 = unpackedValueFromData(data[readingCursor.cursor..<readingCursor.cursor + length])
                readingCursor.cursor += length
                
                let objectLength: UInt32 = unpackedValueFromData(data[readingCursor.cursor..<readingCursor.cursor + length])
                readingCursor.cursor += length
                
                // Not copying the data would EXC_BAD_ACCESS due to a problem in Swift 4.
                let objectData = data.subdata(in: readingCursor.cursor..<readingCursor.cursor + Int(objectLength))
                readingCursor.cursor += Int(objectLength)
                
                guard let item = NavigatorItem(rawValue: objectData) else {
                    broadcast?(processedNodes, false, Error.invalidData)
                    self.readingCursor = nil
                    break
                }
                
                let node = Node(item: item, bundleIdentifier: bundleIdentifier ?? "")
                node.id = UInt32(readingCursor.index)
                node.presentationIdentifier = presentationIdentifier
                
                let parent = self.numericIdentifierToNode[parentID]
                parent?.add(child: node)
                
                self.numericIdentifierToNode[readingCursor.index] = node
                processedNodes.append(node)
                readingCursor.index += 1
                
                if DispatchTime.now() > deadline {
                    queue.async(flags: .barrier) {
                        broadcast?(processedNodes, false, nil)
                    }
                    queue.asyncAfter(deadline: .now() + delay) {
                        __read()
                    }
                    break
                }
            }
            
            if readingCursor.cursor >= data.count {
                queue.async(flags: .barrier) {
                    broadcast?(processedNodes, true, nil)
                }
                self.readingCursor = nil
            }
        }
        
        __read()
        
        guard let root = self.numericIdentifierToNode[0] else {
            throw Error.invalidData
        }
        
        self.root = root
    }
        
    /**
     Serialize the node and descendants to the disk.
     Every node is written in order using a breath first approach, assigning to each node a virtual identifier in `UInt32` which is then used to identify the parent.
     The initial index is 0 and the root gets id 0 and parent id 0, so it can be easily recognized inside the serialized data and it's expected to be the first element.
     
     - Parameters:
        - url: The URL to the file in which the tree gets serialized.
        - writePaths: If true, writes the path component to disk.
        - callback: A block called each time after a node is written to the disk. If the nodes are N, the block is called N times.
     */
    public func write(to url: URL, writePaths: Bool = false, callback: ((Node) -> ())? = nil) throws {
        let path = url.path
        if FileManager.default.fileExists(atPath: path) {
            try FileManager.default.removeItem(at: url)
        }
        
        guard FileManager.default.createFile(atPath: path, contents: nil) else {
            throw Error.cannotCreateFile(path: path)
        }
        
        guard let fileHandler = FileHandle(forWritingAtPath: path) else {
            throw Error.cannotOpenFile(path: path)
        }
        defer { fileHandler.closeFile() }
        
        var queue = [Node]()
        queue.append(root)
        
        var index: UInt32 = 0
        while index < queue.count  {
            let node = queue[Int(index)]
            node.id = index
            numericIdentifierToNode[index] = node
            
            // In case the node has not a parent id, we still need to write an integer to preserve the object size
            // when writing it to the disk. In this case we write 0 as parent which indicates the object is the root of
            // the tree we are serializing.
            var parentID = node.parent?.id ?? 0
            
            let nodeItem = node.item
            let path = node.item.path // Preserve the path for later
            if !writePaths {
                nodeItem.path = "" // Empty path, so we save space and time while loading.
            }
            let data = nodeItem.rawValue
            var length = UInt32(data.count)
            
            let lengthData = Data(bytes: &length, count: MemoryLayout<UInt32>.stride)
            let parentIDData = Data(bytes: &parentID, count: MemoryLayout<UInt32>.stride)
            
            fileHandler.write(parentIDData)
            fileHandler.write(lengthData)
            fileHandler.write(data)
            
            if node.children.count > 0 {
                queue.append(contentsOf: node.children)
            }
            
            if !writePaths {
                nodeItem.path = path // restore the path after writing to disk
            }
            
            callback?(node)
            
            index += 1
        }
    }
    
    /**
     Read a tree from disk from a given path.
     There are two modes of reading content from the disk, atomically and non-atomically.
     Atomically reads all the content of the file from the disk and process the tree from loaded data.
     Non-atomically uses `FileHandle` to read the necessary chunks at time.
     
     - Parameters:
        - url: The file URL from which the tree should be read.
        - bundleIdentifier: The bundle identifier used to generate the mapping topicID to node on tree.
        - interfaceLanguages: A set containing the indication about the interface languages a tree contains.
        - atomically: Defines if the read should be atomic.
        - presentationIdentifier: Defines if nodes should have a presentation identifier useful in presentation contexts.
        - onNodeRead: An action to perform after reading a node. This allows clients to perform arbitrary actions on the node while it is being read from disk. This is useful for clients wanting to attach data to ``NavigatorTree/Node/attributes``.
     */
    static func read(
        from url: URL,
        bundleIdentifier: String? = nil,
        interfaceLanguages: Set<InterfaceLanguage>,
        atomically: Bool = true,
        presentationIdentifier: String? = nil,
        onNodeRead: ((NavigatorTree.Node) -> Void)? = nil
    ) throws -> NavigatorTree {
        let interfaceLanguageMap = Dictionary(uniqueKeysWithValues: interfaceLanguages.map{ ($0.mask, $0)})
        let path = url.path
        if atomically {
            return try readAtomically(
                from: path,
                bundleIdentifier: bundleIdentifier,
                interfaceLanguageMap: interfaceLanguageMap,
                presentationIdentifier: presentationIdentifier,
                onNodeRead: onNodeRead)
        }
        return try read(
            from: path,
            bundleIdentifier: bundleIdentifier,
            interfaceLanguageMap: interfaceLanguageMap,
            presentationIdentifier: presentationIdentifier,
            onNodeRead: onNodeRead)
    }
    
    /// Read a tree by loading the whole data into disk and then process the content.
    fileprivate static func readAtomically(
        from path: String,
        bundleIdentifier: String? = nil,
        interfaceLanguageMap: [InterfaceLanguage.ID: InterfaceLanguage],
        presentationIdentifier: String? = nil,
        onNodeRead: ((NavigatorTree.Node) -> Void)? = nil
    ) throws -> NavigatorTree {
        let fileUrl = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: fileUrl)
        
        var map = [UInt32: Node]()
        var index: UInt32 = 0
        var cursor = 0
        
        while cursor < data.count {
            let length = MemoryLayout<UInt32>.stride
            
            let parentID: UInt32 = unpackedValueFromData(data[cursor..<cursor + length])
            cursor += length
            
            let objectLength: UInt32 = unpackedValueFromData(data[cursor..<cursor + length])
            cursor += length
            
            // Not copying the data would EXC_BAD_ACCESS
            let objectData = data.subdata(in: cursor..<cursor + Int(objectLength))
            cursor += Int(objectLength)
            
            guard let item = NavigatorItem(rawValue: objectData) else {
                throw Error.invalidData
            }
            
            let node = Node(item: item, bundleIdentifier: bundleIdentifier ?? "")
            node.id = index
            node.presentationIdentifier = presentationIdentifier
            onNodeRead?(node)
            if let parent = map[parentID] {
                parent.add(child: node)
            }
            
            map[index] = node
            index += 1
        }
        
        guard let root = map[0] else {
            throw Error.invalidData
        }
        
        return NavigatorTree(root: root, numericIdentifierToNode: map)
    }
    
    /// Read a tree by using a FileHandle while reading chunks of data from disk.
    fileprivate static func read(
        from path: String,
        bundleIdentifier: String? = nil,
        interfaceLanguageMap: [InterfaceLanguage.ID: InterfaceLanguage],
        presentationIdentifier: String? = nil,
        onNodeRead: ((NavigatorTree.Node) -> Void)? = nil
    ) throws -> NavigatorTree {
        guard let fileHandler = FileHandle(forReadingAtPath: path) else {
            throw Error.cannotOpenFile(path: path)
        }
        
        var map = [UInt32: Node]()
        var index: UInt32 = 0
        
        while true {
            let length = MemoryLayout<UInt32>.stride
            var data = fileHandler.readData(ofLength: length)
            
            if data.count < 1 { break } // We don't have anything else to read.
            let parentID: UInt32 = unpackedValueFromData(data)
            
            data = fileHandler.readData(ofLength: length)
            let objectLength: UInt32 = unpackedValueFromData(data)
            
            data = fileHandler.readData(ofLength: Int(objectLength))
            guard let item = NavigatorItem(rawValue: data) else {
                throw Error.invalidData
            }
            
            let node = Node(item: item, bundleIdentifier: bundleIdentifier ?? "")
            node.id = index
            node.presentationIdentifier = presentationIdentifier
            onNodeRead?(node)
            if let parent = map[parentID] {
                parent.add(child: node)
            }
            
            map[index] = node
            index += 1
        }
        
        guard let root = map[0] else {
            throw Error.invalidData
        }
        
        return NavigatorTree(root: root, numericIdentifierToNode: map)
    }
    
    // MARK: - Node
    
    /**
     A representation of a node in the tree wrapping a `NavigatorItem`.
     The node holds the reference to children and parent for fast navigation.
     */
    public class Node: Hashable, Equatable {
                
        /// An id assigned by a process, for example to dump data into disk.
        public var id: UInt32?
        
        /// Bundle identifier.
        public var bundleIdentifier: String
        
        /// The wrapped `NavigatorItem`.
        public var item: NavigatorItem
        
        /// The children of the node.
        public var children: [Node] = []
        
        /// A weak link to the parent. Useful to fast navigate back up to the root.
        public weak var parent: Node? // link to the parent
        
        /// A value that can be used for identification purposes in presentation contexts.
        public var presentationIdentifier: String?
        
        /// Storage for additional information in the nodes.
        public var attributes: [String: Any] = [:]
        
        /// A value that can be used for disambiguation purposes in presentation contexts.
        @available(*, deprecated, message: "Use presentationIdentifier instead.")
        public var presentationDisambiguator: String? {
            get {
                return presentationIdentifier
            }
            set {
                presentationIdentifier = newValue
            }
        }

        /**
         Initialize a node with the given `NavigatorItem`.
         
         - Parameter item: The item to wrap inside the `Node` object.
         - Parameter bundleIdentifier: The bundle identifier of the item.
         */
        public init(item: NavigatorItem, bundleIdentifier: String) {
            self.item = item
            self.bundleIdentifier = bundleIdentifier
        }
        
        /**
         Add a child to the current node.
         
         - Parameter child:The child to add to the current node.
         - Note: It performs the side effect of setting the current node as child's parent.
         */
        public func add(child: Node) {
            children.append(child)
            child.parent = self
        }
        
        /**
         Counts the number of all the items from a given node, including the current node plus all the descendants.
         
         - Returns: The counted items.
         */
        public func countItems() -> Int {
            if children.count == 0 {
                return 1
            } else {
                var n = 1
                for child in children {
                    n += child.countItems()
                }
                return n
            }
        }
        
        /**
         Returns a node containing, in order, the elements of the tree that satisfy the given predicate.
         
         - Parameter isIncluded: A closure that takes an element of the node as its argument and returns a Boolean value indicating whether the element should be included in the returned tree.
         - Returns: A node of the elements that isIncluded allowed.
         - Note: The returned node contains a copy of the original ones.
         */
        public func filter(_ isIncluded: (NavigatorItem) -> Bool) -> Node? {
            guard isIncluded(self.item) else { return nil }
            let node = Node(item: item, bundleIdentifier: self.bundleIdentifier)
            children.forEach { (child) in
                if let child = child.filter(isIncluded) {
                    node.add(child: child)
                }
            }
            return node
        }
        
        /// Copy the current node and children to new instances preserving the node item.
        public func copy() -> NavigatorTree.Node {
            return _copy([])
        }
        
        /// Private version of the logic to copy the current node and children to new instances preserving the node item.
        /// - Parameter hierarchy: The set containing the parent items to avoid entering in an infinite loop.
        private func _copy(_ hierarchy: Set<NavigatorItem>) -> NavigatorTree.Node {
            let mirror = NavigatorTree.Node(item: item, bundleIdentifier: bundleIdentifier)
            guard !hierarchy.contains(item) else { return mirror } // Avoid to enter in an infity loop.
            var updatedHierarchy = hierarchy
            if let parentItem = parent?.item { updatedHierarchy.insert(parentItem) }
            children.forEach { (child) in
                let childCopy = child._copy(updatedHierarchy)
                mirror.add(child: childCopy)
            }
            return mirror
        }
        
        // MARK: Equatable and Hashable
        
        public static func == (lhs: NavigatorTree.Node, rhs: NavigatorTree.Node) -> Bool {
            return lhs.item == rhs.item && lhs.id == rhs.id
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(item)
            hasher.combine(id)
        }
    }
    
    /// Returns an instance of `NavigatorTree.Node` that can be used as root.
    /// - Note: The node has all the masks maxed to potentially include any subtree.
    public static func rootNode(bundleIdentifier: String) -> NavigatorTree.Node {
        let root = NavigatorItem(pageType: UInt8(NavigatorIndex.PageType.root.rawValue),
                                 languageID: InterfaceLanguage.any.mask,
                                 title: "[Root]",
                                 platformMask: Platform.Name.any.mask,
                                 availabilityID: 0)
        return Node(item: root, bundleIdentifier: bundleIdentifier)
    }
    
}

// MARK: - Utilities

extension NavigatorTree.Node
{
    /// Creates an array with the tree data formatted in a readable way.
    public func treeLines(_ nodeIndent: String = "", _ childIndent: String = "") -> [String]
    {
        let initial = [ nodeIndent + item.title ]
        let addition = children.enumerated().map { ($0 < children.count-1, $1) }
            .flatMap { $0 ? $1.treeLines("┣╸","┃ ") : $1.treeLines("┗╸","  ") }
            .map { childIndent + $0 }
        return initial + addition
    }
    
    /// Dumps the tree data into a `String` in a human readable way.
    public func dumpTree() -> String {
        return treeLines().joined(separator:"\n")
    }
}
