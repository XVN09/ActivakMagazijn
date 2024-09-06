//
//  ProfileView.swift
//  ActivakMagazijn1.0
//
//  Created by Xander Van nuffel on 15/04/2023.
//

import CoreImage
import Foundation
import UIKit
import FirebaseAuth
import FirebaseDatabase
import FirebaseFirestore

class ProfileView : UIViewController {
    
    @IBOutlet weak var UploadFiles: UIButton!
    @IBOutlet weak var BarcodeScanner: UIButton!
    @IBOutlet weak var barcodeImageView: UIImageView!
    @IBOutlet weak var showBarcodeButton: UIButton!
    @IBOutlet weak var winkeltjeInButton: UIButton!
    @IBOutlet weak var materiaalInButton: UIButton!
    @IBOutlet weak var winkeltjeInscannen : UIButton!
    @IBOutlet weak var welcomeLable: UILabel!
    @IBOutlet weak var userLable: UILabel!
    @IBOutlet weak var emailLable: UILabel!
    @IBOutlet weak var phoneNumberLable: UILabel!
    
    var ref = Constants.ref
    
    override func viewDidLoad() {
        
        UploadFiles.isHidden = true
        BarcodeScanner.isHidden = true
        
        self.UploadFiles.isHidden = true
        self.BarcodeScanner.isHidden = true
        self.showBarcodeButton.isHidden = false
        self.winkeltjeInscannen.isHidden = true
        self.materiaalInButton.isHidden = true
        self.winkeltjeInscannen.isHidden = true
        self.winkeltjeInButton.isHidden = true
        
        if let loggedInUsr = Auth.auth().currentUser?.uid {
            let usersRef = Constants.ref.child("Users").child(loggedInUsr)
            
            print(usersRef)
            
            usersRef.observeSingleEvent(of: .value) { snapshot in
                if let userDict = snapshot.value as? [String: Any],
                   let isAdmin = userDict["isAdmin"] as? Bool {
                    if isAdmin {
                        self.UploadFiles.isHidden = false
                        self.BarcodeScanner.isHidden = false
                        self.showBarcodeButton.isHidden = true
                        self.winkeltjeInscannen.isHidden = false
                        self.materiaalInButton.isHidden = false
                        self.winkeltjeInscannen.isHidden = false
                        self.winkeltjeInButton.isHidden = false
                    } else {
                        self.UploadFiles.isHidden = true
                        self.BarcodeScanner.isHidden = true
                        self.showBarcodeButton.isHidden = false
                        self.winkeltjeInscannen.isHidden = true
                        self.materiaalInButton.isHidden = true
                        self.winkeltjeInscannen.isHidden = true
                        self.winkeltjeInButton.isHidden = true

                    }
                }
            }
        }
        FetchFirebaseUserData()
    }
    
    // MARK: Barcode Generator
        
    var userBarcode : String?
    var userFirstname : String?
    
    func FetchFirebaseUserData() {
        if let loggedInUserUID = Auth.auth().currentUser?.uid {
            let databaseRef = ref.child("Users").child(loggedInUserUID)
            
            // Check Realtime Database first
            databaseRef.observeSingleEvent(of: .value) { snapshot, _ in
                let value = snapshot.value as? NSDictionary
                if value != nil {
                    // Data found in Realtime Database
                    let email = value?["email"] as? String ?? ""
                    let firstname = value?["FirstName"] as? String ?? ""
                    let lastname = value?["LastName"] as? String ?? ""
                    let phonenumber = value?["phone_number"] as? String ?? ""
                    let userBarcode = value?["userBarcode"] as? String ?? ""
                    
                    print("From RTDB:", email, firstname, lastname, phonenumber, userBarcode)
                    
                    self.emailLable.text = email
                    self.userLable.text = firstname + " " + lastname
                    self.phoneNumberLable.text = phonenumber
                    self.welcomeLable.text = "Welkom " + firstname
                    self.userBarcode = userBarcode
                    self.userFirstname = firstname
                } else {
                    // Data not found in Realtime Database, fetch from Firestore
                    let firestoreRef = Firestore.firestore().collection("Users").document(loggedInUserUID)
                    firestoreRef.getDocument { (document, error) in
                        if let document = document, document.exists {
                            let data = document.data()
                            let email = data?["email"] as? String ?? ""
                            let firstname = data?["FirstName"] as? String ?? ""
                            let lastname = data?["LastName"] as? String ?? ""
                            let phonenumber = data?["phone_number"] as? String ?? ""
                            let userBarcode = data?["userBarcode"] as? String ?? ""
                            
                            print("From Firestore:", email, firstname, lastname, phonenumber, userBarcode)
                            
                            self.emailLable.text = email
                            self.userLable.text = firstname + " " + lastname
                            self.phoneNumberLable.text = phonenumber
                            self.welcomeLable.text = "Welkom " + firstname
                            self.userBarcode = userBarcode
                            self.userFirstname = firstname
                        } else {
                            print("Document does not exist in Firestore")
                        }
                    }
                }
            }
        }
    }

    @IBAction func displayBarCode(){
        let myName = userBarcode
        if let name = myName{
            let combinedString = "\(name)"
            barcodeImageView.image = generateQRCode (Name: combinedString)
        }
    }
    func generateQRCode(Name: String) -> UIImage? {
        let nameData = Name.data(using: .ascii)
        
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
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

    
    @IBAction func onLogOutButtonTapped(){
        do{
            try Auth.auth().signOut()
        
        } catch let error as NSError {
            print(error)
        }
        if Auth.auth().currentUser == nil {
            self.performSegue(withIdentifier: "BackToHome", sender: self)
        }
    }
    
    @IBAction func BackToHomeButton(_ sender: Any){
        self.performSegue(withIdentifier: "BackToHome", sender: self)
    }
}
