//
//  HomeViewModel.swift
//  App13
//
//  Created by Daniela Uribe on 28/08/24.
//

import SwiftUI
import CoreLocation
import Firebase
import FirebaseAuth
import Foundation
import AVFoundation
import Combine

class HomeViewModel: NSObject,ObservableObject,CLLocationManagerDelegate{
    
    @Published var locationManager = CLLocationManager()
    @Published var search = ""
    
    //Location details
    @Published var userLocation : CLLocation?
    @Published var userAdress = ""
    @Published var noLocation = false
    
    //Menu
    @Published var showMenu = false
    
    //ItemData
    @Published var items: [Item] = []
    @Published var filtered: [Item] = []
    private var allItems: [Item] = []
    @Published var favorite: Item? = nil
    
    @Published var cartItems: [Cart] = []
    //    @Published var ordered = false
    
    @State private var synthesizer: AVSpeechSynthesizer?
    
    @Published var showAlert = false
    @Published var alertMessage = ""
    var orderValue: Decimal = 0
    
    @Published var showLocationAlert = false
    
    static let shared = HomeViewModel()
    
    @Published var recentSearches: [String] = []
    
    // Track Order
    @Published var activeOrders: [Cart] = []
    
    override private init() {
        super.init() // Call the super init first
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        // loadCartItems() // load cart items saved in cache.
        self.favorite = CacheManager.shared.getFavoriteItem()
        
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse:
            print("autorizado")
            self.noLocation = false
            manager.requestLocation()
        case .denied:
            print("denegado")
            self.noLocation = true
        default:
            print("desconocido")
            self.noLocation = false
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        print(error.localizedDescription)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.userLocation = locations.last
        self.extractLocation()
        self.login()
    }
    
    func extractLocation(){
        CLGeocoder().reverseGeocodeLocation(self.userLocation!){ (res, err) in
            guard let safeData = res else{return}
            
            var address = ""
            
            address += safeData.first?.name ?? ""
            address += ", "
            address += safeData.first?.locality ?? ""
            
            self.userAdress = address
        }
    }
    
    
    //Anonymus login for reading Database
    
    func login(){
        Auth.auth().signInAnonymously{ (res, err) in
            
            if err != nil{
                print(err!.localizedDescription)
                return
            }
            
            print("Sucess \(res!.user.uid)")
            self.fetchData()
            
            
        }
    }
    
    func fetchData() {
        
        guard isConnected else {
            DispatchQueue.main.async {
                // No internet connection
                self.items = []
                self.filtered = []
                self.favorite = nil
                print("No internet connection. Items, filtered, and favorite are set to nil.")
            }
            return
        }
        
        DatabaseManager.shared.fetchItems { [weak self] (items, error) in
            if let error = error {
                print("Error fetching items: \(error.localizedDescription)")
                return
            }
            
            for item in self!.items{
                print("Agregado \(item.item_name) \(item.isAdded)")
            }
            
            if let items = items {
                DispatchQueue.main.async {
                    self?.items = items
                    self?.filtered = items
                    
                    let favItem = CacheManager.shared.getFavoriteItem()
                    if favItem != nil {
                        self?.favorite = favItem
                    }else{
                        self?.favorite = self?.getFavorite()
                    }
                    self?.loadCartItems()
                }
            }
        }
    }
    
    func filterData(){
        withAnimation(.linear){
            self.filtered = self.filtered.filter{
                return $0.item_name.lowercased().contains(self.search.lowercased())
            }
        }
    }
    
    func addLastOrderToCart() {
        // Retrieve the last order from the cache
        guard let lastOrder = getLastOrder() else {
            print("DEBUG: No last order found to add to cart.")
            let alertController = UIAlertController(
                title: "No hay ordenes recientes",
                message: "No ha hecho ninguna orden reciente",
                preferredStyle: .alert
            )
            
            // Add an OK button to the alert
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alertController.addAction(okAction)
            
            // Present the alert
            if let viewController = UIApplication.shared.keyWindow?.rootViewController {
                viewController.present(alertController, animated: true, completion: nil)
            }
            return
        }
        
        // Loop through each item in the last order and add it to the cart
        for cartItem in lastOrder {
            // Find the index of the item in the items list
            let index = getIndex(item: cartItem.item, isCartIndex: false)
            
            // Ensure the item exists in `items` before proceeding
            if index >= 0 && index < items.count {
                
                // Check if the item is already in the cart
                if !cartItems.contains(where: { $0.item.id == cartItem.item.id }) {
                    // If not in the cart, add it to cartItems and cache
                    addToCart(item: cartItem.item)
                }
                
            } else {
                print("DEBUG: Item not found in items list for \(cartItem.item.item_name)")
            }
        }
        
        print("DEBUG: Last order items added to cart successfully.")
    }
    
