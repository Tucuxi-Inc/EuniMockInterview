import Foundation

enum ConfigurationError: Error {
    case missingKey
    case invalidValue
    case fileNotFound
}

class ConfigurationManager {
    static let shared = ConfigurationManager()
    
    private init() {}
    
    private var configuration: [String: String] {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "xcconfig") else {
            print("Config.xcconfig file not found in bundle")
            return [:]
        }
        
        do {
            let contents = try String(contentsOfFile: path, encoding: .utf8)
            var config: [String: String] = [:]
            
            // Parse the xcconfig file
            let lines = contents.components(separatedBy: .newlines)
            for line in lines {
                // Skip comments and empty lines
                if line.trimmingCharacters(in: .whitespaces).hasPrefix("//") || line.isEmpty {
                    continue
                }
                
                // Parse key-value pairs
                let parts = line.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    config[key] = value
                }
            }
            
            return config
        } catch {
            print("Error reading Config.xcconfig: \(error)")
            return [:]
        }
    }
    
    func value<T>(for key: String) throws -> T {
        guard let value = configuration[key] else {
            throw ConfigurationError.missingKey
        }
        
        // Convert string to the requested type
        if T.self == String.self {
            return value as! T
        } else if T.self == Int.self {
            if let intValue = Int(value) {
                return intValue as! T
            }
        } else if T.self == Double.self {
            if let doubleValue = Double(value) {
                return doubleValue as! T
            }
        } else if T.self == Bool.self {
            if let boolValue = Bool(value) {
                return boolValue as! T
            }
        }
        
        throw ConfigurationError.invalidValue
    }
    
    var openAIAPIKey: String {
        get throws {
            try value(for: "OPENAI_API_KEY")
        }
    }
    
    var vectorDatabaseId: String {
        get throws {
            try value(for: "VECTOR_DATABASE_ID")
        }
    }
} 