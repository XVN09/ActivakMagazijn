//
//  DetailViewController.swift
//  ActivakMagazijn1.0
//
//  Created by Xander Van nuffel on 21/05/2023.
//

import Foundation
import UIKit
import FirebaseAuth
import FirebaseStorage
import FirebaseDatabase

class DetailViewController: UIViewController {
    var data: MyData?

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var placeLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var Image : UIImageView!
    @IBOutlet weak var categoryLabel : UILabel!
    @IBOutlet weak var editButton : UIButton!
    @IBOutlet weak var currentStockLabel : UILabel!
    @IBOutlet weak var barcodeLabel : UILabel!
    @IBOutlet weak var barcodeImage : UIImageView!
    @IBOutlet weak var historyButton : UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        editButton.isHidden = true
        
        if let loggedInUsr = Auth.auth().currentUser?.uid {
            let usersRef = Database.database().reference().child("Users").child(loggedInUsr)
            
            usersRef.observeSingleEvent(of: .value) { snapshot,_ in
                if let userDict = snapshot.value as? [String: Any],
                   let isAdmin = userDict["isAdmin"] as? Bool {
                    if isAdmin {
                        self.editButton.isHidden = false
                        
                    } else {
                        self.editButton.isHidden = true
                    }
                }
            }
        }
        
        if let loggedInUsr = Auth.auth().currentUser?.uid {
            let productenRef = Constants.ref.child("Producten").child(data?.barText ?? "0000")
            
            productenRef.observeSingleEvent(of: .value) { snapshot,_ in
                if let bartextDict = snapshot.value as? [String: Any],
                   let isTracking = bartextDict["isTracked"] as? Bool {
                    if isTracking == true{
                        self.historyButton.isHidden = false
                    } else {
                        // Your logic when isTracking is false
                        self.historyButton.isHidden = true
                    }
                }
            }
        }

        // Configure your UI elements to display the details
        if let data = data {
            titleLabel.text = data.titleText
            placeLabel.text = data.placeText
            priceLabel.text = data.priceText
            categoryLabel.text = data.catText
            
            // Convert currentStock to a string before assigning to the label
            currentStockLabel.text = String(data.basisStock)
            
            barcodeLabel.text = data.barText
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
        generateAction(self)
    }
    
    func generateAction(_ sender: Any){
        let myName = data?.barText
        if let name = myName{
            let combinedString = "\(name)"
            barcodeImage.image = generateQRCode (Name: combinedString)
        }
    }
    func generateQRCode(Name: String) -> UIImage? {
        let nameData = Name.data(using: .ascii)
        
        if let filter = CIFilter(name: "CICode128BarcodeGenerator") {
            filter.setValue(nameData, forKey: "inputMessage")
            
            // Generating the QR code
            if let output = filter.outputImage {
                // Scale the QR code
                let scaleX = UIScreen.main.scale
                let transform = CGAffineTransform(scaleX: scaleX, y: scaleX)
                let scaledOutput = output.transformed(by: transform)
                
                // Convert CIImage to UIImage
                if let cgImage = CIContext().createCGImage(scaledOutput, from: scaledOutput.extent) {
                    var uiImage = UIImage(cgImage: cgImage)
                    
                    // Add white background
                    UIGraphicsBeginImageContextWithOptions(uiImage.size, true, 0)
                    UIColor.white.setFill()
                    UIRectFill(CGRect(origin: .zero, size: uiImage.size))
                    uiImage.draw(in: CGRect(origin: .zero, size: uiImage.size))
                    uiImage = UIGraphicsGetImageFromCurrentImageContext() ?? uiImage
                    UIGraphicsEndImageContext()
                    
                    return uiImage
                }
            }
        }
        return nil
    }


    @IBAction func handleEditButtonTap() {
        performSegue(withIdentifier: "Edit", sender: self)
    }

    @IBAction func handleOtherButtonTap() {
            performSegue(withIdentifier: "Other", sender: self)
        }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Edit" {
            if let editViewController = segue.destination as? EditViewController {
                editViewController.data = data
            }
        } else if segue.identifier == "Other" {
            if let otherViewController = segue.destination as? OtherViewController {
                otherViewController.barcode = data?.barText
            }
        }
    }
}

class OtherViewController: UITableViewController {
    var barcode: String?
    var locations: [(location: String, quantity: Int)] = [] // Array to store locations

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Fetch locations data from Firebase
        fetchLocations()
    }

    func fetchLocations() {
        guard let barcode = barcode else {
            print("Barcode is nil")
            return
        }
        
        let productenRef = Database.database(url: "https://activak-57cf3-default-rtdb.europe-west1.firebasedatabase.app/").reference().child("Producten").child(barcode).child("Locaties")
        
        productenRef.observeSingleEvent(of: .value) { snapshot in
            guard let locationsData = snapshot.value as? [[String: Any]] else {
                print("No locations found")
                return
            }
            
            for locationData in locationsData {
                if let location = locationData["Location"] as? String,
                   let quantity = locationData["Quantity"] as? Int {
                    self.locations.append((location, quantity))
                }
            }
            
            self.tableView.reloadData()
        }
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return locations.count
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 75
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LocationQuantityCell", for: indexPath) as! LocationQuantityTableViewCell
        
        let location = locations[indexPath.row].location
        let quantity = locations[indexPath.row].quantity
        cell.configure(with: location, quantity: quantity)
        
        return cell
    }
}

class LocationQuantityTableViewCell: UITableViewCell {
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var quantityLabel: UILabel!
    
    func configure(with location: String, quantity: Int) {
        locationLabel.text = location
        quantityLabel.text = "\(quantity)"
    }
}

