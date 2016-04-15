//
//  Tests.swift
//  Tests
//
//  Created by Matthew Yannascoli on 4/11/16.
//  Copyright © 2016 Matthew Yannascoli. All rights reserved.
//

import XCTest
@testable import KeyValueStore


class Tests: XCTestCase {
    var store: KeyValueStore?
}

//Tests
extension Tests {
    
    override func tearDown() {
        super.tearDown()
        deleteContainerWithName("TestStore")
    }

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
    
}


//Given
extension Tests {
    
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
}

//When
extension Tests {
    
    func whenISaveADistantPastDateForKeyDate() {
        let date = NSDate.distantPast()
        store!.setDate(date, forKey: "date")
    }
    
    func whenINilTheDateStoredInDateKey() {
        store!.setDate(nil, forKey: "date")
    }
    
}


//Then
extension Tests {
    
    func thenTheStoreReturnsADistantPastDate() {
        XCTAssertEqual(NSDate.distantPast(), store!.dateForKey("date"))
    }
    
    func thenTheStoreShouldReturnANilDate() {
        XCTAssertEqual(nil, store!.dateForKey("date"))
    }
    
}





//MARK: - Utilities -
extension XCTestCase {
    private func urlWithName(name: String) -> NSURL {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
        let fullPath = documentsPath.stringByAppendingString("/\(name)")
        
        return NSURL(fileURLWithPath: fullPath, isDirectory: false)
    }
    
    private func createContainerFromName(name: String) -> NSURL {
        let url = urlWithName(name)
        
        //Create the container if necessary
        var error:NSError?
        if !url.checkResourceIsReachableAndReturnError(&error) {
            try! NSFileManager.defaultManager().createDirectoryAtURL(
                url, withIntermediateDirectories: true, attributes: nil)
        }
        
        print("Container URL: \(url.absoluteString)")
        return url
    }
    
    private func deleteContainerWithName(name: String) {
        let url = urlWithName(name)
        try! NSFileManager.defaultManager().removeItemAtURL(url)
    }
}