//
//  KeyValueStore.swift
//  KeyValueStore
//
//  Created by Matthew Yannascoli on 4/11/16.
//  Copyright © 2016 Matthew Yannascoli. All rights reserved.
//

import Foundation

/// KeyValueStore (store) is a simple key-value storage class that persists data asynchronously to
/// disk while providing a synchronous setter/getter interface. Additionally KeyValueStore
/// Allows the sandboxing of instances based on a `filePath` that is passed in during class
/// instantiation. This enables one to create different stores for different users, for example.
///
/// To maintain a synchronous interface but write to disk off the main thread an in-memory 
/// dictionary (`data`) and a backing plist file are kept in a synchronized state. This
/// synchronization commences once one of the `load` methods are called (load or load:) and
/// is a necessary precusor for setting/getting data from the store.
///
/// The intention of this class is to support a relatively small amount of key-value pairs,
/// and to satisfy the requirements of most user preference needs. Be aware that this class
/// stores your pairs in an in-memory dictionary and could contribute to memory pressure if
/// an abundance of data is stored.  The `unload` method can be used to release this pressure
/// at the expense of the store becoming unusable until `load` is again called.

public class KeyValueStore {
    private let filePath: String
    
    //Keep an `isLoaded` flag to ensure the local `data` object is populated with
    //the data from the backing file. (We cannot use nil state for data to represent this
    //because it would (legitimately) because data will be nil if nothing has yet been saved to it.
    private var isLoaded: Bool = false
    
    private let queue: NSOperationQueue = {
        let queue = NSOperationQueue()
        queue.qualityOfService = .Background
        return queue
    }()
    
    private typealias DataType = [String: NSCoding]

    //In-memory storage for the key-value pairs.
    private var data: DataType = [:]
    
    ///
    public enum KeyValueStoreError: ErrorType, CustomDebugStringConvertible, CustomStringConvertible {
        
        /// A custom error that will occur if the backing file cannot be created
        /// at the specified `filePath`
        case InvalidFilePath(path: String)
        
        public var debugDescription: String {
            switch self {
            case .InvalidFilePath(let path):
                return "Unable to write/read file at path: \(path)"
            }
        }
        
        public var description: String {
            switch self {
            case .InvalidFilePath(let path):
                return "Unable to write/read file at path: \(path)"
            }
        }
    }
    
    
    /// Instantiate a base instance.  Even though `filePath` is passed in here the backing
    /// file is not created until one of the `load` methods is called.  If the `filePath`
    /// is an invalid path the store will instance will be unusable.
    ///
    /// - `filePath`: Path to the backing string file.  If none exists one will be
    ///   be created at the specified path.
    ///
    /// - `logOutput`: An optional flag that determines whether debugging info is printed
    ///   to the console.
    ///
    public required init(filePath: String, logOutput: Bool = false) {
        self.filePath = filePath

        //Logging
        loggingOn = logOutput
    }
}





//MARK: - Api -
extension KeyValueStore {
    
