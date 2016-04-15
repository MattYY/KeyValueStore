//
//  KeyValueStore.swift
//  KeyValueStore
//
//  Created by Matthew Yannascoli on 4/11/16.
//  Copyright © 2016 Matthew Yannascoli. All rights reserved.
//

import Foundation


public class KeyValueStore {
    private let directoryURL: NSURL
    private let plistName: String
    private let queue = dispatch_queue_create("com.keyvaluestore", DISPATCH_QUEUE_SERIAL)
    
    private var fileURL: NSURL {
        return directoryURL.URLByAppendingPathComponent("/\(plistName).plist")
    }
    
    ///
    private(set) internal var data: [String: AnyObject]?
    
    ///
    public enum KeyValueStoreError: ErrorType, CustomDebugStringConvertible {
        case InvalidFilePath(path: String)
        public var debugDescription: String {
            switch self {
            case .InvalidFilePath(let path):
                return "Archived data cannot be found at file path: \(path)"
            }
        }
    }
    
    
    ///Instantiate a base instance
    /// - directoryURL
    /// - plistName
    /// - logOutput
    public required init(directoryURL: NSURL, plistName: String, logOutput: Bool = false) throws {
        guard let path = directoryURL.relativePath else {
            throw KeyValueStoreError.InvalidFilePath(path: "nil")
        }

        //verify the passed in directoryURL is writeable/readable
        let fileManager = NSFileManager.defaultManager()
        let isWritable = fileManager.isWritableFileAtPath(path)
        let isReadable = fileManager.isReadableFileAtPath(path)
        if !isWritable || !isReadable {
            throw KeyValueStoreError.InvalidFilePath(path: path)
        }
        
        self.directoryURL = directoryURL
        self.plistName = plistName
        
        //Synchronously fetch file contents from disk
        data = NSDictionary(contentsOfURL: fileURL) as? [String: AnyObject]
        
        //Logging
        loggingOn = logOutput
    }
    
    
    /// Deletes the file in which key-value data is stored.
    public func deleteDataFile() throws {
        do {
            try NSFileManager.defaultManager().removeItemAtURL(fileURL)
        }
        catch let error as NSError {
            throw error
        }
    }
}


///Getters/Setters
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





extension KeyValueStore {
    private func saveToDisk() {
        guard let data = self.data else {
            Log("Save to disk aborted because there is no data to save")
            return
        }
        
        guard let path = self.fileURL.relativePath else {
            Log(KeyValueStoreError.InvalidFilePath(path: "\(fileURL)").debugDescription)
            return
        }
        
        dispatch_async(queue) {
            let fileManager = NSFileManager.defaultManager()
            if(!fileManager.fileExistsAtPath(path)) {
                do {
                    try fileManager.createDirectoryAtURL(self.fileURL, withIntermediateDirectories: true, attributes: nil)
                }
                catch let error as NSError {
                    Log("Unable to create file with error: \(error.localizedDescription)")
                }
                
                (data as NSDictionary).writeToURL(self.fileURL, atomically: true)
            }
        }
    }
    
    //Sync
    private func setValue(value: AnyObject?, forKey key: String) {
        if self.data != nil  {
            self.data![key] = value
        }
        else {
            //no data is current stored so create a fresh
            //dictionary if the applied value is not nil
            if let value = value {
                self.data = [key : value]
            }
        }
        
        self.saveToDisk()
    }
    
    private func valueForKey(key: String) -> AnyObject? {
        return data?[key]
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