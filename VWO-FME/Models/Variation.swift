/**
 * Copyright 2024-2025 Wingify Software Pvt. Ltd.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
/**
 * Represents a variation in VWO.
 *
 * This struct encapsulates information about a VWO variation, including its ID, key, name, weight,
 * start range variation, end range variation, variables, variations, and segments.
 */

struct Variation: Codable, Equatable {
    var id: Int?
    var key: String?
    var name: String?
    var ruleKey: String?
    var type: String?
    var weight: Double = 0.0
    var startRangeVariation: Int = 0
    var endRangeVariation: Int = 0
    var variables: [Variable] = []
    var variations: [Variation] = []    
    var segments: [String: CodableValue]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case key
        case name
        case ruleKey
        case type
        case weight
        case startRangeVariation
        case endRangeVariation
        case variables
        case variations
        case segments
    }
        
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        key = try container.decodeIfPresent(String.self, forKey: .key)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        ruleKey = try container.decodeIfPresent(String.self, forKey: .ruleKey)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        weight = try container.decodeIfPresent(Double.self, forKey: .weight) ?? 0.0
        startRangeVariation = try container.decodeIfPresent(Int.self, forKey: .startRangeVariation) ?? 0
        endRangeVariation = try container.decodeIfPresent(Int.self, forKey: .endRangeVariation) ?? 0
        variables = try container.decodeIfPresent([Variable].self, forKey: .variables) ?? []
        variations = try container.decodeIfPresent([Variation].self, forKey: .variations) ?? []
        segments = try container.decodeIfPresent([String: CodableValue].self, forKey: .segments)
        
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(key, forKey: .key)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(weight, forKey: .weight)
        try container.encodeIfPresent(startRangeVariation, forKey: .startRangeVariation)
        try container.encodeIfPresent(endRangeVariation, forKey: .endRangeVariation)
        try container.encodeIfPresent(variables, forKey: .variables)
        try container.encodeIfPresent(variations, forKey: .variations)
        try container.encodeIfPresent(segments, forKey: .segments)
    }
}

enum CodableValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case float(Float)
    case double(Double)
    case bool(Bool)
    case array([CodableValue])
    case dictionary([String: CodableValue])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Float.self) {
            self = .float(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([CodableValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: CodableValue].self) {
            self = .dictionary(value)
        } else {
            throw DecodingError.typeMismatch(CodableValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Type not supported"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        case .float(let value):
            try container.encode(value)
        }
    }
    
    func toJSONCompatible() -> Any {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .bool(let value):
            return value
        case .array(let value):
            return value.map { $0.toJSONCompatible() }
        case .dictionary(let value):
            return value.mapValues { $0.toJSONCompatible() }
        case .float(let value):
            return value
        }
    }
    
    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }
    
    var intValue: Int? {
        if case .int(let value) = self {
            return value
        }
        return nil
    }
    
    var doubleValue: Double? {
        if case .double(let value) = self {
            return value
        }
        return nil
    }
    
    var floatValue: Float? {
        if case .float(let value) = self {
            return value
        }
        return nil
    }
    
    var boolValue: Bool? {
        if case .bool(let value) = self {
            return value
        }
        return nil
    }
    
    var arrayValue: [CodableValue]? {
        if case .array(let value) = self {
            return value
        }
        return nil
    }
    
    var dictionaryValue: [String: CodableValue]? {
        if case .dictionary(let value) = self {
            return value
        }
        return nil
    }
}
