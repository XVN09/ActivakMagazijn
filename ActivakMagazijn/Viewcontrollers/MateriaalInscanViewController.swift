//
//  MateriaalInscanViewController.swift
//  Activak Magazijn
//
//  Created by Xander Van nuffel on 08/05/2024.
//

import UIKit
import AVFoundation
import Firebase

class ScanBarcodeFromUserViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var nameLabel: UILabel!

    var captureSession: AVCaptureSession!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    var ref: DatabaseReference!
    var scannedUserName: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        ref = Database.database().reference()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupQRScanner()
    }

    func setupQRScanner() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession = AVCaptureSession()

            guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
                print("Failed to get the camera device")
                return
            }

            let videoInput: AVCaptureDeviceInput

            do {
                videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            } catch {
                print(error)
                return
            }

            if (self?.captureSession.canAddInput(videoInput) ?? false) {
                self?.captureSession.addInput(videoInput)
            } else {
                print("Failed to add video input to the session")
                return
            }

            let metadataOutput = AVCaptureMetadataOutput()

            if (self?.captureSession.canAddOutput(metadataOutput) ?? false) {
                self?.captureSession.addOutput(metadataOutput)

                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            } else {
                print("Failed to add metadata output to the session")
                return
            }

            DispatchQueue.main.async {
                // Set up the video preview layer on the main thread
                self?.videoPreviewLayer = AVCaptureVideoPreviewLayer(session: self?.captureSession ?? AVCaptureSession())
                self?.videoPreviewLayer.videoGravity = .resizeAspectFill
                self?.videoPreviewLayer.frame = self?.previewView.layer.bounds ?? CGRect.zero
                self?.previewView.layer.addSublayer(self?.videoPreviewLayer ?? AVCaptureVideoPreviewLayer())

                // Start running the capture session
                self?.captureSession.startRunning()
            }
        }
    }


    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }

            print(stringValue)

            // Search for the barcode in Firebase
            searchUserInDatabase(barcode: stringValue)
        }
    }

    func searchUserInDatabase(barcode: String) {
        ref.child("UsersBarcodes").child(barcode).observeSingleEvent(of: .value) { [weak self] (snapshot) in
            guard let userData = snapshot.value as? [String: Any] else {
                // Barcode not found in database
                print("Barcode not found in database")
                self?.nameLabel.text = "Geen animator gevonden"
                self?.scannedUserName = nil
                return
            }
            
            if let firstName = userData["FirstName"] as? String {
                // User found, update UI
                self?.nameLabel.text = firstName
                self?.scannedUserName = firstName
            } else {
                // Barcode node found, but "FirstName" attribute not found
                print("FirstName not found for the barcode")
                self?.nameLabel.text = "User data incomplete"
                self?.scannedUserName = nil
            }
        }
    }


    @IBAction func startScanningButtonPressed(_ sender: UIButton) {
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }

    @IBAction func uploadSelectionsButtonPressed(_ sender: UIButton) {
        // Transition to the next view controller
        DispatchQueue.main.async {
            self.performSegue(withIdentifier: "ToListSegue", sender: nil)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ToListSegue",
           let destinationVC = segue.destination as? MateriaalScanner {
            // Pass the scannedUserName to the next view controller
            destinationVC.scannedUserName = scannedUserName
        }
    }
}

