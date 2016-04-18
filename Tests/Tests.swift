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
        givenALoadedStore()
        whenISaveADateInTheDistantPast()
        thenTheStoreReturnsADistantPastDate()
    }
    
    func testSavingAnNSDatewithoutLoadingStoreReturnsNil() {
        givenAStore()
        whenISaveADateInTheDistantPast()
        thenTheStoreShouldReturnANilDate()
    }
    
    /*
    func testDateSave() {
        givenAnInitializedStore()
        whenISaveADistantPastDateForKeyDate()
        thenTheStoreReturnsADistantPastDate()
    }
    
    func testNilingDate() {
        givenAnInitializedStore()
        whenISaveADistantPastDateForKeyDate()
        thenTheStoreReturnsADistantPastDate()
    }
    
    func testDataIsPreservedBetweenStoreInstances() {
        givenAnInitializedStore()
        whenISaveADistantPastDateForKeyDate()
        thenTheStoreReturnsADistantPastDate()
        
        whenINilTheDateStoredInDateKey()
        thenTheStoreShouldReturnANilDate()
    }
    */
}


//Given
extension Tests {
    
    /*
    func givenAnInitializedStore() {
        let directoryURL = createContainerFromName("TestStore")
        store = try! KeyValueStore(directoryURL: directoryURL, plistName: "TestFile", logOutput: true)
    }
    
    func givenTheBackingFileHasBeenLoaded() {
        let expectation = expectationWithDescription("Load")
        store!.load() {
            error in
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(3, handler: nil)
    }
    */
    
    
    func givenAStore() {
        let docPath = documentsPathWithName(DefaultFileName)
        store = KeyValueStore(filePath: docPath, logOutput: true)
    }
    
    func givenALoadedStore() {
        store?.load()
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
    

    func whenIIntializeAStoreWithAnInvalidPath() {
        let docPath = documentsPathWithName("")
        store = KeyValueStore(filePath: docPath)
    }
}


//Then
extension Tests {
    
   
    func thenTheStoreReturnsADistantPastDate() {
        XCTAssertEqual(NSDate.distantPast(), store!.valueForKey(key!))
    }
    
    func thenTheStoreShouldReturnANilDate() {
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



