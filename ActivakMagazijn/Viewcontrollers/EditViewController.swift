import UIKit
import FirebaseDatabase
import FirebaseStorage
import FirebaseAuth

extension UIImage {
    func resizeImage(to targetSize: CGSize) -> UIImage {
        let size = self.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        let newSize = widthRatio > heightRatio ?
            CGSize(width: size.width * heightRatio, height: size.height * heightRatio) :
            CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage ?? self
    }
}

class EditViewController: UIViewController, UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var placeLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var descriptionLabel : UILabel!
    @IBOutlet weak var imageView : UIImageView!
    @IBOutlet weak var categoryLabel : UILabel!
    @IBOutlet weak var basicStockLabel : UILabel!
    @IBOutlet weak var barcodeLabel : UILabel!
    @IBOutlet weak var Image : UIImageView!
    
    @IBOutlet weak var trackingSwitch: UISwitch!
    
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var placeTextField: UITextField!
    @IBOutlet weak var priceTextField: UITextField!
    @IBOutlet weak var descriptionTextField: UITextField!
    @IBOutlet weak var categoryButton : UIButton!
    @IBOutlet weak var basicStockTextField : UITextField!
    @IBOutlet weak var switchHistory : UISwitch!
    @IBOutlet weak var switchBasiskoffer : UISwitch!
    
    var randomKey: String? // Add this variable to the class
    var data : MyData?
    var ref = Constants.ref
    let imagePicker: UIImagePickerController = UIImagePickerController()
    var isTracked : Bool = false
    var selectedCategory : String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let data = data {
            titleLabel.text = data.titleText
            placeLabel.text = data.placeText
            priceLabel.text = data.priceText
            descriptionLabel.text = data.descText
            categoryLabel.text = data.catText
            basicStockLabel.text = String(data.basisStock)
            barcodeLabel.text = data.barText
            
            titleTextField.text = data.titleText
            placeTextField.text = data.placeText
            priceTextField.text = data.priceText
            descriptionTextField.text = data.descText
            basicStockTextField.text = String(data.basisStock)
            switchHistory.isOn = data.isTracked
        }
        
        let storageRef = Storage.storage().reference(forURL: data?.imgURL ?? "gs://activak-57cf3.appspot.com/1QmF9fFlYh5S4TkM_ifD-42i2ABKMC-8pVacw5L1tFGY/Producten/Screenshot 2023-07-01 at 20.04.26.png")
         
         storageRef.getData(maxSize: 200000000) {(data,error) in
             if let err = error {
                 print(err)
             }else {
                 if let image = data {
                     let myImage : UIImage! = UIImage(data:image)
                     self.Image.image = myImage
                 }
             }
         }
        
        trackingSwitch.addTarget(self, action: #selector(trackingSwitchValueChanged(_:)), for: .valueChanged)

        imagePicker.delegate = self
        imagePicker.sourceType = .camera
        
        categoryButton.addTarget(self, action: #selector(showCategorySelection), for: .touchUpInside)
    }
    
    // Function to handle switch value changes
    @objc func trackingSwitchValueChanged(_ sender: UISwitch) {
        // Get the current user's ID
        guard let loggedInUsr = Auth.auth().currentUser?.uid else {
            return
        }

        // Reference to the isTracking value in the database
        let isTrackingRef = Constants.ref.child("Producten").child(data?.barText ?? "0000").child("isTracked")

        // Update the value in the database based on the switch state
        isTrackingRef.setValue(sender.isOn) { (error, _) in
            if let error = error {
                print("Error updating isTracking value: \(error.localizedDescription)")
            } else {
                print("isTracking value updated successfully")
            }
        }
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

    @objc func showCategorySelection() {
        // Fetch previously chosen category value from Firebase Database
        if let data = data {
            selectedCategory = data.catText
        }

        showSelectionAlert(with: "Selecteer categorie", dataKey: "Categories", selectedCategory: selectedCategory) { (selectedItem) in
            self.selectedCategory = selectedItem
            self.categoryButton.setTitle(selectedItem, for: .normal)
        }
    }

    private func showSelectionAlert(with title: String, dataKey: String, selectedCategory: String?, completion: @escaping (String) -> Void) {
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

                // Pre-select the previously chosen category
                if let selectedCategory = selectedCategory, item == selectedCategory {
                    action.setValue(true, forKey: "checked")
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
    
    // Function to observe changes in the isTracking value and update the switch state accordingly
    func observeIsTrackingValue() {
        // Reference to the isTracking value in the database
        let isTrackingRef = Constants.ref.child("Producten").child(data?.barText ?? "0000").child("isTracked")

        // Observe changes in the isTracking value
        isTrackingRef.observe(.value) { [weak self] (snapshot) in
            guard let self = self else { return }

            if let isTracking = snapshot.value as? Bool {
                // Update the switch state based on the isTracking value
                self.trackingSwitch.isOn = isTracking
            }
        }
    }
    
    @IBAction func editPhoto() {
        present(imagePicker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
           imagePicker.dismiss(animated: true)

           guard let image = info[.originalImage] as? UIImage else {
               return
           }

           imageView.image = image

           uploadMedia { url in
               guard let url = url else {
                   return
               }

               // Update the data using the stored random key
               if let basicStockText = self.basicStockTextField.text, let _ = Int(basicStockText){
                   let item = [
                       "Image": url,
                   ] as [String : Any]

                   self.ref.child("Producten").child(self.data!.barText).setValue(item) { error, _ in
                       if let error = error {
                           print("Error updating data: \(error)")
                       } else {
                           self.present(Service.createAlertController(title: "Foto geupdate", message: "Foto succesvol geupload. Vergeet zeker niet op de knop uploaden te drukken"), animated: true, completion: nil)
                       }
                   }
               }
           }
       }

    func uploadMedia(completion: @escaping(_ url: String?) -> Void) {
        let storageRef = Storage.storage(url: "gs://activak-57cf3.appspot.com").reference().child("Producten").child(self.titleLabel.text!)

        if let originalImage = self.imageView.image ?? self.Image.image { // Check if either imageView or Image has the image
            // Resize the image to reduce its size
            let resizedImage = originalImage.resizeImage(to: CGSize(width: 240, height: 135)) // Adjust the target size as needed

            // Convert the resized image to data
            if let data = resizedImage.pngData() {
                storageRef.putData(data) { (metadata, error) in
                    if error != nil {
                        print("An error occurred")
                        completion(nil)
                    } else {
                        storageRef.downloadURL { (url, error) in
                            print(url?.absoluteString as Any)
                            completion(url?.absoluteString)
                        }
                    }
                }
            } else {
                print("Failed to convert resized image to data")
                completion(nil)
            }
        } else {
            // In case the image is not changed, we can use the existing URL
            if let imageUrl = data?.imgURL {
                completion(imageUrl)
            } else {
                print("No image available")
                completion(nil)
            }
        }
    }

        
    @IBAction func uploadData() {
        if let basicStockText = self.basicStockTextField.text {
            // Call uploadMedia here to ensure that the image URL gets uploaded to Firebase
            uploadMedia { imageUrl in
                guard let imageUrl = imageUrl else {
                    print("Failed to get image URL")
                    return
                }
                
                let item = [
                    "Title": self.titleTextField.text ?? "",
                    "Description": self.descriptionTextField.text ?? "",
                    "Price": self.priceTextField.text ?? "",
                    "Place": self.placeTextField.text ?? "",
                    "Category": self.selectedCategory,
                    "BasisStock": self.basicStockTextField.text ?? "",
                    "Barcode": self.barcodeLabel.text ?? "",
                    "Key" : self.data?.randomKey ?? "",
                    "isTracked" : self.switchHistory.isOn,
                    "Image": imageUrl // Include the image URL here
                ] as [String : Any]
                
                let productRef = self.ref.child("Producten").child(self.data?.barText ?? "0000")
                
                productRef.setValue(item) { error, _ in
                    if let error = error {
                        print("Error uploading data: \(error)")
                    } else {
                        self.present(Service.createAlertController(title: "Success", message: "Succesvol database geupdate"), animated: true, completion: nil)
                    }
                }
            }
        } else {
            print("Invalid basic stock value")
            self.present(Service.createAlertController(title: "Error", message: "Probeer opnieuw"),animated: true, completion: nil)
        }
        
        
        func fetchDataFromFirebase() {
            
            ref.child("Producten").observeSingleEvent(of: .value) { snapshot in
                for child in snapshot.children {
                    let snap = child as! DataSnapshot
                    let key = snap.key
                    
                    self.ref.child("Producten").child(key).observeSingleEvent(of: .value) { snapshot, _ in
                        guard let value = snapshot.value as? [String: Any] else {
                            return
                        }
                        
                        let url = value["Image"] as? String ?? ""
                        let title = value["Title"] as? String ?? ""
                        let place = value["Place"] as? String ?? ""
                        let price = value["Price"] as? String ?? ""
                        let description = value["Description"] as? String ?? ""
                        let category = value["Category"] as? String ?? ""
                        let barcode = value["Barcode"] as? String ?? ""
                        let currentStock = value["BasisStock"] as? String ?? ""
                        let isTracked = value["isTracked"] as? Bool ?? false
                        
                        var locaties: [String: Location] = [:]
                        if let locatiesData = value["Locaties"] as? [String: [String: String]] {
                            for (locatieKey, locatieValue) in locatiesData {
                                let aantal = locatieValue["Aantal"] ?? ""
                                let locatie = locatieValue["Locatie"] ?? ""
                                locaties[locatieKey] = Location(aantal: aantal, locatie: locatie)
                            }
                        }
                        
                        let data = MyData()
                        data.setData(url: url, title: title, place: place, price: price, descripiton: description, category: category, barcode: barcode, stock: currentStock, randomkey: key, istracked: isTracked, locaties: locaties)
                    }
                }
            }
        }
    }
}
        
        

