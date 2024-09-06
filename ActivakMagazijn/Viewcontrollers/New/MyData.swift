//
//  MyData.swift
//  ActivakMagazijn1.0
//
//  Created by Xander Van nuffel on 14/04/2023.
//

import Foundation

class MyData {
    
    var imgURL: String
    var titleText: String
    var placeText: String
    var priceText: String
    var descText: String
    var catText: String
    var barText: String
    var isFavorite: Bool
    var favoriteStatus: [String: Bool] = [:]
    var basisStock: String
    var randomKey: String
    var isTracked: Bool
    var locaties: [String: Location] = [:] // Location information
    
    // Function to update the favorite status for a user
    func setFavoriteStatus(_ isFavorite: Bool, forUser userUID: String) {
        favoriteStatus[userUID] = isFavorite
    }
    
    // Function to get the favorite status for a user
    func getFavoriteStatus(forUser userUID: String) -> Bool {
        return favoriteStatus[userUID] ?? false
    }
    
    init() {
        imgURL =  ""
        titleText = ""
        placeText = ""
        priceText = ""
        descText = ""
        catText = ""
        barText = ""
        isFavorite = false
        basisStock = ""
        randomKey = ""
        isTracked = false
    }
    
    func setData(url: String, title: String, place: String, price: String, descripiton: String, category: String, barcode: String, stock: String, randomkey: String, istracked: Bool, locaties: [String: Location]) {
        imgURL = url
        titleText = title
        placeText = place
        priceText = price
        descText = descripiton
        catText = category
        barText = barcode
        basisStock = stock
        randomKey = randomkey
        isTracked = istracked
        self.locaties = locaties // Setting location information
    }
}

struct Location {
    let aantal: String
    let locatie: String
}
