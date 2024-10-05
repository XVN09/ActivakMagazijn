import Foundation
import UIKit
import FirebaseDatabase
import FirebaseAuth
import VisionKit
import MLKit
import Vision
import AVFoundation

class DisplayDataViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, UISearchResultsUpdating, VNDocumentCameraViewControllerDelegate, AVCaptureMetadataOutputObjectsDelegate {
    
    // MARK: Variables and outlets
    
    @IBOutlet weak var tableView: UITableView!
    
    var refreshControl = UIRefreshControl()
    
    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var overlayView: UIView! // Declare the overlay view
    
    var dataArray: [MyData] = []
    var filteredDataArray: [MyData] = [] // For storing filtered data
    var categoryFilter: [MyData] = []
    let reuseIdentifier = "DataCell"
    var filteredResults : [MyData] = []
    private var scanButton : UIButton!
    weak var delegate: DataScannerDelegate?
    
    var ref = Constants.ref
    
    let searchController = UISearchController(searchResultsController: nil)
    var categories: [String] = [] // Array to store unique categories
        

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self

        // Configure search controller
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Zoeken"
        navigationItem.searchController = searchController
        definesPresentationContext = true
        
        let modeButton = UIButton(type: .custom)
        modeButton.setImage(UIImage(systemName: "slider.horizontal.3"), for: .normal)
        modeButton.addTarget(self, action: #selector(modeButtonTapped), for: .touchUpInside)
        searchController.searchBar.searchTextField.leftView = modeButton
        searchController.searchBar.searchTextField.leftViewMode = .always
        
        searchController.searchBar.searchTextField.leftView?.tintColor = .black
    
        // Initialize refresh control
        refreshControl.addTarget(self, action: #selector(refreshTable), for: .valueChanged)

        // Add refresh control to the table view
        if #available(iOS 10.0, *) {
            tableView.refreshControl = refreshControl
        } else {
            tableView.addSubview(refreshControl)
        }
        
        fetchDataFromFirebase()
    }
    
    @objc func refreshTable() {
            fetchDataFromFirebase()
            // Reload table view
            tableView.reloadData()

            // End refreshing
            refreshControl.endRefreshing()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Reload table view data when the view appears
        tableView.reloadData()
    }

    // MARK: TableView Methods
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isFiltering() {
            return filteredDataArray.count
        }
        return dataArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as? DataCell else {
            return UITableViewCell()
        }
        
        let data: MyData
        if isFiltering() {
            data = filteredDataArray[indexPath.row]
        } else {
            data = dataArray[indexPath.row]
        }
        
        cell.setValues(data: data)
        
        return cell
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedData: MyData
        if isFiltering() {
            selectedData = filteredDataArray[indexPath.row]
        } else {
            selectedData = dataArray[indexPath.row]
        }
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let detailViewController = storyboard.instantiateViewController(withIdentifier: "DetailViewController") as? DetailViewController else {
            return
        }
        
