//
//  XCTestCase+Helpers.swift
//  Tests
//
//  Created by Bogdan P on 31/01/2021.
//  Copyright © 2021 Essential Developer. All rights reserved.
//

import XCTest

extension XCTestCase {
	func testSpecificStoreURL() -> URL {
		XCTestCase.cachesDirectory().appendingPathComponent("\(type(of: self)).store")
	}
	
	private static func cachesDirectory() -> URL {
		FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
	}
}
