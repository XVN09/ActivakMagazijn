import UIKit

class DetailViewController: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var placeLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var barcodeLabel: UILabel!
    @IBOutlet weak var basisStockLabel: UILabel!
    @IBOutlet weak var isTrackedLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    
    var product: Product?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure UI with product data
        guard let product = product else { return }
        titleLabel.text = "\(product.title)"
        placeLabel.text = "\(product.place)"
        priceLabel.text = "\(product.price)"
        descriptionLabel.text = "\(product.description)"
        categoryLabel.text = "\(product.category)"
        barcodeLabel.text = "\(product.barcode)"
        basisStockLabel.text = "\(product.basisStock)"
        isTrackedLabel.text = "Is Tracked: \(product.isTracked ? "Yes" : "No")"
        
        // Load Image
        if let imageUrl = URL(string: product.image) {
            URLSession.shared.dataTask(with: imageUrl) { data, _, _ in
                guard let data = data else { return }
                DispatchQueue.main.async {
                    self.imageView.image = UIImage(data: data)
                }
            }.resume()
        }
    }
}
