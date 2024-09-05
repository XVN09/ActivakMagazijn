import Foundation

struct Product {
    var barcode: String
    var basisStock: String
    var category: String
    var description: String
    var image: String
    var isTracked: Bool
    var key: String
    var place: String
    var price: String
    var title: String
    
    init(dictionary: [String: Any]) {
        self.barcode = dictionary["Barcode"] as? String ?? ""
        self.basisStock = dictionary["BasisStock"] as? String ?? ""
        self.category = dictionary["Category"] as? String ?? ""
        self.description = dictionary["Description"] as? String ?? ""
        self.image = dictionary["Image"] as? String ?? ""
        self.isTracked = dictionary["IsTracked"] as? Bool ?? false
        self.key = dictionary["Key"] as? String ?? ""
        self.place = dictionary["Place"] as? String ?? ""
        self.price = dictionary["Price"] as? String ?? ""
        self.title = dictionary["Title"] as? String ?? ""
    }
}
