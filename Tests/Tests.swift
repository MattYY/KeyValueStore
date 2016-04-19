//
//  Tests.swift
//  Tests
//
//  Created by Matthew Yannascoli on 4/11/16.
//  Copyright © 2016 Matthew Yannascoli. All rights reserved.
//

import XCTest
@testable import KeyValueStore


let DefaultFileName = "TestFile.plist"

class Tests: XCTestCase {
    var store: KeyValueStore?
    var key: String?
    var value: NSCoding?
}

//Tests
extension Tests {
    
    override func tearDown() {
        super.tearDown()
        deleteFileWithName(DefaultFileName)
    }

    func testSyncLoadWithInvalidPathReturnsError() {
        whenIIntializeAStoreWithAnInvalidPath()
        thenSynchronousLoadReturnsFalse()
    }
    
    func testAsyncLoadWithInvalidPathReturnsError() {
        whenIIntializeAStoreWithAnInvalidPath()
        thenAnAsynchronousLoadReturnsFalse()
    }
    
    func testSavingAnNSDate() {
        givenAStore()
        whenILoadAStoreSynchronously()
        whenISaveADateInTheDistantPast()
        thenTheStoreReturnsTheCorrectDate()
    }
    
    func testSavingAnInt() {
        givenAStore()
        whenILoadAStoreSynchronously()
        whenISaveAnInt()
        thenTheStoreReturnsTheCorrectInt()
    }
    
    func testSavingAnNSDatewithoutLoadingStoreReturnsNil() {
        givenAStore()
        whenISaveADateInTheDistantPast()
        thenTheStoreReturnsANilValue()
    }
    
    func testDeletingAStoreRemovesFileAndIsUnloaded() {
        givenAStore()
        whenILoadAStoreSynchronously()
        thenTheBackingPlistExists()
        
        whenIDeleteTheStore()
        
        thenTheBackingPlistIsDeleted()
        thenTheStoreIsInAnUnloadedState()
    }
    
    func testAnUnloadedStoreIsProperlyReloaded() {
        givenAStore()
        whenILoadAStoreSynchronously()
        whenISaveADateInTheDistantPast()
        
        thenUnloadTheStore()
        thenTheStoreReturnsANilValue()
        
        whenILoadAStoreAsynchronously()
        thenTheStoreReturnsTheCorrectDate()
    }
}


//Given
extension Tests {
    
    func givenAStore() {
        let docPath = documentsPathWithName(DefaultFileName)
        store = KeyValueStore(filePath: docPath, logOutput: true)
    }
    
    
}

//When
extension Tests {
    func whenISaveADateInTheDistantPast() {
        let date = NSDate.distantPast()
        
        key = "date"
        value = date
        
        store!.setValue(date, forKey: key!)
    }
    
    func whenISaveAnInt() {
        let number = NSNumber(integer: 10)
        
        key = "int"
        value = number
        
        store!.setValue(number, forKey: key!)
    }

    func whenIIntializeAStoreWithAnInvalidPath() {
        let docPath = documentsPathWithName("")
        store = KeyValueStore(filePath: docPath)
    }
    
    func whenIDeleteTheStore() {
        try! store!.delete()
    }
    
    func whenILoadAStoreSynchronously() {
        store!.load()
    }
    
    func whenILoadAStoreAsynchronously() {
        let expectation = expectationWithDescription("Load")
        store!.load() {
            error in
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(3, handler: nil)
    }
}


//Then
extension Tests {
    
   
    func thenTheStoreReturnsTheCorrectInt() {
        let sourceValue = (value as? NSNumber)!.integerValue
        let storeValue: NSNumber? = store!.valueForKey(key!)
        
        XCTAssertEqual(sourceValue, storeValue!.integerValue)
    }
    
    func thenTheStoreReturnsTheCorrectDate() {
        let sourceValue = (value as! NSDate)
        let storeValue: NSDate? = store!.valueForKey(key!)
        
        XCTAssertEqual(sourceValue, storeValue!)
    }
    
    func thenTheStoreReturnsANilValue() {
        let date: NSDate? = store!.valueForKey(key!)
        XCTAssertNil(date)
    }

    func thenSynchronousLoadReturnsFalse() {
        XCTAssertEqual(store!.load(), false)
    }
    
    func thenAnAsynchronousLoadReturnsFalse() {
        let expectation = expectationWithDescription("Load")
        store!.load() {
            error in
            XCTAssertNotNil(error)
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(3, handler: nil)
    }
    
    func thenTheBackingPlistExists() {
        let fileExists = NSFileManager.defaultManager().fileExistsAtPath(documentsPathWithName(DefaultFileName))
        XCTAssertTrue(fileExists)
    }
    
    func thenTheBackingPlistIsDeleted() {
        let fileExists = NSFileManager.defaultManager().fileExistsAtPath(documentsPathWithName(DefaultFileName))
        XCTAssertFalse(fileExists)
    }
    
    func thenTheStoreIsInAnUnloadedState() {
        XCTAssertFalse(store!.isLoaded)
    }
    
    func thenUnloadTheStore() {
        let expectation = expectationWithDescription("unload")
        store!.unload { 
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(3, handler: nil)
    }
}





//MARK: - Utilities -
extension XCTestCase {
    private func documentsPathWithName(name: String) -> String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
        return documentsPath.stringByAppendingString("/\(name)")
    }
    
    private func deleteFileWithName(name: String) {
        let path = documentsPathWithName(name)
        
        do {
            try NSFileManager.defaultManager().removeItemAtPath(path)
        }
        catch {}
    }
 
}