    func addToCart(item:Item){
        
        let index = getIndex(item: item, isCartIndex: false)
        let filteredIndex = self.filtered.firstIndex { (item1) -> Bool in
            return item.id == item1.id
        } ?? 0
        
        // Toggle the isAdded state
        items[index].toggleIsAdded()
        if items[index].id != filtered[filteredIndex].id { //is this necessary?
            filtered[filteredIndex].toggleIsAdded()
        }

        
        // Adds the added item to the cartitems and the cache.
        if  items[index].isAdded {
            let newCartItem = Cart(item: items[index], quantity: 1)
            cartItems.append(newCartItem)
            CacheManager.shared.addCartItem(newCartItem) // Cache the item
        } else { //removes de item from the cart and the cache.
            let removedElement = cartItems.remove(at: getIndex(item: item, isCartIndex: true))
            CacheManager.shared.removeCartItem(byId: removedElement.id)
        }
        
    }
    
    func getIndex(item: Item, isCartIndex: Bool)->Int{
        
        let index = self.items.firstIndex{ (item1)->Bool in
            return item.id == item1.id
        } ?? 0
        
        let cartIndex = self.cartItems.firstIndex{ (item1)->Bool in
            return item.id == item1.item.id
        } ?? 0
        
        return isCartIndex ? cartIndex : index
    }
    
    func calculateTotalPrice() -> String {
        
        orderValue = 0
        
        for index in cartItems.indices {
            let cartItem = cartItems[index]
            let quantity = Decimal(cartItem.quantity)
            let unit_cost = cartItem.item.item_cost.decimalValue
            orderValue += quantity * unit_cost
        }
        
        return getPrice(value: orderValue as NSNumber)
    }
    
    func getPrice(value: NSNumber) -> String {
        
        let format = NumberFormatter()
        format.numberStyle = .currency
        
        return format.string(from: value) ?? ""
    }
    
