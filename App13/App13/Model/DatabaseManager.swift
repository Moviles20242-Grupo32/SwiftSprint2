//
//  FirestoreManager.swift
//  App13
//
//  Created by Daniela Uribe on 11/09/24.
//

import SwiftUI
import FirebaseFirestore
import Network

// DatabaseManager class to handle Firestore operations

class DatabaseManager: ObservableObject {
    
    // Singleton instance of DatabaseManager
    static let shared = DatabaseManager()
    
    // Firestore instance, wrapped with @Published to observe changes
    @Published var db: Firestore
    
    @Published var viewModel = AuthViewModel.shared
    
    // Private initializer to enforce the singleton pattern
    private init() {
        db = Firestore.firestore()
        
//        let settings = FirestoreSettings()
//        settings.isPersistenceEnabled = true // Enable offline persistence
//        db.settings = settings
    }

    // Method to fetch items from the "Items" collection in Firestore
    func fetchItems(completion: @escaping ([Item]?, Error?) -> Void) {
        
        // Fetch documents from the "Items" collection
        db.collection("Items").getDocuments { (snap, err) in
            
            // If an error occurs, return the error via completion handler
            if let err = err {
                completion(nil, err)
                return
            }
            
            // If the snapshot is nil, return nil items
            guard let itemData = snap else {
                let customError = NSError(domain: "com.example.database", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to access the Items collection."])
                completion(nil, customError)
                return
            }
            
            // Parse the document data into Item objects
            let items = itemData.documents.compactMap { (doc) -> Item? in
                
                // Extract values from the document
                let id = doc.documentID
                let name = doc.get("item_name") as! String
                let cost = doc.get("item_cost") as! NSNumber
                let ratings = doc.get("item_ratings") as! String
                let image = doc.get("item_image") as! String
                let details = doc.get("item_details") as! String
                let times = doc.get("times_ordered") as! Int
                let item_ingredients = doc.get("item_ingredients") as! String
                let item_starProducts = doc.get("item_starProducts") as! String
                
                // Create and return an Item object
                return Item(id: id, item_name: name, item_cost: cost, item_details: details, item_image: image, item_ratings: ratings, times_ordered: times, isAdded: false, item_ingredients: item_ingredients, item_starProducts: item_starProducts)
            }
            
            // Pass the parsed items to the completion handler
            completion(items, nil)
        }
    }
    
    
    // Method to delete an order for a specific user based on userId
    func deleteOrder(for userId: String, completion: @escaping (Error?) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("Orders").document(userId).delete { (err) in
            completion(err)
        }
    }
        
    // Method to update/set order details
    func setOrder(for userId: String, details: [[String: Any]], ids: [[String: Any]], totalCost: NSNumber, location: GeoPoint, completion: @escaping (Error?) -> Void) {
        let db = Firestore.firestore()
            
        // Update or set the order details in the "Orders" collection for the userId
        db.collection("Orders").document(userId).setData([
            "ordered_food": details,
            "total_cost": totalCost,
            "location": location,
            "user_id": userId
        ]) { (err) in
            // Return any error encountered to the completion handler
            completion(err)
        }
            
            
        // Iterate through each item ID and update 'times_ordered'
        ids.forEach { id in
            let itemId = id["id"] as? String ?? "Unknown"
            let quantity = id["num"] as? Int ?? 0
            
            // Fetch the current 'times_ordered' value
            db.collection("Items").document(itemId).getDocument { (document, error) in
                if let document = document, document.exists {
                    let currentTimesOrdered = document.data()?["times_ordered"] as? Int ?? 0
                    
                    // Update 'times_ordered' by adding the incoming quantity
                    db.collection("Items").document(itemId).updateData([
                        "times_ordered": currentTimesOrdered + quantity
                    ]) { err in
                        if let err = err {
                            print("Error updating times_ordered: \(err)")
                        } else {
                            print("Successfully updated times_ordered for item \(itemId)")
                        }
                    }
                } else {
                    print("Document does not exist for item \(itemId)")
                }
            }
        }
            
            
    }
    
    // Async method to fetch a user document from Firestore by user ID
    func fetchUser(uid: String) async throws -> User? {
        print("En Database manager" + uid)
        do {
            // Attempt to fetch the document from Firestore
            let snapshot = try await db.collection("users").document(uid).getDocument()

            // Check if the document exists
            if snapshot.exists {
                // Log the raw data returned from Firestore
                let data = snapshot.data()
                print("DEBUG: Fetched user data: \(String(describing: data))")
                
                // Attempt to decode the document into the User object
                return try snapshot.data(as: User.self)
            } else {
                // If no document exists for the given UID
                print("DEBUG: No document found for user UID: \(uid)")
                return nil
            }
        } catch {
            // Log any errors that occur during fetching or decoding
            print("DEBUG: Error fetching user data: \(error)")
            throw error
        }
    }
    
    func fetchUserByEmail(email: String) async throws -> User? {
        do {
            // Query the "users" collection where the "email" field matches the given email
            let querySnapshot = try await db.collection("users")
                .whereField("email", isEqualTo: email)
                .getDocuments()

            // Check if there are any documents that match the query
            if let document = querySnapshot.documents.first {
                // Log the raw data returned from Firestore
                let data = document.data()
                print("DEBUG: Fetched user data by email: \(String(describing: data))")
                
                // Attempt to decode the document into the User object
                return try document.data(as: User.self)
            } else {
                // If no document matches the email
                print("DEBUG: No user found with email: \(email)")
                return nil
            }
        } catch {
            // Log any errors that occur during the fetching or decoding
            print("DEBUG: Error fetching user by email: \(error)")
            throw error
        }
    }

    // Async method to create a new user in the "users" collection
    func createUser(user: User) async throws {
        print("Creando usuario")
        // Encode the User object to a Firestore-compatible format
        let encodedUser = try Firestore.Encoder().encode(user)
        // Save the encoded user data to Firestore
        try await db.collection("users").document(user.id).setData(encodedUser)
        print("Usuario creado")
    }
    
    func saveSearchUse(finalValue: String) {
        let timestamp = Timestamp()
        let data: [String: Any] = [
            "finalValue": finalValue,
            "timestamp": timestamp,
            "userId": currentUser?.id as Any
        ]

        db.collection("searchUse").addDocument(data: data) { error in
            if let error = error {
                print("Error saving search use: \(error)")
            } else {
                print("Search use successfully saved!")
            }
        }
    }
        
    func saveElapsedTimeToCheckout(_ elapsedTime: NSNumber){
        let timestamp = Timestamp()
        let data: [String: Any] = [
            "elapsed_time": elapsedTime,
            "timestamp": timestamp,
            "userId": currentUser?.id as Any
        ]

        db.collection("elapsed_time").addDocument(data: data) { error in
            if let error = error {
                print("DEBUG: Error saving elapsed time to checkout: \(error)")
            } else {
                print("DEBUG: Elapsed time to checkout successfully saved.")
            }
        }
    }
    
    func saveUserSpendings( amountSpent: NSNumber){
        let timestamp = Timestamp()
        let data: [String: Any] = [
            "amount_spent": amountSpent,
            "timestamp": timestamp,
            "userId": currentUser?.id as Any
        ]

        db.collection("user_spendings").addDocument(data: data) { error in
            if let error = error {
                print("DEBUG: Error saving amount spent by user \(currentUser?.id ?? "???"): \(error)")
            } else {
                print("DEBUG: user spendings successfully saved.")
            }
        }
    }

    func saveStarFilterUse() {
        let timestamp = Timestamp()
        let data: [String: Any] = [
            "timestamp": timestamp,
            "userId": currentUser?.id as Any
        ]

        db.collection("starFilterUse").addDocument(data: data) { error in
            if let error = error {
                print("Error saving star filter use: \(error)")
            } else {
                print("Star filter use successfully saved!")
            }
        }
    }
    
    func saveRecentSearchFilterUse() {
        let timestamp = Timestamp()
        let data: [String: Any] = [
            "timestamp": timestamp,
            "userId": currentUser?.id as Any
        ]

        db.collection("recentSearchFilterUse").addDocument(data: data) { error in
            if let error = error {
                print("Error saving star filter use: \(error)")
            } else {
                print("Star filter use successfully saved!")
            }
        }
    }
    
    //  In the last month, what percentage of users used the track the order feature ? Type 3 Juan
    func saveTrackOrderFeatureUse(){
        let timestamp = Timestamp()
        let data: [String: Any] = [
            "timestamp": timestamp,
            "userId": currentUser?.id as Any
        ]

        db.collection("trackOrderFeatureUse").addDocument(data: data) { error in
            if let error = error {
                print("Error saving star filter use: \(error)")
            } else {
                print("track Order Feature Use successfully saved!")
            }
        }
    }
    
    func saveCloseFoodies() {
        let timestamp = Timestamp()
        let data: [String: Any] = [
            "timestamp": timestamp,
            "id": currentUser?.id as Any
        ]

        db.collection("closeFoodies").addDocument(data: data) { error in
            if let error = error {
                print("Error saving star filter use: \(error)")
            } else {
                print("Star filter use successfully saved!")
            }
        }
    }
    
    func saveNoOrderNotfication() {
        let timestamp = Timestamp()
        let data: [String: Any] = [
            "timestamp": timestamp,
            "id": currentUser?.id as Any
        ]

        db.collection("NoOrderNotfication").addDocument(data: data) { error in
            if let error = error {
                print("Error saving star filter use: \(error)")
            } else {
                print("Star filter use successfully saved!")
            }
        }
    }

}
