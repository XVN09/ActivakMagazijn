import Foundation
import UIKit
import PDFKit
import FirebaseDatabase
import AVFoundation
import FirebaseStorage
import FirebaseAuth

class WinkeltjeUitscannenViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var itemNameLabel: UILabel!
    @IBOutlet weak var barcodeLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var categoryLabel: UILabel!
    
    var ref = Constants.ref
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var itemName: String?
    var itemPrice: String?
    var itemCategory: String?
    var code: String!
    var scannedItems: [[String: Any]] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        generateRandom13DigitNumberString()
        print("Code is \(code ?? "")")
    }
    
    func generateRandom13DigitNumberString() {
        var randomString = ""
        
        for _ in 0..<12 {
            randomString += String(Int.random(in: 0...9))
        }
        
        randomString += String(Int.random(in: 0...9))
        
        code = randomString
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
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.code128, .ean13]
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
    
    @IBAction func scanButton() {
        setupCamera()
    }
    
    func failed() {
        let ac = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
        captureSession = nil
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject, let stringValue = readableObject.stringValue else { return }
            print(stringValue)
            handleScannedBarcode(stringValue)
        }
    }
    
    func handleScannedBarcode(_ barcode: String) {
        ref.child("Producten").child(barcode).observeSingleEvent(of: .value) { [weak self] snapshot,_  in
            guard let itemData = snapshot.value as? [String: Any],
                  let itemName = itemData["Title"] as? String,
                  let itemPrice = itemData["Price"] as? String,
                  let itemCategory = itemData["Category"] as? String else {
                print("No item was found")
                return
            }
            
            DispatchQueue.main.async {
                self?.itemNameLabel.text = itemName
                self?.priceLabel.text = itemPrice
                self?.barcodeLabel.text = barcode
                self?.categoryLabel.text = itemCategory
            }
            
            self?.itemName = itemName
            self?.itemPrice = itemPrice
            self?.itemCategory = itemCategory
            
            let alertController = UIAlertController(title: "Item gevonden", message: itemName, preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                self?.promptForQuantityAndUpload(barcode: barcode)
            }
            alertController.addAction(okAction)
            self?.present(alertController, animated: true, completion: nil)
        }
    }
    
    func promptForQuantityAndUpload(barcode: String) {
        let alertController = UIAlertController(title: "Hoeveelheid instellen", message: nil, preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "Hoeveelheid"
            textField.keyboardType = .numberPad
        }
        
        let confirmAction = UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            if let quantityString = alertController.textFields?.first?.text, let quantity = Int(quantityString) {
                self?.uploadScannedItemDetails(barcode: barcode, quantity: quantity)
            }
        }
        alertController.addAction(confirmAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    func uploadScannedItemDetails(barcode: String, quantity: Int) {
        let scannedListRef = ref.child("scannedWinkeltje").child(code).child(barcode)
        let itemDetails = [
            "Name": itemName ?? "Unknown",
            "Quantity": quantity,
            "Barcode": barcode,
            "Category": itemCategory ?? "Unknown",
            "Price": itemPrice ?? "0"
        ] as [String : Any]
        
        scannedListRef.setValue(itemDetails) { [weak self] (error, ref) in
            if let error = error {
                print("Error uploading scanned item details: \(error.localizedDescription)")
            } else {
                print("Scanned item details uploaded successfully")
            }
            self?.resetLabels()
        }
    }
    
    func resetLabels() {
        barcodeLabel.text = "Barcode"
        categoryLabel.text = "Categorie"
        itemNameLabel.text = "Naam"
        priceLabel.text = "Prijs"
    }
    
    @IBAction func generatePDFButtonPressed(_ sender: UIButton) {
        fetchScannedItems()
    }
    
    func fetchScannedItems() {
        ref.child("scannedWinkeltje").child(code).observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let items = snapshot.value as? [String: Any] else {
                print("No scanned items found")
                return
            }
            
            for (_, value) in items {
                if let itemDetails = value as? [String: Any] {
                    self?.scannedItems.append(itemDetails)
                }
            }
            
            self?.generatePDF()
        }
    }
    
    func generatePDF() {
        let pdf = PDFDocument()
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792) // Standard US Letter size
        
        // Creating an empty page
        var page = PDFPage()
        var pageContent = ""

        var lineCount = 0
        let maxLinesPerPage = 40
        
        for item in scannedItems {
            let itemName = item["Name"] as? String ?? "Unknown"
            let barcode = item["Barcode"] as? String ?? "Unknown"
            let price = item["Price"] as? String ?? "0"
            let itemString = "\(itemName) | \(barcode) | \(price)\n"
            
            pageContent += itemString
            lineCount += 1
            
            if lineCount >= maxLinesPerPage {
                let page = PDFPage()
                let attributedString = NSAttributedString(string: pageContent)
                let pdfPageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
                let pdfPage = PDFPage()
                
                UIGraphicsBeginImageContext(pdfPageBounds.size)
                attributedString.draw(in: pdfPageBounds)
                let pageImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                if let pageImage = pageImage, let pageData = pageImage.pngData() {
                    let imagePDFPage = PDFPage(image: UIImage(data: pageData)!)!
                    pdf.insert(imagePDFPage, at: pdf.pageCount)
                }
                
                // Reset for the next page
                pageContent = ""
                lineCount = 0
            }
        }
        
        // Add remaining content to the last page
        if !pageContent.isEmpty {
            let attributedString = NSAttributedString(string: pageContent)
            let pdfPageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
            let pdfPage = PDFPage()
            
            UIGraphicsBeginImageContext(pdfPageBounds.size)
            attributedString.draw(in: pdfPageBounds)
            let pageImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            if let pageImage = pageImage, let pageData = pageImage.pngData() {
                let imagePDFPage = PDFPage(image: UIImage(data: pageData)!)!
                pdf.insert(imagePDFPage, at: pdf.pageCount)
            }
        }
        
        // Add QR code to the last page
        if let qrCodeImage = generateQRCodeImage(from: code) {
            let lastPage = pdf.page(at: pdf.pageCount - 1)
            let qrCodeBounds = CGRect(x: 50, y: 50, width: 10000, height: 10000)
            let qrCodeAnnotation = PDFAnnotation(bounds: qrCodeBounds, forType: .stamp, withProperties: nil)
            
            UIGraphicsBeginImageContext(qrCodeBounds.size)
            qrCodeImage.draw(in: qrCodeBounds)
            let qrCodeImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            if let qrCodeImage = qrCodeImage, let qrCodeData = qrCodeImage.pngData() {
                let qrCodePDFPage = PDFPage(image: UIImage(data: qrCodeData)!)!
                pdf.insert(qrCodePDFPage, at: pdf.pageCount)
            }
            
            if let lastPage = lastPage {
                let pageImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                if let pageImage = pageImage, let pageData = pageImage.pngData() {
                    let imagePDFPage = PDFPage(image: UIImage(data: pageData)!)
                    lastPage.addAnnotation(qrCodeAnnotation)
                }
            }
        }
        
        if let documentData = pdf.dataRepresentation() {
            let printController = UIPrintInteractionController.shared
            let printInfo = UIPrintInfo(dictionary: nil)
            printInfo.outputType = .general
            printInfo.jobName = "Scanned Items"
            printController.printInfo = printInfo
            printController.printingItem = documentData
            
            printController.present(animated: true, completionHandler: nil)
        }
    }
    
    func generateQRCodeImage(from string: String) -> UIImage? {
        // Create a data object from the input string
        guard let data = string.data(using: String.Encoding.ascii) else {
            print("Failed to create data from string")
            return nil
        }
        
        // Create a QR code generator
        guard let qrCodeGenerator = CIFilter(name: "CIQRCodeGenerator") else {
            print("Failed to create QR code generator")
            return nil
        }
        
        // Set the input message for the QR code generator
        qrCodeGenerator.setValue(data, forKey: "inputMessage")
        
        // Set the correction level for the QR code
        qrCodeGenerator.setValue("H", forKey: "inputCorrectionLevel")
        
        // Get the output CIImage from the QR code generator
        guard let outputImage = qrCodeGenerator.outputImage else {
            print("Failed to generate QR code image")
            return nil
        }
        
        // Resize the QR code image
        let transform = CGAffineTransform(scaleX: 100 , y: 100)
        let scaledImage = outputImage.transformed(by: transform)
        
        // Convert the CIImage to a UIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            print("Failed to create CGImage from CIImage")
            return nil
        }
        
        let qrCodeImage = UIImage(cgImage: cgImage)
        return qrCodeImage
    }
}
