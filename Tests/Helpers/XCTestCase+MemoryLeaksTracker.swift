//
//  XCTestCase+MemoryLeaksTracker.swift
//  Tests
//
//  Created by Bogdan P on 31/01/2021.
//  Copyright © 2021 Essential Developer. All rights reserved.
//

import XCTest

extension XCTestCase {
	func trackForMemoryLeaks(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
		addTeardownBlock { [weak instance] in
			XCTAssertNil(instance, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
		}
	}
}
