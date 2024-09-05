import UIKit
import Firebase

class ProductsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    
    var products = [Product]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        
        // Register custom cell
        tableView.register(UINib(nibName: "ProductCell", bundle: nil), forCellReuseIdentifier: "ProductCell")
        
        // Load data from Firebase
        loadProducts()
    }
    
    func loadProducts() {
        // Reference to Firebase Database
        let ref = Database.database().reference().child("Producten")
        
        ref.observe(.value) { snapshot in
            self.products.removeAll() // Clear existing data
            
            // Loop through all products
            for child in snapshot.children.allObjects as! [DataSnapshot] {
                if let dictionary = child.value as? [String: Any] {
                    let product = Product(dictionary: dictionary)
                    self.products.append(product)
                }
            }
            
            self.tableView.reloadData() // Refresh table
        }
    }
    
    // TableView DataSource Methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return products.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ProductCell", for: indexPath) as? ProductCell else {
            return UITableViewCell()
        }
        let product = products[indexPath.row]
        
        // Configure the details label with the title, place, and price
        cell.detailsLabel.text = """
        Title: \(product.title)
        Place: \(product.place)
        Price: \(product.price)
        """
        
        // Load Image asynchronously
        if let imageUrl = URL(string: product.image) {
            URLSession.shared.dataTask(with: imageUrl) { data, _, _ in
                guard let data = data else { return }
                DispatchQueue.main.async {
                    cell.productImageView.image = UIImage(data: data)
                }
            }.resume()
        }
        
        return cell
    }
    
    // Navigate to DetailViewController on cell tap
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let product = products[indexPath.row]
        let detailVC = storyboard?.instantiateViewController(withIdentifier: "DetailViewController") as! DetailViewController
        detailVC.product = product
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
