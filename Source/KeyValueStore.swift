//
//  KeyValueStore.swift
//  KeyValueStore
//
//  Created by Matthew Yannascoli on 4/11/16.
//  Copyright © 2016 Matthew Yannascoli. All rights reserved.
//

import Foundation



///
///
///
///
public class KeyValueStore {
    private let directoryURL: NSURL
    private let plistName: String
    
    //Keep an `isLoaded` flag to ensure the local `data` object is populated with
    //the data from the backing file. (We cannot use nil state for data to represent this
    //because it would (legitimately) because data will be nil if nothing has yet been saved to it.
    private var isLoaded: Bool = false
    
    private let queue: NSOperationQueue = {
        let queue = NSOperationQueue()
        queue.qualityOfService = .Background
        return queue
    }()
    
    private var fileURL: NSURL {
        return directoryURL.URLByAppendingPathComponent("/\(plistName).plist")
    }

    //
    private var data: [String: AnyObject] = [:]
    
    ///
    public enum KeyValueStoreError: ErrorType, CustomDebugStringConvertible {
        case InvalidFilePath(string: String)
        case BackingFileError(error: NSError)
        
        public var debugDescription: String {
            switch self {
            case .InvalidFilePath(let path):
                return "Unable to create file at path: \(path)"
            case .BackingFileError(let error):
                return "Unable to create backing file with error: \(error.localizedDescription)"
            }
        }
    }
    
    
    /// Instantiate a base instance
    /// - directoryURL
    /// - plistName
    /// - logOutput
    public required init(directoryURL: NSURL, plistName: String, logOutput: Bool = false) throws {
        self.directoryURL = directoryURL
        self.plistName = plistName
        
        try createContainerDirectoryIfNecessary()
        
        //Logging
        loggingOn = logOutput
    }
    
    
    private func createContainerDirectoryIfNecessary() throws {
        guard let path = directoryURL.relativePath else {
            throw KeyValueStoreError.InvalidFilePath(string: "nil")
        }
        
        let fileManager = NSFileManager.defaultManager()
        if(!fileManager.fileExistsAtPath(path)) {
            do {
                try fileManager.createDirectoryAtURL(self.fileURL, withIntermediateDirectories: true, attributes: nil)
            }
            catch let error as NSError {
                Log("Unable to create backing file with error: \(error.localizedDescription)")
                throw KeyValueStoreError.BackingFileError(error: error)
            }
        }
    }
}





//MARK: - Api -
extension KeyValueStore {
    ///Synchronously fetch file contents from disk
    public func load() {
        data = (NSDictionary(contentsOfURL: fileURL) as? [String: AnyObject]) ?? [:]
        isLoaded = true
    }
    
    ///
    public func load(completion: (() -> Void)?) {
        queue.addOperationWithBlock {
            let fileData = (NSDictionary(contentsOfURL: self.fileURL) as? [String: AnyObject]) ?? [:]
            
            dispatch_async(dispatch_get_main_queue()) {
                self.data = fileData
                self.isLoaded = true
                completion?()
            }
        }
    }
    
    ///
    public func unload() {
        data = [:]
        isLoaded = false
    }
    
    
    /// Synchronously deletes the file in which key-value data is
    /// stored after canceling any enqued safe operations.
    public func delete() throws {
        queue.cancelAllOperations()
        unload()
        
        do {
            try NSFileManager.defaultManager().removeItemAtURL(fileURL)
        }
        catch let error as NSError {
            throw error
        }
    }
    
    
    ///
    public func setValue(value: AnyObject?, forKey key: String) {
        guard isLoaded else {
            Log("You must call one of the `load` methods before setting a new value on the store.")
            return
        }
        
        self.data[key] = value
        self.saveToDisk()
    }
    
    ///
    public func valueForKey(key: String) -> AnyObject? {
        guard isLoaded else {
            Log("Attempting to get a value on a store that is not loaded.")
            return nil
        }
        
        return data[key]
    }
    
    
    private func saveToDisk() {
        guard isLoaded else {
            Log("Cannot save to backing file on a store that is not in a loaded state.")
            return
        }

        queue.addOperationWithBlock {
            (self.data as NSDictionary).writeToURL(self.fileURL, atomically: true)
        }
    }
}




//MARK: - Convenience Accessors -
extension KeyValueStore {
    ///Set a String
    public func setString(string: String, forKey key: String) {
        self.setValue((string as NSString), forKey: key)
    }
    
    ///Retrieve a String
    public func stringForKey(key: String) -> String? {
        return self.valueForKey(key) as? String
    }
    
    ///Set an Int
    public func setInt(value: Int, forKey key: String) {
        self.setValue(NSNumber(integer: value), forKey: key)
    }
    
    ///Retrieve an Int
    public func intForKey(key: String) -> Int? {
        let value = self.valueForKey(key) as? NSNumber
        return value?.integerValue
    }
    
    ///Set a Float
    public func setFloat(value: Float, forKey key: String) {
        self.setValue(NSNumber(float: value), forKey: key)
    }
    
    ///Retrieve an Float
    public func floatForKey(key: String) -> Float? {
        let value = self.valueForKey(key) as? NSNumber
        return value?.floatValue
    }
    
    ///Set a Double
    public func setDouble(value: Double, forKey key: String) {
        self.setValue(NSNumber(double: value), forKey: key)
    }
    
    ///Retrieve a Double
    public func doubleForKey(key: String) -> Double? {
        let value = self.valueForKey(key) as? NSNumber
        return value?.doubleValue
    }
    
    ///Set a bool
    public func setBool(bool: Bool, forKey key: String) {
        self.setValue(NSNumber(bool: bool), forKey: key)
    }
    
    ///Retrieve a bool
    public func boolForKey(key: String) -> Bool? {
        return self.valueForKey(key) as? Bool
    }
    
    ///Set a date
    public func setDate(date: NSDate?, forKey key: String) {
        self.setValue(date, forKey: key)
    }
    
    ///Retrieve a date
    public func dateForKey(key: String) -> NSDate? {
        return self.valueForKey(key) as? NSDate
    }
}




//MARK: - Log -
private var loggingOn: Bool = false
private func Log(message: String, file: String = #file, function: String = #function, line: Int = #line) -> Void {
    guard loggingOn else {
        return
    }
    
    let string = String(
        "\n:-:-:-:-:-:-: KeyValueStore :-:-:-:-:-:-:\n" +
            "File: \(file)\n" +
            "Function: \(function), Line: \(line)\n" +
            message + "\n" +
        ":-:-:-:-:-:-:-:-:-:-:-:-:-:-:-:-:-:-:-:\n"
    )
    
    print(string)
}