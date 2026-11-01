import Foundation

struct ComponentLoader {
    static func load(named resourceName: String) throws -> ComponentDefinition {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json") else {
            throw ComponentLoaderError.resourceNotFound(resourceName)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ComponentDefinition.self, from: data)
    }

    enum ComponentLoaderError: LocalizedError {
        case resourceNotFound(String)

        var errorDescription: String? {
            switch self {
            case .resourceNotFound(let name):
                return "Component JSON '\(name).json' not found in bundle."
            }
        }
    }
}
