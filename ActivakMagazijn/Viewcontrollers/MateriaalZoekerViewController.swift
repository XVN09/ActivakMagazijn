//
//  MateriaalZoekerViewController.swift
//  ActivakMagazijn1.0
//
//  Created by Xander Van nuffel on 17/03/2024.
//

import Foundation
import FirebaseDatabase
import AVFoundation
import FirebaseStorage
import UIKit

class MateriaalZoekerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    @IBOutlet weak var cameraView : UIView!
    @IBOutlet weak var itemNameLabel : UILabel!
    @IBOutlet weak var itemPlaceLabel : UILabel!
    
    var ref = Constants.ref
    var scannedUserName: String?
    var selectedWeek : String?
    var selectedLocation : String?
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    
    var itemName: String? =  ""
    var itemPrice: String?
    var itemCategory: String?
    var itemPlace : String?
    var itemImage : String?
    var itemStock : String?
    var itemIsTracked : Bool?
    var itemBarcode : String?
    
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
            metadataOutput.metadataObjectTypes = [.code128, .ean8, .ean13, .qr]
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
    
    // Function to handle the scanned barcode
    func handleScannedBarcode(_ barcode: String) {
        // Query Firebase to retrieve item information based on the scanned barcode
        ref.child("Producten").child(barcode).observeSingleEvent(of: .value) { [weak self] snapshot,_  in
            guard let itemData = snapshot.value as? [String: Any],
                  let itemName = itemData["Title"] as? String,
                  let itemPrice = itemData["Price"] as? String,
                  let itemCategory = itemData["Category"] as? String,
                  let itemPlace = itemData["Place"] as? String,
                  let itemUrl = itemData["Image"] as? String,
                  let itemIsTracked = itemData["isTracked"] as? Bool,
                  let itemStock = itemData["BasisStock"] as? String,
                  let itemBarcode = itemData["Barcode"] as? String else {
                print("No item was found")
                self?.setupCamera()
                return
            }
            
            self?.itemName = itemName
            self?.itemPrice = itemPrice
            self?.itemCategory = itemCategory
            self?.itemImage = itemUrl
            self?.itemIsTracked = itemIsTracked
            self?.itemStock = itemStock
            self?.itemBarcode = itemBarcode
            
            // Update the labels with the scanned item details
            DispatchQueue.main.async {
                self?.itemNameLabel.text = itemName
                self?.itemPlaceLabel.text = itemPlace
                self?.setupCamera()
            }
        }
    }
    
    @IBAction func detailButtonTapped(_ sender: UIButton) {
        if itemName != "" {
            let destinationViewController = self.storyboard?.instantiateViewController(withIdentifier: "ScannedDetailViewController") as! ScannedDetailViewController
            destinationViewController.titlelbl = self.itemName ?? ""
            destinationViewController.price = self.itemPrice ?? ""
            destinationViewController.place = self.itemPlace ?? ""
            destinationViewController.stock = self.itemStock ?? ""
            destinationViewController.category = self.itemCategory ?? ""
            destinationViewController.imageurl = self.itemImage ?? ""
            self.navigationController?.pushViewController(destinationViewController, animated: true)
        } else {
            let emptyAlert = UIAlertController(title: "Error", message: "U heeft nog geen barcode gescand. Scan eerst een barcode voordat u verder kunt gaan.", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "Ok", style: .default) { _ in
                self.dismiss(animated: true)
            }
            emptyAlert.addAction(okAction)
            present(emptyAlert, animated: true, completion: nil)
            
            

        }
    }
}

class ScannedDetailViewController: UIViewController {
    
    
    @IBOutlet weak var titleLabel : UILabel!
    @IBOutlet weak var priceLabel : UILabel!
    @IBOutlet weak var stockLabel : UILabel!
    @IBOutlet weak var categoryLabel : UILabel!
    @IBOutlet weak var descriptionLabel : UILabel!
    @IBOutlet weak var placeLabel : UILabel!
    @IBOutlet weak var Image : UIImageView!
    @IBOutlet weak var whereIsItButton : UIButton!
    
    var titlelbl : String? = ""
    var price : String? = ""
    var place : String? = ""
    var stock : String? = ""
    var category : String? = ""
    var imageurl : String? = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = titlelbl
        priceLabel.text = price
        stockLabel.text = stock
        categoryLabel.text = category
        placeLabel.text = place
        
        let storageRef = Storage.storage().reference(forURL: imageurl ?? "gs://activak-57cf3.appspot.com/1QmF9fFlYh5S4TkM_ifD-42i2ABKMC-8pVacw5L1tFGY/Producten/Screenshot 2023-07-01 at 20.04.26.png")
         
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
        
    }
    
}
