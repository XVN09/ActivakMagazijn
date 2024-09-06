//
//  MateriaalScannerViewController.swift
//  ActivakMagazijn1.0
//
//  Created by Xander Van nuffel on 07/02/2024.
//
import Foundation
import UIKit
import FirebaseDatabase
import AVFoundation
import PDFKit
import FirebaseStorage
import FirebaseAuth

class AnimatorenScanner: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

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
                self?.scannedUserName = barcode
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
            self.performSegue(withIdentifier: "LocatieEnPeriodeKiezen", sender: nil)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "LocatieEnPeriodeKiezen",
           let destinationVC = segue.destination as? LocatieEnPeriodeViewController {
            // Pass the scannedUserName to the next view controller
            destinationVC.scannedUserName = scannedUserName
        }
    }
}

    
class LocatieEnPeriodeViewController : UIViewController {
    
    @IBOutlet weak var weekButton : UIButton!
    @IBOutlet weak var locationButton : UIButton!
    
    var scannedUserName: String?
    var ref = Constants.ref
    var selectedLocation : String? = "Buro"
    var selectedWeek : String? = "Week"
    
    override func viewDidLoad() {
        super.viewDidLoad()

        print("scanned barcode is \(scannedUserName)")
        
        // Assign actions to buttons
        weekButton.addTarget(self, action: #selector(showWeekSelection), for: .touchUpInside)
        locationButton.addTarget(self, action: #selector(showLocationSelection), for: .touchUpInside)
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
    @objc func showWeekSelection() {
        showSelectionAlert(with: "Selecteer week", dataKey: "Periodes") { (selectedItem) in
            self.selectedWeek = selectedItem
            self.weekButton.setTitle(selectedItem, for: .normal)
        }
    }

    @objc func showLocationSelection() {
        showSelectionAlert(with: "Selecteer Locatie", dataKey: "Locaties") { (selectedItem) in
            self.selectedLocation = selectedItem
            self.locationButton.setTitle(selectedItem, for: .normal)
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

    
    @IBAction func uploadSelectionsButtonPressed(_ sender: UIButton) {
        // Transition to the next view controller
        DispatchQueue.main.async {
            self.performSegue(withIdentifier: "materiaalScannerSegue", sender: nil)
        }
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "materiaalScannerSegue",
           let destinationVC = segue.destination as? MateriaalScanner {
            // Pass the scannedUserName to the next view controller
            destinationVC.scannedUserName = scannedUserName
            destinationVC.selectedWeek = selectedWeek
            destinationVC.selectedLocation = selectedLocation
        }
    }
}
    
class MateriaalScanner : UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
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
    
    // New property to store scanned items temporarily
    var scannedItems: [[String: Any]] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
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
    
    func failed() {
        let ac = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
        captureSession = nil
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            print(stringValue)
            
            handleScannedBarcode(stringValue)
        }
    }
    
    @IBAction func startScan() {
        setupCamera()
    }
    
    func handleScannedBarcode(_ barcode: String) {
        let alertControllerNotFound = UIAlertController(title: "Item niet gevonden", message: "Wilt u het item toevoegen aan de database?", preferredStyle: .alert)
        let NokAction = UIAlertAction(title: "Nee", style: .default)
        let YokAction = UIAlertAction(title: "Toevoegen aan database", style: .default) { [weak self] _ in
            self?.performSegue(withIdentifier: "DidNotFoundItem", sender: nil)
        }
        alertControllerNotFound.addAction(NokAction)
        alertControllerNotFound.addAction(YokAction)
        
        ref.child("Producten").child(barcode).observeSingleEvent(of: .value) { [weak self] snapshot,_  in
            guard let itemData = snapshot.value as? [String: Any],
                  let itemName = itemData["Title"] as? String,
                  let itemPrice = itemData["Price"] as? String,
                  let itemCategory = itemData["Category"] as? String else {
                
                self?.present(alertControllerNotFound, animated: true, completion: nil)
                return
            }
            
            DispatchQueue.main.async {
                self?.itemNameLabel.text = itemName
                self?.barcodeLabel.text = barcode
                self?.priceLabel.text = itemPrice
                self?.categoryLabel.text = itemCategory
            }
            
            self?.itemName = itemName
            self?.itemPrice = itemPrice
            self?.itemCategory = itemCategory
            
            let alertController = UIAlertController(title: "Item gevonden", message: itemName, preferredStyle: .alert)
            let okAction = UIAlertAction(title: "Hoeveelheid instellen", style: .default) { _ in
                self?.promptForQuantityAndAddToList(barcode: barcode)
            }
            alertController.addAction(okAction)
            self?.present(alertController, animated: true, completion: nil)
        }
    }
    
    func promptForQuantityAndAddToList(barcode: String) {
        let alertController = UIAlertController(title: "Hoeveelheid instellen", message: nil, preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "Hoeveelheid"
            textField.keyboardType = .numberPad
        }
        
        let confirmAction = UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            if let quantityString = alertController.textFields?.first?.text,
               let quantity = Int(quantityString) {
                self?.addItemToList(barcode: barcode, quantity: quantity)
                self?.setupCamera()
            } else {
                // Handle invalid quantity input
            }
        }
        alertController.addAction(confirmAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    func addItemToList(barcode: String, quantity: Int) {
        let itemDetails = [
            "Name": itemName ?? "Unknown",
            "Quantity": quantity,
            "Barcode": barcode,
            "Category": itemCategory ?? "Unknown",
            "Price": itemPrice ?? "0"
        ] as [String : Any]
        
        scannedItems.append(itemDetails)
        
        barcodeLabel.text = "Barcode"
        categoryLabel.text = "Categorie"
        itemNameLabel.text = "Naam"
        priceLabel.text = "Prijs"
    }
    
    func uploadScannedItems() {
        guard let scannedUserName = scannedUserName else {
            print("Scanned user name is nil.")
            return
        }
        
        let scannedListRef = ref.child("scannedUitLists").child(scannedUserName).child("\(selectedLocation ?? "Buro") - \(selectedWeek ?? "Week 1")")
        
        for item in scannedItems {
            if let barcode = item["Barcode"] as? String {
                scannedListRef.child(barcode).setValue(item) { (error, ref) in
                    if let error = error {
                        print("Error uploading scanned item details: \(error.localizedDescription)")
                        // Handle error if upload fails
                    } else {
                        print("Scanned item details uploaded successfully")
                        // Display success message or take appropriate action
                    }
                }
            }
        }
        
        scannedItems.removeAll()
    }
    
    @IBAction func doneButtonTapped(_ sender: UIButton) {
        uploadScannedItems()
        displaySuccessMessage()
    }
    
    func displaySuccessMessage() {
        let successAlert = UIAlertController(title: "Winkeltje?", message: "Is er nog een winkeltje dat uitgescand moet worden?", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ja", style: .default) { _ in
            self.performSegue(withIdentifier: "WinkeltjeScan", sender: nil)
        }
        let nokAction = UIAlertAction(title: "Nee", style: .default) { [weak self] _ in
            self?.performSegue(withIdentifier: "BackToBase", sender: nil)
        }
        successAlert.addAction(nokAction)
        successAlert.addAction(okAction)
        
        present(successAlert, animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "WinkeltjeScan",
           let destinationVC = segue.destination as? WinkeltjeMeegevenViewController {
            destinationVC.scannedUserName = scannedUserName
        }
    }
}

class WinkeltjeMeegevenViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    var scannedUserName: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup capture session
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
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            failed()
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        captureSession.startRunning()
    }
    
    func failed() {
        let alertController = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning a code from an item. Please use a device with a camera.", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
        captureSession = nil
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if (captureSession.isRunning) {
            captureSession.stopRunning()
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            found(code: stringValue)
        }
        
        dismiss(animated: true)
    }
    
    func found(code: String) {
        print("Scanned QR code: \(code)")
        let ref = Database.database().reference()
        
        ref.child("scannedWinkeltje").child(code).observeSingleEvent(of: .value) { snapshot in
            // Check if snapshot has data
            guard let winkeltjeData = snapshot.value as? [String: Any] else {
                print("No data found for this QR code.")
                return
            }
            
            // Assuming you have userID available
            let usersRef = ref.child("scannedWinkeltje").child(self.scannedUserName!)
            
            // Update user's winkeltjes with winkeltjeData
            usersRef.updateChildValues(winkeltjeData) { (error, ref) in
                if let error = error {
                    print("Error updating user data: \(error.localizedDescription)")
                } else {
                    print("Successfully added scanned winkel data to user.")
                }
            }
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}
