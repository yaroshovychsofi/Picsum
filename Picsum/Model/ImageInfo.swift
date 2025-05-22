import Foundation

struct ImageInfo: Codable, Identifiable, Hashable {
    let id: String
    let author: String
    let width: Int
    let height: Int
    let url: String
    let download_url: String

    enum CodingKeys: String, CodingKey {
        case id
        case author
        case width
        case height
        case url
        case download_url
    }
}
