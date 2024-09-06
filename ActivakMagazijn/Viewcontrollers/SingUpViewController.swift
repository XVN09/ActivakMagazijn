//
//  SingUpViewController.swift
//  ActivakMagazijn1.0
//
//  Created by Xander Van nuffel on 16/09/2022.
//

import UIKit
import FirebaseAuth
import FirebaseDatabase

class SingUpViewController: UIViewController {

    @IBOutlet weak var Email: UITextField!
    @IBOutlet weak var Password: UITextField!
    
    let ref = Constants.ref
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    
    @IBAction func SignUpButton_Tapped(_ sender: Any) {
        let auth = Auth.auth()
        
        auth.createUser(withEmail: Email.text!, password: Password.text!) { (authResult, error) in
            
            if error != nil {
                
                self.present(Service.createAlertController(title:  "Error", message: error!.localizedDescription ), animated: true, completion: nil )
                return
            } else {
                
                let destinationViewController = self.storyboard?.instantiateViewController(withIdentifier: "SignUpViewControllerPart2") as! SignUpViewControllerPart2
                destinationViewController.email = self.Email.text ?? ""
                self.navigationController?.pushViewController(destinationViewController, animated: true)

                }
                return
            }
        }
         
        
    }


class SignUpViewControllerPart2: UIViewController {
    
    @IBOutlet weak var FirstName : UITextField!
    @IBOutlet weak var LastName : UITextField!
    @IBOutlet weak var PhoneNumber : UITextField!
    @IBOutlet weak var Email : UITextField!
    
    let ref = Constants.ref
    var email : String = ""
    
    override func viewDidLoad() {
        Email.text = email
    }
    @IBAction func SignUpButton_Tapped(_ sender: Any){
        func dataPush(){
            
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            guard let profileView = storyboard.instantiateViewController(withIdentifier: "ProfileView") as? ProfileView else {
                return
            }
        }
        
        func generateRandom13DigitNumberString() -> String {
                var randomString = ""
                
                for _ in 0..<12 {
                    randomString += String(Int.random(in: 0...9))
                }
                
                randomString += String(Int.random(in: 0...9))
            
                return randomString
            }
        
        var usrbar : String = generateRandom13DigitNumberString()
        
        let user = [ "FirstName" : self.FirstName.text,
                     "LastName" : self.LastName.text,
                     "phone_number" : self.PhoneNumber.text,
                     "email" : self.Email.text,
                     "isAdmin" : false,
                     "userBarcode" : usrbar,
                     "uid" : Auth.auth().currentUser?.uid
                     
        ] as [String : Any]
        
        self.ref.child("UsersBarcodes").child(usrbar).setValue(user)
        self.ref.child("Users").child(Auth.auth().currentUser!.uid).setValue(user)
        self.performSegue(withIdentifier: "accountCreatedSegue", sender: self)
        self.present(Service.createAlertController(title: "Verificatie vereist", message: "Check uw email "), animated: true, completion: nil )
    }
}
    


