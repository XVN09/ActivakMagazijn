//
//  Constants.swift
//  ActivakMagazijn1.0
//
//  Created by Xander Van nuffel on 24/04/2023.
//

import Foundation
import FirebaseDatabase
import FirebaseStorage

class Constants
{
    static var isUserLoggedIn : Bool = false
    static var username : String = ""
    static var id : String = ""
    static var email : String = ""
    
    static var ref = Database.database().reference(fromURL: "https://activak-57cf3-default-rtdb.europe-west1.firebasedatabase.app/")
    static var storageRef = ""
}
