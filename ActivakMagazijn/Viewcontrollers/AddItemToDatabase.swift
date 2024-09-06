import UIKit
import FirebaseDatabase
import FirebaseStorage

class AddItemToDatabase: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    let imagePicker: UIImagePickerController = UIImagePickerController()
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var clickToOpenGalleryButton: UIButton!
    @IBOutlet weak var categoryButton: UIButton!
    @IBOutlet weak var priceTextfield: UITextField!
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var barcodeTextField: UITextField!
    @IBOutlet weak var placeTextField: UITextField!
    @IBOutlet weak var basicStockTextField: UITextField!
    @IBOutlet weak var historySelectionSwitch: UISwitch!

    var ref = Constants.ref

    var selectedCategory: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        imagePicker.delegate = self
        imagePicker.sourceType = .camera
        
        categoryButton.addTarget(self, action: #selector(showCategorySelection), for: .touchUpInside)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }

    
    // Assuming you have a struct to represent your data
    struct DataModel {
        let categories: [String]
        let periods: [String]
        let locations: [String]
    }
    
    // Fetch and parse the JSON data
    func fetchData(completion: @escaping (DataModel?, Error?) -> Void) {
        let ref = Database.database(url: "https://setupactivak.europe-west1.firebasedatabase.app/").reference()

        ref.observeSingleEvent(of: .value, with: { (snapshot) in
            guard let data = snapshot.value as? [String: Any],
                  let categories = data["Categories"] as? [String],
                  let periods = data["Periodes"] as? [String],
                  let locations = data["Locaties"] as? [String] else {
                completion(nil, NSError(domain: "ParsingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse data"]))
                return
            }

            let dataModel = DataModel(categories: categories, periods: periods, locations: locations)
            completion(dataModel, nil)
        }) { (error) in
            completion(nil, error)
        }
    }

    // Usage example in your function
    @objc func showCategorySelection() {
        showSelectionAlert(with: "Selecteer categorie", dataKey: "Categories") { (selectedItem) in
            self.selectedCategory = selectedItem
        }
    }

    // General function to show selection alert
    private func showSelectionAlert(with title: String, dataKey: String, completion: @escaping (String) -> Void) {
        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)

        fetchData { (dataModel, error) in
            if let error = error {
                print("Error fetching data: \(error.localizedDescription)")
                return
            }

            guard let dataModel = dataModel else { return }

            var items: [String]
            switch dataKey {
            case "Categories":
                items = dataModel.categories
            case "Periodes":
                items = dataModel.periods
            case "Locaties":
                items = dataModel.locations
            default:
                return
            }

            // Sort items alphabetically
            items.sort()

            for item in items {
                let action = UIAlertAction(title: item, style: .default) { _ in
                    completion(item)
                }
                alertController.addAction(action)
            }

            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            alertController.addAction(cancelAction)

            DispatchQueue.main.async {
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }

    @IBAction func openPhotoLibrary() {
        present(imagePicker, animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        imagePicker.dismiss(animated: true)
        clickToOpenGalleryButton.titleLabel?.isHidden = true
        guard let image = info[.originalImage] as? UIImage else {
            return
        }
        imageView.image = image
    }

    func uploadMedia(completion: @escaping (_ url: String?) -> Void) {
        let storageRef = Storage.storage(url: "gs://activak-57cf3.appspot.com/").reference().child("Producten").child(self.titleTextField.text ?? "")
        
        if let originalImage = self.imageView.image {
            let resizedImage = originalImage.resizeImage(to: CGSize(width: 240, height: 135))
            
            
            if let data = resizedImage.pngData() {
                storageRef.putData(data) { (metadata, error) in
                    if error != nil {
                        print("An error occurred")
                        completion(nil)
                    } else {
                        storageRef.downloadURL(completion: { (url, error) in
                            print(url?.absoluteString as Any)
                            completion(url?.absoluteString)
                        })
                    }
                }
            }
        } else {
            print("No image available")
        }
    }
    func generateRandomID() -> String {
        let uuid = UUID()
        let randomID = uuid.uuidString
        return randomID
    }
    
    let randomUID = RandomId()

    @IBAction func uploadData() {
        uploadMedia() { url in
            guard let url = url else {
                return
            }

            let item = [
                "Title": self.titleTextField.text ?? "",
                "Price": self.priceTextfield.text ?? "0",
                "Place": self.placeTextField.text ?? "",
                "Barcode": self.barcodeTextField.text ?? "",
                "Category": self.selectedCategory ?? "",
                "Image": url,
                "BasisStock": self.basicStockTextField.text ?? "",
                "isTracked": self.historySelectionSwitch.isOn
            ] as [String: Any]

            self.ref.child("Producten").child(self.barcodeTextField.text ?? self.randomUID.randomID).setValue(item)
            self.present(Service.createAlertController(title: "Success", message: "Successfully added to the database."), animated: true, completion: nil)
        }
    }
}



import Foundation

class RandomId {
    var randomID: String
    
    init() {
        self.randomID = RandomId.generateRandomID()
    }
    
    static func generateRandomID() -> String {
        let uuid = UUID()
        let randomID = uuid.uuidString
        return randomID
    }
}
