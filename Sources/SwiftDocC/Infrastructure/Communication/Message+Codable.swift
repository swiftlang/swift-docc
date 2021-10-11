/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension Message: Codable {
    
    enum CodingKeys: String, CodingKey {
        case type
        case data
        case identifier
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(MessageType.self, forKey: .type)
        self.identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
        
        self.data = try decodeDataIfPresent(for: type, from: container)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(type, forKey: .type)
        try container.encode(data, forKey: .data)
        try container.encode(identifier, forKey: .identifier)
    }
}

fileprivate func decodeDataIfPresent(
    for type: MessageType,
    from container: KeyedDecodingContainer<Message.CodingKeys>
) throws -> AnyCodable? {
    switch type {
    case .codeColors:
        return AnyCodable(try container.decodeIfPresent(CodeColors.self, forKey: .data))
    default:
        return AnyCodable(try container.decodeIfPresent(AnyCodable.self, forKey: .data))
    }
}
