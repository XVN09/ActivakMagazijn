//
//  MyUser.swift
//  ActivakMagazijn1.0
//
//  Created by Xander Van nuffel on 20/08/2023.
//

import Foundation

class MyUser {
    
    var Email : String
    var FirstName : String
    var LastName : String
    var PhoneNumber : String
    var isAdmin : Bool
    var usrBarcode : String
    
    init()
        {
            Email = ""
            FirstName = ""
            LastName = ""
            PhoneNumber = ""
            isAdmin = false
            usrBarcode = ""
        }
    
    func setData(email : String, firstname : String, lastname : String, phonenumber : String, isadmin : Bool, userbarcode : String) {
        Email = email
        FirstName = firstname
        LastName = lastname
        PhoneNumber = phonenumber
        isAdmin = isadmin
        usrBarcode = userbarcode
    }
}