    func updateOrder() {
        // Adding a delay of 1 second before executing the rest of the code
        DispatchQueue.main.asyncAfter(deadline: .now()) { [weak self] in
            guard let self = self else { return }
            
            
            if cartItems.isEmpty {
                
                let alertController = UIAlertController(
                    title: "Carrito vacío",
                    message: "Añada artículos al carrito para realizar su orden ",
                    preferredStyle: .alert
                )
                
                // Add an OK button to the alert
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alertController.addAction(okAction)
                
                // Present the alert
                if let viewController = UIApplication.shared.keyWindow?.rootViewController {
                    viewController.present(alertController, animated: true, completion: nil)
                }
                
                return
                
            }
            
            let userId = Auth.auth().currentUser!.uid

            var details: [[String: Any]] = []
            var items_ids: [[String: Any]] = []
            
            for index in cartItems.indices {
                let cart = cartItems[index]
                
                details.append([
                    "item_name": cart.item.item_name,
                    "item_quantity": cart.quantity,
                    "item_cost": cart.item.item_cost
                ])
                
                items_ids.append([
                    "id": cart.item.id,
                    "num": cart.quantity
                ])
            }

            
            // Call DatabaseManager to set the order
            DatabaseManager.shared.setOrder(for: userId, details: details, ids: items_ids,  totalCost: calculateTotalPrice(), location: GeoPoint(latitude: userLocation?.coordinate.latitude ?? 0, longitude: userLocation?.coordinate.longitude ?? 0)) { error in
                        if let error = error {
                            print("Error setting order: \(error)")
                        }
                    }
            print(userId)
            
            for cart in cartItems {
                let index = getIndex(item: cart.item, isCartIndex: false)
                let filteredIndex = self.filtered.firstIndex { (item1) -> Bool in
                    return cart.item.id == item1.id
                } ?? 0
                
                // Toggle the isAdded state
                items[index].toggleIsAdded()
                
                if items[index].id != filtered[filteredIndex].id {
                    filtered[filteredIndex].toggleIsAdded()
                }
                
                activeOrders.append(cart)
            }
            
            CacheManager.shared.clearCartCache()
            CacheManager.shared.addOrder(cartItems)
            cartItems.removeAll()
                
            let alertController = UIAlertController(
                title: "Orden realizada",
                message: "Su orden se ha realizado con éxito.",
                preferredStyle: .alert
            )
            
            // Add an OK button to the alert
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alertController.addAction(okAction)
            
            // Present the alert
            if let viewController = UIApplication.shared.keyWindow?.rootViewController {
                viewController.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    
    func calculateTotalPrice() -> NSNumber {
        // Assuming there's logic here to calculate total price
        return cartItems.reduce(0) { $0 + $1.item.item_cost.floatValue * Float($1.quantity) } as NSNumber
    }
    
    func getFavorite() -> Item? {
        let favItem = items.max(by: { $0.times_ordered < $1.times_ordered })
        if favItem?.times_ordered == 0 {
            return nil
        }
        CacheManager.shared.addFavoriteItem(favItem)
        return favItem
    }
    
    func saveSearchUse(finalValue: String) {
        DatabaseManager.shared.saveSearchUse(finalValue: finalValue)
    }
    
    func saveElapsedTimeToCheckout(_ elapsedTime: NSNumber){
        if !cartItems.isEmpty {
            DatabaseManager.shared.saveElapsedTimeToCheckout(elapsedTime)
        }
    }
    
    func saveUserSpendings(){
        if orderValue != 0 {
            DatabaseManager.shared.saveUserSpendings(amountSpent: orderValue as NSNumber)
        }
    }
    
    func filterHighRatedItems(showHighRated: Bool) {
        if showHighRated {
            saveStarFilterUse()
            filtered = items.filter { $0.item_ratings == "5" }
        } else {
            filtered = items // Reset to show all items
        }
    }
    
    func filterLastSearch(showRecentSearch: Bool) {
        if showRecentSearch {
            saveRecentSearchFilterUse()
            getRecentSearches()
            if let lastSearch = self.recentSearches.last {
                filtered = items.filter{$0.item_name.lowercased().contains(lastSearch.lowercased())}
            }
            else{
                filtered=[]
                let alertController = UIAlertController(
                    title: "No hay busquedas recientes",
                    message: "No se puede filtrar por busqueda reciente",
                    preferredStyle: .alert
                )
                
                // Add an OK button to the alert
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alertController.addAction(okAction)
                
                // Present the alert
                if let viewController = UIApplication.shared.keyWindow?.rootViewController {
                    viewController.present(alertController, animated: true, completion: nil)
                }
                
            }
        } else {
            filtered = items // Reset to show all items
        }
    }
    
    //Function to increment or decrement the quantity to be ordered of an item in the cart.
    func incrementDecrementItemQuantity(index: Int, operation: String){
        
        if operation == "+"{
            let modifiedCart = self.cartItems[index].incrementQuantity()
            self.cartItems[index] = modifiedCart
        }
        else if operation == "-" {
            let modifiedCart2 = self.cartItems[index].decrementQuantity()
            self.cartItems[index] = modifiedCart2        }
    }
    
    // Function to retrieve cart items from the cache
    func loadCartItems() {
        
        // Load items from cache
        CacheManager.shared.restoreCartCacheFromDatabase(items: items)
        print("DEBUG loadCartItem: \(CacheManager.shared.getAllCartItems().count)")
        
        cartItems=[]
        for cartItem in CacheManager.shared.getAllCartItems() {
            cartItems.append(cartItem)
        }
    }
    
    // Function to clear the cart
    func clearCart() {
        cleanItems()
        cartItems.removeAll()
        activeOrders.removeAll()
        CacheManager.shared.clearCartCache()
    }
    
    func saveStarFilterUse() {
        DatabaseManager.shared.saveStarFilterUse()
    }
    
    func saveRecentSearchFilterUse() {
        DatabaseManager.shared.saveRecentSearchFilterUse()
    }
    
    func saveTrackOrderFeatureUse(){
        DatabaseManager.shared.saveTrackOrderFeatureUse()
    }
    
    
    // function to clean items and the favorite Cache.
    func cleanItems(){
        for index in cartItems.indices {
            cartItems[index].item.toggleIsAdded()
        }

        CacheManager.shared.clearFavoriteCache()
    }
    
    func getItem(id:String ) -> Item? {
        for item in items {
            if item.id == id {
                return item
            }
        }
        return nil
    }
    
    func getLastOrder() -> [Cart]? {
        guard let lastOrder = CacheManager.shared.getLastOrder() else {
            print("DEBUG: No last order found in cache. Attempting to restore from database...")
            
            // If not in cache, restore it from the database
            CacheManager.shared.restoreLastOrderCacheFromDatabase(items: items)
            
            // Try fetching again after restoration
            if let restoredOrder = CacheManager.shared.getLastOrder() {
                print("DEBUG: Successfully restored last order from database.")
                return restoredOrder
            } else {
                print("DEBUG: No last order found even after database restoration.")
                return nil
            }
        }
        return lastOrder
    }
    
    func saveSearch(finalValue: String) {
        // Get current searches from UserDefaults
        var recentSearches = UserDefaults.standard.stringArray(forKey: "recentSearches") ?? []
        
        // Append the new search value
        recentSearches.append(finalValue)
        
        // Limit the number of stored searches (e.g., keep the last 10 searches)
        if recentSearches.count > 10 {
            recentSearches.removeFirst()
        }
        
        // Save the updated array back to UserDefaults
        UserDefaults.standard.set(recentSearches, forKey: "recentSearches")
        print("Save #: ",recentSearches.count)
    }
    
    func getRecentSearches() {
        self.recentSearches = UserDefaults.standard.stringArray(forKey: "recentSearches") ?? []
        print("Get #:",recentSearches.count)
    }
    
}