        detailViewController.data = selectedData
        navigationController?.pushViewController(detailViewController, animated: true)
    }
    
    // MARK: Search Bar Methods
    
    func updateSearchResults(for searchController: UISearchController) {
        filterContentForSearchText(searchController.searchBar.text!)
    }
    
    func filterContentForSearchText(_ searchText: String) {
        
        
        filteredDataArray = dataArray.filter { data in
            let titleMatch = data.titleText.lowercased().contains(searchText.lowercased())
            let placeMatch = data.placeText.lowercased().contains(searchText.lowercased())
            let priceMatch = data.priceText.lowercased().contains(searchText.lowercased())
            let categoryMatch = data.catText.lowercased().contains(searchText.lowercased())
            let barcodeMatch = data.barText.lowercased().contains(searchText.lowercased())
            
            return titleMatch || placeMatch || priceMatch || categoryMatch || barcodeMatch
        }
        
        tableView.reloadData()
    }
    
    func isFiltering() -> Bool {
        let searchBarScopeIsFiltering = searchController.searchBar.selectedScopeButtonIndex != 0
        return searchController.isActive && !searchBarIsEmpty() || searchBarScopeIsFiltering
    }
    
    
    func searchBarIsEmpty() -> Bool {
        return searchController.searchBar.text?.isEmpty ?? true
    }
    
    @objc func modeButtonTapped() {
        let alertController = UIAlertController(title: "Filter", message: "Selecteer hoe je wilt filteren", preferredStyle: .actionSheet)
        
        let scanAction = UIAlertAction(title: "Scanner", style: .default) { [weak self] _ in
            // Handle scan mode behavior
            self?.setupScannerViewAndActivateScan()
            self?.searchController.isActive = true
        }
        alertController.addAction(scanAction)
        
        let filterAction = UIAlertAction(title: "Categorie Filter", style: .default) { [weak self] _ in
            // Handle filter mode behavior
            self?.searchController.isActive = true
            self?.categoryButtonTapped()
        }
        alertController.addAction(filterAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }


    func setupScannerViewAndActivateScan() {
        // Create and configure the scanner view
        let captureDevice = AVCaptureDevice.default(for: .video)

        do {
            let input = try AVCaptureDeviceInput(device: captureDevice!)
            let captureSession = AVCaptureSession()
            captureSession.addInput(input)

            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession.addOutput(captureMetadataOutput)

            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = [.code128, .code39, .ean13, .qr]

            let scannerViewController = UIViewController()
            let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            videoPreviewLayer.videoGravity = .resizeAspectFill
            videoPreviewLayer.frame = scannerViewController.view.layer.bounds
            scannerViewController.view.layer.addSublayer(videoPreviewLayer)

            let cancelButton = UIButton(type: .system)
            cancelButton.setTitle("Cancel", for: .normal)
            cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
            scannerViewController.view.addSubview(cancelButton)

            // Customize the frame and appearance of the cancel button as needed
            cancelButton.frame = CGRect(x: 16, y: 16, width: 80, height: 40)

            // Present the scanner view controller modally
            present(scannerViewController, animated: true, completion: {
                // Start the search controller in the background
                self.searchController.isActive = true
                self.searchController.searchBar.becomeFirstResponder()
            })

            captureSession.startRunning()

        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }

    // Implement the delegate method to handle scanned metadata (barcode data)
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           let scannedData = metadataObj.stringValue {
            // Dismiss the scanner view
            captureSession?.stopRunning()
            dismiss(animated: true, completion: nil)

            // Update the search controller's search bar text with the scanned data
            searchController.searchBar.text = scannedData

            // Activate the search controller (optional)
            searchController.isActive = true
        }
    }

    
    @objc func cancelButtonTapped() {
        // Stop the scanner and dismiss the scanner view controller
        captureSession?.stopRunning()
        dismiss(animated: true, completion: nil)
    }

    var randomKey : String = ""
    
    // MARK: Firebase Data Methods
    
    func fetchDataFromFirebase() {
        self.dataArray = []
        
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
                    
                    self.dataArray.append(data)
                    
                    // Update categories array with unique categories
                    if !self.categories.contains(category) {
                        self.categories.append(category)
                    }
                    
                    self.tableView.reloadData()
                }
            }
        }
    }

    
    // MARK: Category Button
    
    @objc func categoryButtonTapped() {
        let alertController = UIAlertController(title: "Selecteer Categorie", message: nil, preferredStyle: .actionSheet)
        
        for category in categories {
            let action = UIAlertAction(title: category, style: .default) { [weak self] _ in
                self?.searchController.searchBar.text = category
            }
            alertController.addAction(action)
        }
        
        let cancelAction = UIAlertAction(title: "Annuleer", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        if let popoverController = alertController.popoverPresentationController {
            popoverController.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(alertController, animated: true, completion: nil)
    }
    
    //MARK: Scanner search`
    
    func recognizeBarcodeInImage(_ image: UIImage) {
        let visionImage = VisionImage(image: image)

        // Initialize the barcode detector
        let barcodeDetector = BarcodeScanner.barcodeScanner()

        // Perform barcode detection on the image
        barcodeDetector.process(visionImage) { barcodes, error in
            guard error == nil, let barcodes = barcodes else {
                // Handle the error or no barcodes detected
                print("Barcode detection failed or no barcodes detected")
                return
            }

            // Process the detected barcodes (if needed)
            for barcode in barcodes {
                let barcodeValue = barcode.rawValue
                self.searchController.searchBar.text = barcodeValue
                print("Detected Barcode: \(barcodeValue)")
            }
        }
    }
    
    private func handleSearch(with searchText: String) {
        // Set the scanned text in the search bar
        searchController.searchBar.text = searchText
        
        // Filter the content for the search text
        filterContentForSearchText(searchText)
        
        // Dismiss the scanning view and show the search results
        dismiss(animated: true, completion: nil)
        
        // Perform the segue to show the search results
        performSegue(withIdentifier: "backSegue", sender: nil)
    }
    
    
    func dismissDataScannerViewController() {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: Segue
    
    @IBAction func loginButtonTapped(_ sender: Any) {
        if Constants.isUserLoggedIn == true{
            self.performSegue(withIdentifier: "LoggedInSegue", sender:  nil)
        } else {
            self.performSegue(withIdentifier: "AccountStartScreenSegue", sender: nil)
        }
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "DetailSegue" {
            if let detailViewController = segue.destination as? DetailViewController {
                // Pass the selected data to the detail view controller
                detailViewController.data = filteredResults[0]
            }
        }
    }
}

// MARK: Protocols
protocol DataScannerDelegate: AnyObject {
    func didScanData(_ data: String)
}