    /// Synchronously fetch the backing file at `filePath` from disk. If no file currently
    /// exists the creation of an empty file is attempted.  If this creation fails
    /// the store is stuck in an unloaded state and can only be "fixed" by creating a new
    /// instance with a valid filePath.
    ///
    /// Return a `Bool` to represend whether the resulting state is loaded.
    ///
    public func load() -> Bool {
        guard !isLoaded else {
            Log("Calling `load` but store is already loaded.")
            return true
        }
        
        let result = self.loadOrCreate()
        self.data = result.data
        self.isLoaded = result.loaded
        
        return isLoaded
    }
    
    
    /// Has similar functionality to `load` however disk operations occur asynchronously
    /// on a background queue.
    ///
    /// - `comletion` : An optional completion block that is called when the load action 
    ///   completes. Completion can return an `InvalidFilePath` error.
    ///
    public func load(completion: ((error: ErrorType?) -> Void)?) {
        guard !isLoaded else {
            Log("Calling `load` but store is already loaded.")
            return
        }
        
        queue.addOperationWithBlock {
            let result = self.loadOrCreate()
            
            dispatch_async(dispatch_get_main_queue()) {
                self.data = result.data
                self.isLoaded = result.loaded
                completion?(error: result.error)
            }
        }
    }
    
    
    /// Empties the store's backing in-memory data object but does not delete the backing.
    /// plist file.  Store is unusable without another call to one of the `load` methods.
    /// Useful for freeing memory in constrainted situations.
    public func unload() {
        data = [:]
        isLoaded = false
    }
    
    
    /// Synchronously delete the store's backing data file and clear the in-memory data object.
    /// The store object will not be usable after this point until load is again called.
    public func delete() throws {
        queue.cancelAllOperations()
        unload()
        
        do {
            try NSFileManager.defaultManager().removeItemAtPath(filePath)
        }
        catch let error as NSError {
            throw error
        }
    }
    
    /// Sets a `value` for a `key` in the store.  The in-memory data object will be updated
    /// immediately but the propogation to disk will happen asynchronously on a background queue.
    /// If the store is in an unloaded state `setValue` will return without setting the in-memory
    /// object or underlying backing file.
    ///
    /// - `value` : must conform to NSCoding
    /// - `key` : must be a String
    ///
    public func setValue<T: NSCoding>(value: T?, forKey key: String) {
        guard isLoaded else {
            Log("You must call one of the `load` methods before setting a new value on the store.")
            return
        }
        
        self.data[key] = value
        self.saveToDisk()
    }
    
    
    /// Return a value for a `key`.  If no value exists return nil.
    public func valueForKey<T: NSCoding>(key: String) -> T? {
        guard isLoaded else {
            Log("Attempting to get a value on a store that is not loaded.")
            return nil
        }
        
        return data[key] as? T
    }
    
}


//MARK: - Disk Operations -
extension KeyValueStore {
    
    private func loadOrCreate() -> (data: DataType, loaded: Bool, error: ErrorType?) {
        let resultData: DataType
        let loaded: Bool
        let error: KeyValueStoreError?
        
        //Load a file
        let fileData = NSDictionary(contentsOfFile: self.filePath) as? DataType
        
        //If load succeeds...
        if let fileData = fileData {
            resultData = fileData
            loaded = true
            error = nil
        }
        else {
            //If load returns as nil it means that no backing file yet exists at the
            //specified filePath.  In this case we try to create a file but this fails the
            //filePath is determined to be invalid.
            resultData = [:]
            
            let createdFile = ([:] as NSDictionary).writeToFile(self.filePath, atomically: true)
            if !createdFile {
                error = KeyValueStoreError.InvalidFilePath(path: self.filePath)
                loaded = false
            }
            else {
                error = nil
                loaded = true
            }
        }
        
        if let error = error {
            Log(error.debugDescription)
        }
        
        return (data: resultData, loaded: loaded, error: error)
    }
    
    
    private func saveToDisk() {
        guard isLoaded else {
            Log("Cannot save to backing file on a store that is not in a loaded state.")
            return
        }
        
        queue.addOperationWithBlock {
            (self.data as NSDictionary).writeToFile(self.filePath, atomically: true)
        }
    }
}



//MARK: - Log -
private var loggingOn: Bool = false
private func Log(message: String, file: String = #file, function: String = #function, line: Int = #line) -> Void {
    guard loggingOn else {
        return
    }
    
    let string = String(
        "\n:-:-:-:-:-:-: KeyValueStore :-:-:-:-:-:\n" +
            "File: \(file)\n" +
            "Function: \(function), Line: \(line)\n" +
            message + "\n" +
        ":-:-:-:-:-:-:-:-:-:-:-:-:-:-:-:-:-:-:-:\n"
    )
    
    print(string)
}