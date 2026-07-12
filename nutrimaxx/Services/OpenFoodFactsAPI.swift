import Foundation

/// A single search result from OpenFoodFacts, normalised to per-100g nutrients.
struct FoodProduct: Identifiable, Hashable {
    let id: String            // barcode / product code
    let name: String
    let brand: String?
    let per100g: Nutrients
}

enum OpenFoodFactsError: Error {
    case badURL
    case badResponse
}

/// Minimal client for the OpenFoodFacts API.
/// Docs: https://openfoodfacts.github.io/openfoodfacts-server/api/
struct OpenFoodFactsAPI {
    static let shared = OpenFoodFactsAPI()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }()

    /// Text search across products, returning up to `pageSize` normalised results.
    func search(_ query: String, pageSize: Int = 25) async throws -> [FoodProduct] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")
        components?.queryItems = [
            URLQueryItem(name: "search_terms", value: trimmed),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: String(pageSize)),
            URLQueryItem(name: "fields", value: "code,product_name,brands,nutriments"),
        ]
        guard let url = components?.url else { throw OpenFoodFactsError.badURL }

        var request = URLRequest(url: url)
        // OFF asks clients to identify themselves via User-Agent.
        request.setValue("nutrimaxx/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw OpenFoodFactsError.badResponse
        }

        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        return decoded.products.compactMap { $0.asFoodProduct }
    }

    // MARK: - Decoding

    private struct SearchResponse: Decodable {
        let products: [Product]
    }

    private struct Product: Decodable {
        let code: String?
        let product_name: String?
        let brands: String?
        let nutriments: Nutriments?

        var asFoodProduct: FoodProduct? {
            let name = (product_name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let n = nutriments ?? Nutriments()
            return FoodProduct(
                id: code ?? UUID().uuidString,
                name: name,
                brand: brands?.isEmpty == false ? brands : nil,
                per100g: Nutrients(
                    calories: n.energyKcal100g,
                    protein: n.proteins_100g ?? 0,
                    carbs: n.carbohydrates_100g ?? 0,
                    fat: n.fat_100g ?? 0
                )
            )
        }
    }

    /// OFF exposes energy in a couple of shapes; handle the common ones.
    private struct Nutriments: Decodable {
        let energy_kcal_100g: Double?
        let energy_100g: Double?
        let proteins_100g: Double?
        let carbohydrates_100g: Double?
        let fat_100g: Double?

        init() {
            energy_kcal_100g = nil; energy_100g = nil
            proteins_100g = nil; carbohydrates_100g = nil; fat_100g = nil
        }

        enum CodingKeys: String, CodingKey {
            case energy_kcal_100g = "energy-kcal_100g"
            case energy_100g = "energy_100g"
            case proteins_100g
            case carbohydrates_100g
            case fat_100g
        }

        /// kcal per 100g, converting from kJ if only that is present.
        var energyKcal100g: Double {
            if let kcal = energy_kcal_100g { return kcal }
            if let kj = energy_100g { return kj / 4.184 }
            return 0
        }
    }
}
