import Foundation

struct Product: Identifiable, Hashable, Sendable {
    /// A stable slug, not a generated UUID: the viewing history is stored on the
    /// backend and has to survive an app restart.
    let id: String
    let name: String
    let imageName: String
    let price: Int
}

let mockProducts: [Product] = [
    Product(id: "smartphone-x100", name: "Смартфон X100", imageName: "iphone", price: 59990),
    Product(id: "laptop-pro-15", name: "Ноутбук Pro 15", imageName: "laptopcomputer", price: 89990),
    Product(id: "headphones-soundmax", name: "Наушники SoundMax", imageName: "headphones", price: 12990),
    Product(id: "watch-fit", name: "Умные часы Fit", imageName: "applewatch", price: 15990),
    Product(id: "tablet-air", name: "Планшет Air", imageName: "ipad", price: 45990),
    Product(id: "tv-4k-55", name: "Телевизор 4K 55\"", imageName: "tv", price: 54990),
    Product(id: "console-play", name: "Игровая приставка", imageName: "gamecontroller", price: 39990),
    Product(id: "speaker-smartsound", name: "Колонка SmartSound", imageName: "hifispeaker", price: 8990)
]

extension Product {
    static func named(_ id: String) -> Product? {
        mockProducts.first { $0.id == id }
    }
}
