//
//  KeyValueStore.swift
//  KeyValueStore
//
//  Created by Matthew Yannascoli on 4/11/16.
//  Copyright © 2016 Matthew Yannascoli. All rights reserved.
//

import Foundation

/// KeyValueStore (store) is a simple key-value storage class that persists data asynchronously to
/// disk while providing a synchronous setter/getter interface. KeyValueStore also allows you
/// to easily create unique storage instances by passing in a `filePath` that is passed in during
/// class instantiation. This is convenient if you want to quickly switch preference states.
///
/// To maintain a synchronous interface but write to disk off the main thread an in-memory 
/// dictionary (`data`) is kept in sync with a backing plist file. This synchronization
/// commences once one of the `load` methods is called (load or load:) which is necessary precusor
/// for using the store. Conversely the `unload` can be used "empty" the in-memory storage object
/// to free up space in constrained situations.
///
/// That said, the intention of this class is to support a relatively small amount of key-value
/// pairs so consider other implementations if you find yourself needing to store thousands or
/// even hundreds of items.
///
public class KeyValueStore {
    
    //MARK: Private
    private let filePath: String
    private let queue: NSOperationQueue = {
        let queue = NSOperationQueue()
        queue.qualityOfService = .Background
        return queue
    }()

    ///In-memory storage for the key-value pairs.
    private(set) internal var data: [String: NSCoding] = [:]
    
    //MARK: Public
    ///Custom Errors
    public enum KeyValueStoreError: ErrorType, CustomDebugStringConvertible {
        /// A custom error that will occur if the backing file cannot be created
        /// at the specified `filePath`.
        case InvalidFilePath(path: String)
        public var debugDescription: String {
            switch self {
            case .InvalidFilePath(let path):
                return "Unable to write/read file at path: \(path)"
            }
        }
    }
    
    /// Indicates whether the store's backing file has successfully been initialized.  This
    /// must be `true` for the `setValue` or `valueForKey` methods to be usable.
    public var isLoaded: Bool = false
    
    
    /// Instantiate a base instance.  Even though `filePath` is passed in here the backing
    /// file is not created until one of the `load` methods is called.  If the `filePath`
    /// is an invalid path the store instance will be unusable.
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
    /// instance with a valid `filePath`.
    ///
    /// Return a `Bool` to represent whether the resulting state is loaded.
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
    /// - `completion` : An optional block that is called after the backing file is loaded or
    ///   created. If `filePath` is cannot be read or written to/from an `InvalidFilePath`
    ///   error will be returned.
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
    
    
    /// Asynchronously empties the store's in-memory `data` object but does not delete the
    /// backing plist file. Any data that may be in the process of saving will be commited to disk 
    /// before `data`'s contents is released. After calling `unload` the store will be in an
    /// unusable state until load or load(_:) is called.
    public func unload(completion: (() -> Void)? = nil) {
        queue.addOperationWithBlock {
            dispatch_async(dispatch_get_main_queue()) {
                self.data = [:]
                self.isLoaded = false
                completion?()
            }
        }
    }
    
    
    /// Synchronously deletes the store's backing plist file and empties the in-memory data object.
    /// Calling load or load(_:) after this point will result in a fresh plist being created at
    /// the `filePath` specified during instantiation.
    public func delete() throws {
        queue.cancelAllOperations()
        
        self.data = [:]
        self.isLoaded = false
        
        do {
            try NSFileManager.defaultManager().removeItemAtPath(filePath)
        }
        catch let error as NSError {
            throw error
        }
    }
    
    /// Sets a `value` for a `key` in the store.  The in-memory `data` object will be updated
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
    
    private func loadOrCreate() -> (data: [String: NSCoding], loaded: Bool, error: ErrorType?) {
        let resultData: [String: NSCoding]
        let loaded: Bool
        let error: KeyValueStoreError?
        
        //Load a file
        let fileData = NSDictionary(contentsOfFile: self.filePath) as? [String: NSCoding]
        
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