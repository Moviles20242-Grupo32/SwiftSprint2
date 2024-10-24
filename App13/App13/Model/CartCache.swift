//
//  CartCache.swift
//  App13
//
//  Created by Juan Andres Jaramillo on 17/10/24.
//

import Foundation
import SQLite3

class CartCache {
    static let shared = CartCache() // Singleton instance
    
    private var db: OpaquePointer?
    
    private let cache = NSCache<NSString, Cart>() // Cache to store Cart items
    private var keys: [String] = [] // Array to store keys of cached items
    
    // Private initializer to enforce the singleton pattern
    private init() {
        setupDatabase()
        restoreCartCacheFromDatabase()
    }
    
    // This function sets up the SQLite database and creates the table if it doesn't exist
    private func setupDatabase() {
        // Define the database location
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("CartCache.sqlite")
        
        // Open the database
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("DEBUG: Error opening database")
            return
        }
        
        // Create the table if it doesn't exist
        let createTableQuery = """
        CREATE TABLE IF NOT EXISTS Cart (
        id TEXT PRIMARY KEY,
        itemId TEXT,
        itemName TEXT,
        itemCost REAL,
        itemDetails TEXT,
        itemImage TEXT,
        itemRatings TEXT,
        isAdded INTEGER,
        timesOrdered INTEGER,
        quantity INTEGER
        );
        """
        
        if sqlite3_exec(db, createTableQuery, nil, nil, nil) != SQLITE_OK {
            print("DEBUG: Error creating table")
        }
    }

    // Add a Cart item to the cache + database
    func addCartItem(_ item: Cart) {
        cache.setObject(item, forKey: item.id as NSString)
        keys.append(item.id) // Track the key
        saveToDatabase(cart: item) // Save item to SQLite database
        print("DEBUG: Cart item added to Cache. Cache size: \(keys.count)")
    }
    
    // Retrieve a Cart item from the cache
    func getCartItem(byId id: String) -> Cart? {
        return cache.object(forKey: id as NSString)
    }
    
    // Remove a Cart item from the cache
    func removeCartItem(byId id: String) {
        cache.removeObject(forKey: id as NSString)
        keys.removeAll { $0 == id } // Remove the key from the array
        removeFromDatabase(byId: id) // Remove from SQLite database
        print("DEBUG: cart item removed from Cache. Cache size: \(keys.count)")
    }
    
    // Clear all items from the cache
    func clearCache() {
        cache.removeAllObjects()
        keys.removeAll() // Clear keys array
        clearDatabase()
        print("DEBUG: Cache cleared")
    }
    
    // Retrieve all items in the cache (optional)
    func getAllCartItems() -> [Cart] {
        return keys.compactMap { cache.object(forKey: $0 as NSString) }
    }
    
    
    // SQLite Operations

    // Save a Cart item to the SQLite database
    private func saveToDatabase(cart: Cart) {
        var statement: OpaquePointer?
        
        let insertQuery = """
        INSERT OR REPLACE INTO Cart (id, itemId, itemName, itemCost, itemDetails, itemImage, itemRatings, isAdded, timesOrdered, quantity) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        if sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) == SQLITE_OK {
            // Bind the parameters
            sqlite3_bind_text(statement, 1, cart.id, -1, nil)
            sqlite3_bind_text(statement, 2, cart.item.id, -1, nil)
            sqlite3_bind_text(statement, 3, cart.item.item_name, -1, nil)
            sqlite3_bind_double(statement, 4, cart.item.item_cost.doubleValue)
            sqlite3_bind_text(statement, 5, cart.item.item_details, -1, nil)
            sqlite3_bind_text(statement, 6, cart.item.item_image, -1, nil)
            sqlite3_bind_text(statement, 7, cart.item.item_ratings, -1, nil)
            sqlite3_bind_int(statement, 8, cart.item.isAdded ? 1 : 0)
            sqlite3_bind_int(statement, 9, Int32(cart.item.times_ordered))
            sqlite3_bind_int(statement, 10, Int32(cart.quantity))
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("DEBUG: Successfully added cart to database")
            } else {
                print("DEBUG: Failed to add cart to database")
            }
        }
        sqlite3_finalize(statement)
    }

    // Remove a Cart item from the SQLite database by its ID
    private func removeFromDatabase(byId id: String) {
        var statement: OpaquePointer?
        
        let deleteQuery = "DELETE FROM Cart WHERE id = ?;"
        
        if sqlite3_prepare_v2(db, deleteQuery, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, id, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("DEBUG: Successfully removed cart from database")
            } else {
                print("DEBUG: Failed to remove cart from database")
            }
        }
        sqlite3_finalize(statement)
    }

    // Clear all Cart items from the SQLite database
    private func clearDatabase() {
        let deleteAllQuery = "DELETE FROM Cart;"
        
        if sqlite3_exec(db, deleteAllQuery, nil, nil, nil) == SQLITE_OK {
            print("DEBUG: Cleared all cart items from database")
        } else {
            print("DEBUG: Failed to clear cart items from database")
        }
    }
    
    // Restore Cart items from SQLite database and populate the cache
    private func restoreCartCacheFromDatabase() {
        let selectQuery = "SELECT id, itemId, itemName, itemCost, itemDetails, itemImage, itemRatings, isAdded, timesOrdered, quantity FROM Cart;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, selectQuery, -1, &statement, nil) == SQLITE_OK {
            // Loop through the result set and restore the cache
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(statement, 0))
                let itemId = String(cString: sqlite3_column_text(statement, 1))
                let itemName = String(cString: sqlite3_column_text(statement, 2))
                let itemCost = NSNumber(value: sqlite3_column_double(statement, 3))
                let itemDetails = String(cString: sqlite3_column_text(statement, 4))
                let itemImage = String(cString: sqlite3_column_text(statement, 5))
                let itemRatings = String(cString: sqlite3_column_text(statement, 6))
                let isAdded = sqlite3_column_int(statement, 7) == 1
                let timesOrdered = Int(sqlite3_column_int(statement, 8))
                let quantity = Int(sqlite3_column_int(statement, 9))
                
                // Create the Item and Cart instances
                let item = Item(id: itemId, item_name: itemName, item_cost: itemCost, item_details: itemDetails, item_image: itemImage, item_ratings: itemRatings, times_ordered: timesOrdered, isAdded: isAdded)
                let cart = Cart(item: item, quantity: quantity)
                cart.id = id // Use the saved ID
                
                // Restore the cart in the cache
                cache.setObject(cart, forKey: cart.id as NSString)
                keys.append(cart.id)
                
                print("DEBUG: Restored cart with id \(id) from database")
            }
        } else {
            print("DEBUG: Failed to restore cart items from database")
        }
        sqlite3_finalize(statement)
    }
}
