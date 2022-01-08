/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/


import XCTest
@testable import SwiftDocC
import SwiftDocCTestUtilities

final class SwiftLMDBTests: XCTestCase {
    var environment: LMDB.Environment!
    
    override func setUpWithError() throws {
        let tempURL = try createTemporaryDirectory()
        
        environment = try! LMDB.Environment(path: tempURL.path, maxDBs: 4, mapSize: 1024 * 1024 * 1024) // 1GB of mapSize
    }
    
    override func tearDown() {
        environment = nil
    }
    
    // MARK: Basic Tests
    
    func testVersion() {
        let version = LMDB.default.version
        
        // Ensure the LMDB library version is the expected one: 0.9.70
        XCTAssertEqual(version.description, "0.9.70")
    }
    
    // MARK: Test Writing
    
    func testWriteAndReadMultipleValues() throws {
        let database = try environment.openDatabase()
        
        let string = "value"
        let integer = 10
        let float = Float(1.0)
        let double = Double(2.0)
        let data = string.data(using: .utf8)!
        
        XCTAssertNoThrow(try database.put(key: "string", value: string))
        XCTAssertNoThrow(try database.put(key: "integer", value: integer))
        XCTAssertNoThrow(try database.put(key: "float", value: float))
        XCTAssertNoThrow(try database.put(key: "double", value: double))
        XCTAssertNoThrow(try database.put(key: "data", value: data))
        
        XCTAssertEqual(string, database.get(type: String.self, forKey: "string"))
        XCTAssertEqual(integer, database.get(type: Int.self, forKey: "integer"))
        XCTAssertEqual(float, database.get(type: Float.self, forKey: "float"))
        XCTAssertEqual(double, database.get(type: Double.self, forKey: "double"))
        XCTAssertEqual(data, database.get(type: Data.self, forKey: "data"))
    }

    func testWriteAndReadRecords() throws {
        let database = try environment.openDatabase()
        
        let records: [NavigatorIndex.Builder.Record] = [
            .init(nodeMapping: (1, "one"), curationMapping: ("one", 1), usrMapping: ("usr1", 1)),
            .init(nodeMapping: (2, "two"), curationMapping: ("two", 2), usrMapping: ("usr2", 2)),
            .init(nodeMapping: (3, "three"), curationMapping: ("three", 3), usrMapping: nil),
        ]
        XCTAssertNoThrow(try database.put(records: records))

        // Verify node mapping
        XCTAssertEqual("one", database.get(type: String.self, forKey: UInt32(1)))
        XCTAssertEqual("two", database.get(type: String.self, forKey: UInt32(2)))
        XCTAssertEqual("three", database.get(type: String.self, forKey: UInt32(3)))
        
        // Verify curation mapping
        XCTAssertEqual(1, database.get(type: UInt32.self, forKey: "one"))
        XCTAssertEqual(2, database.get(type: UInt32.self, forKey: "two"))
        XCTAssertEqual(3, database.get(type: UInt32.self, forKey: "three"))

        // Verify node mapping
        XCTAssertEqual(1, database.get(type: UInt32.self, forKey: "usr1"))
        XCTAssertEqual(2, database.get(type: UInt32.self, forKey: "usr2"))

    }

    func testWriteMultipleTimes() throws {
        let database = try environment.openDatabase()
        
        let key = "string"
        XCTAssertNoThrow(try database.put(key: key, value: "value1"))
        XCTAssertNoThrow(try database.put(key: key, value: "value2"))
        
        // Ensure an error is thrown when noOverwrite is used as flag.
        XCTAssertThrowsError(try database.put(key: key, value: "value3", flags: [.noOverwrite]), "Database is expected to throw when putting the same value with `.noOverwrite` flag.") { (error) in
            XCTAssertTrue(error is LMDB.Error)
            XCTAssertEqual(error as? LMDB.Error, LMDB.Error.keyExists)
        }
    }
    
    // MARK: Test Transactions
    
    func testSimpleTransaction() throws {
        let database = try environment.openDatabase()
        let txn = environment.transaction()
        
        // Begin a transaction.
        try txn.begin()
        
        for i in 0...5 {
            try txn.put(key: "value\(i)", value: i, in: database)
        }
        
        try txn.commit()
        
        // Assert transaction completed correctly.
        XCTAssertTrue(txn.completed)
        
        for i in 0...5 {
            let value = database.get(type: Int.self, forKey: "value\(i)")
            XCTAssertEqual(value, i)
        }
    }
    
    func testAbortTransaction() throws {
        let database = try environment.openDatabase()
        let txn = environment.transaction()
        
        // Begin a transaction.
        try txn.begin()
        
        for i in 0...5 {
            try txn.put(key: "value\(i)", value: i, in: database)
        }
        
        txn.abort()
        
        // Assert transaction completed correctly.
        XCTAssertTrue(txn.completed)
        
        for i in 0...5 {
            let value = database.get(type: Int.self, forKey: "value\(i)")
            XCTAssertNil(value)
        }
    }
    
    func testMultipleTransactions() throws {
        let database = try environment.openDatabase()
        let txn = environment.transaction()
        let otherTxn = environment.transaction(readOnly: true)
        
        // Begin transactions.
        try txn.begin()
        try otherTxn.begin()
        
        for i in 0...5 {
            try txn.put(key: "value\(i)", value: i, in: database)
        }
        
        for i in 0...5 {
            let value = otherTxn.get(type: Int.self, forKey: "value\(i)", from: database)
            XCTAssertNil(value)
        }
        
        try txn.commit()
        otherTxn.abort()
        
        // Assert transaction completed correctly.
        XCTAssertTrue(txn.completed)
        XCTAssertTrue(otherTxn.completed)
        
        for i in 0...5 {
            let value = database.get(type: Int.self, forKey: "value\(i)")
            XCTAssertEqual(value, i)
        }
    }
    