class MateriaalInScanner : UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    @IBOutlet weak var cameraView : UIView!
    @IBOutlet weak var itemNameLabel : UILabel!
    @IBOutlet weak var barcodeLabel : UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var categoryLabel: UILabel!
    
    var ref = Database.database().reference(fromURL: "https://activak-57cf3-default-rtdb.europe-west1.firebasedatabase.app/")
    var scannedUserName: String?
    var selectedWeek : String?
    var selectedLocation : String?
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var itemName: String?
    var itemPrice: String?
    var itemCategory: String?
    var scannedBarcode: String!
    var scannedItem: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    // Function to set up the camera for barcode scanning
    func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.code128, .ean13, .ean8, .code39]
        } else {
            failed()
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = cameraView.bounds
        previewLayer.videoGravity = .resizeAspectFill
        cameraView.layer.addSublayer(previewLayer)
        
        captureSession.startRunning()
    }
    
    // Function to handle camera setup failure
    func failed() {
        let ac = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
        captureSession = nil
    }
    
    // Function to handle metadata output from the camera (barcode scanning)
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            print(stringValue)
            
            // Handle the scanned barcode string value
            handleScannedBarcode(stringValue)
        }
    }
    
    @IBAction func startScan() {
        setupCamera()
    }
    
    // Function to handle the scanned barcode
    func handleScannedBarcode(_ barcode: String) {
        
        let alertControllerNotFound = UIAlertController(title: "Item niet gevonden", message: "Wilt u het item toevoegen aan de database?", preferredStyle: .alert)
        let NokAction = UIAlertAction(title: "Nee", style: .default)
        let YokAction = UIAlertAction(title: "Toevoegen aan database", style: .default) { [weak self] _ in
            self?.performSegue(withIdentifier: "DidNotFoundItem", sender: nil)
        }
        alertControllerNotFound.addAction(NokAction)
        alertControllerNotFound.addAction(YokAction)
        
        // Query Firebase to retrieve item information based on the scanned barcode
        ref.child("Producten").child(barcode).observeSingleEvent(of: .value) { [weak self] snapshot,_  in
            guard let itemData = snapshot.value as? [String: Any],
                  let itemName = itemData["Title"] as? String,
                  let itemPrice = itemData["Price"] as? String,
                  let itemCategory = itemData["Category"] as? String else {
                
                self?.present(alertControllerNotFound, animated: true, completion: nil)
                
                return
            }
            
            // Update the labels with the scanned item details
            DispatchQueue.main.async {
                self?.itemNameLabel.text = itemName
                self?.barcodeLabel.text = barcode
                self?.priceLabel.text = itemPrice
                self?.categoryLabel.text = itemCategory
            }
            
            // Store the item name retrieved from Firebase
            self?.itemName = itemName
            self?.itemPrice = itemPrice
            self?.itemCategory = itemCategory
            
            // Display the item name retrieved from Firebase
            let alertController = UIAlertController(title: "Item gevonden", message: itemName, preferredStyle: .alert)
            let okAction = UIAlertAction(title: "Hoeveelheid instellen", style: .default) { _ in
                // Prompt the user for quantity
                self?.promptForQuantityAndUpload(barcode: barcode)
            }
            alertController.addAction(okAction)
        }
    }
    
    // Function to prompt for quantity and upload scanned item details to the database
    func promptForQuantityAndUpload(barcode: String) {
        let alertController = UIAlertController(title: "Hoeveelheid instellen", message: nil, preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "Hoeveelheid"
            textField.keyboardType = .numberPad
        }
        
        let confirmAction = UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            if let quantityString = alertController.textFields?.first?.text,
               let quantity = Int(quantityString) {
                // Upload scanned item details to the database
                self?.uploadScannedItemDetails(barcode: barcode, quantity: quantity)
                self?.setupCamera();
            } else {
                // Handle invalid quantity input
            }
        }
        alertController.addAction(confirmAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    // Function to upload scanned item details to the database
    func uploadScannedItemDetails(barcode: String, quantity: Int) {
        guard let scannedUserName = scannedUserName else {
            print("Scanned user name is nil.")
            return
        }
        
        let scannedListRef = ref.child("scannedUitLists").child(scannedUserName).child("\(selectedLocation ?? "Buro" )  - \(selectedWeek ?? "Week 1")").child("Materiaal").child(barcode)
        let itemDetails = [
            "Name": itemName ?? "Unknown", // You should ensure itemName is available in scope as well
            "Quantity": quantity,
            "Barcode": barcode, //Use the passed barcode value here
            "Category": itemCategory ?? "Unknown",
            "Price": itemPrice ?? "0"
        ] as [String : Any]
        
        scannedListRef.setValue(itemDetails) { (error, ref) in
            if let error = error {
                print("Error uploading scanned item details: \(error.localizedDescription)")
                self.setupCamera()
                // Handle error if upload fails
            } else {
                print("Scanned item details uploaded successfully")
                self.setupCamera()
                // Display success message or take appropriate action
            }
        }
        
        self.barcodeLabel.text = "Barcode"
        self.categoryLabel.text = "Categorie"
        self.itemNameLabel.text = "Naam"
        self.priceLabel.text = "Prijs"
    }
    
    @IBAction func doneButtonTapped(_ sender: UIButton) {
        displaySuccessMessage()
    }
    
    // Function to display success message and dismiss view controllers
    func displaySuccessMessage() {
        let successAlert = UIAlertController(title: "Succesvol", message: "Het materiaal is nu succesvol ingescand,", preferredStyle: .alert)
        
        present(successAlert, animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "materiaalScannerSegue",
           let destinationVC = segue.destination as? DiscrepancyListViewController {
            // Pass the scannedUserName to the next view controller
            destinationVC.scannedBarcode = scannedUserName
        }
    }
}

class DiscrepancyListViewController: UIViewController {
    
    var scannedBarcode: String!
    var originalItems: [String] = []
    var scannedItems: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Fetch original and scanned items from Firebase
        fetchOriginalItems(barcode: scannedBarcode)
        fetchScannedItems(barcode: scannedBarcode)
    }
    
    func fetchOriginalItems(barcode: String) {
        let ref = Database.database().reference().child("Uitgeleend").child(barcode)
        ref.observeSingleEvent(of: .value, with: { snapshot in
            // Parse snapshot and populate originalItems array
            // Reload table view
        })
    }
    
    func fetchScannedItems(barcode: String) {
        let ref = Database.database().reference().child("terugGescand").child(barcode)
        ref.observeSingleEvent(of: .value, with: { snapshot in
            // Parse snapshot and populate scannedItems array
            // Reload table view
        })
    }
    
    @IBAction func continueButtonTapped(_ sender: UIButton) {
        // Proceed to next view controller or perform any other action
    }
}
