import Foundation

struct Product: Identifiable {
    let id = UUID()
    let name: String
    let imageName: String
    let price: Int
}

let mockProducts: [Product] = [
    Product(name: "Смартфон X100", imageName: "iphone", price: 59990),
    Product(name: "Ноутбук Pro 15", imageName: "laptopcomputer", price: 89990),
    Product(name: "Наушники SoundMax", imageName: "headphones", price: 12990),
    Product(name: "Умные часы Fit", imageName: "applewatch", price: 15990),
    Product(name: "Планшет Air", imageName: "ipad", price: 45990),
    Product(name: "Телевизор 4K 55\"", imageName: "tv", price: 54990),
    Product(name: "Игровая приставка", imageName: "gamecontroller", price: 39990),
    Product(name: "Колонка SmartSound", imageName: "hifispeaker", price: 8990)
]