    // MARK: Test Custom Object
    func testCustomObject() throws {
        let database = try environment.openDatabase()
        
        let stub = JSONStub(id: 5, title: "This is a test.")
        
        let key = "object"
        XCTAssertNoThrow(try database.put(key: key, value: stub))
        
        let value = database.get(type: JSONStub.self, forKey: key)
        XCTAssertEqual(value, stub)
    }
    
    func testMultipleCustomObjects() throws {
        let database = try environment.openDatabase()
        
       for i in 0...1000 {
            let key = "object-\(i)"
            let stub = JSONStub(id: i, title: "This object has id: \(i).")
            XCTAssertNoThrow(try! database.put(key: key, value: stub))
        }
        
        for i in 0...1000 {
            let original = JSONStub(id: i, title: "This object has id: \(i).")
            let key = "object-\(i)"
            let result = database.get(type: JSONStub.self, forKey: key)
            XCTAssertEqual(result, original)
        }
    }
    
    func testMultipleCustomRawObjects() throws {
        let database = try environment.openDatabase()
        let txn = environment.transaction()
                
        try txn.begin()
        for i in 0...1000 {
            let key = "object-\(i)"
            let stub = RawStub(id: i, title: "This object has id: \(i).", type: "Raw")
            try! txn.put(key: key, value: stub, in: database)
        }
        try txn.commit()
                
        for i in 0...1000 {
            let original = RawStub(id: i, title: "This object has id: \(i).", type: "Raw")
            let key = "object-\(i)"
            let result = database.get(type: RawStub.self, forKey: key)
            XCTAssertEqual(result, original)
        }
    }
    
    func testArrayOfInt() throws {
#if !os(Linux) && !os(Android)
        let database = try environment.openDatabase()
        
        var array: [UInt32] = []
        var index: UInt32 = 1
        array.append(index)
        
        for _ in 0..<100 {
            let key = "array-\(index)"
            index += 1
            array.append(index)
            XCTAssertNoThrow(try database.put(key: key, value: array))
        }
            
        var value = database.get(type: Array<UInt32>.self, forKey: "array-8")
        XCTAssertEqual(value, [1,2,3,4,5,6,7,8,9])
        
        value = database.get(type: Array<UInt32>.self, forKey: "array-13")
        XCTAssertEqual(value, [1,2,3,4,5,6,7,8,9,10,11,12,13,14])
#endif
    }

    static var allTests = [
        ("testVersion", testVersion),
    ]
}

// MARK: - Custom Objects

struct JSONStub: LMDBData, Equatable, Codable {
    
    let id: Int
    let title: String
    
    init(id: Int, title: String) {
        self.id = id
        self.title = title
    }
    
    static func == (lhs: JSONStub, rhs: JSONStub) -> Bool {
        return lhs.id == rhs.id && lhs.title == rhs.title
    }
    
    public init?(data: UnsafeRawBufferPointer) {
        let data = Data.init(bytes: data.baseAddress!, count: data.count)
        self = try! JSONDecoder().decode(JSONStub.self, from: data)
    }

    public func read<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        let data = try! JSONEncoder().encode(self)
        return try data.read(body)
    }
    
}

struct RawStub: LMDBData, Equatable, Codable {
    
    let id: Int64
    let title: String
    let type: String
    
    init(id: Int, title: String, type: String) {
        self.id = Int64(id)
        self.title = title
        self.type = type
    }
    
    static func == (lhs: RawStub, rhs: RawStub) -> Bool {
        return lhs.id == rhs.id && lhs.title == rhs.title && lhs.type == rhs.type
    }
    
    public init?(data: UnsafeRawBufferPointer) {
        let d = Data.init(bytes: data.baseAddress!, count: data.count)
        
        var cursor: Int = 0
        let length = MemoryLayout<Int64>.stride
        let id = d[cursor..<cursor + length].withUnsafeBytes { $0.load(as: Int64.self) }
        cursor += length
        
        let titleLength = d[cursor..<cursor + length].withUnsafeBytes{ $0.load(as: Int64.self) }
        cursor += length
        
        let typeLength = d[cursor..<cursor + length].withUnsafeBytes { $0.load(as: Int64.self) }
        cursor += length
        
        let titleData = d[cursor..<cursor + Int(titleLength)]
        cursor += Int(titleLength)
        
        let typeData = d[cursor..<cursor + Int(typeLength)]
        
        self.init(id: Int(id), title: String(data: Data(titleData), encoding: .utf8)!, type: String(data: Data(typeData), encoding: .utf8)!)
    }

    public func read<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        var data = Data()
        
        let idData = withUnsafeBytes(of: id) { return Data($0) }
        data.append(idData)
        
        let titleLength = withUnsafeBytes(of: Int64(title.utf8.count)) { return Data($0) }
        data.append(titleLength)
        
        let typeLength = withUnsafeBytes(of: Int64(type.utf8.count)) { return Data($0) }
        data.append(typeLength)
        
        data.append(Data(title.utf8))
        data.append(Data(type.utf8))
        
        return try data.read(body)
    }
    
}
