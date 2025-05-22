import Foundation
import UIKit 

enum NetworkError: Error {
    case invalidURL
    case requestFailed(Error)
    case noData
    case decodingError(Error)
    case invalidResponse
    case imageCreationError
}

class NetworkManager {
    static let shared = NetworkManager()
    private let baseURL = "https://picsum.photos"
    private init() {}

    func fetchImageList(page: Int, limit: Int, completion: @escaping (Result<[ImageInfo], NetworkError>) -> Void) {
        var components = URLComponents(string: "\(baseURL)/v2/list")
        components?.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        guard let url = components?.url else {
            completion(.failure(.invalidURL))
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(.requestFailed(error)))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(.invalidResponse))
                return
            }
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            do {
                let images = try JSONDecoder().decode([ImageInfo].self, from: data)
                completion(.success(images))
            } catch let decodingError {
                completion(.failure(.decodingError(decodingError)))
            }
        }
        task.resume()
    }

    func fetchImageData(urlString: String, completion: @escaping (Result<Data, NetworkError>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(.requestFailed(error)))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(.invalidResponse))
                return
            }
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            completion(.success(data))
        }
        task.resume()
    }
}
