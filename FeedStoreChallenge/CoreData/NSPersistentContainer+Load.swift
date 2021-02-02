//
//  NSPersistentContainer+Load.swift
//  FeedStoreChallenge
//
//  Created by Bogdan Poplauschi on 02/02/2021.
//  Copyright © 2021 Essential Developer. All rights reserved.
//

import CoreData

internal extension NSPersistentContainer {
	
	enum LoadingError: Error {
		case modelNotFound
		case cannotLoadPersistentStores(Error)
	}
	
	static func load(dataModelName: String, storeURL: URL, in bundle: Bundle) throws -> NSPersistentContainer {
		guard let model = NSManagedObjectModel(name: dataModelName, in: bundle) else {
			throw LoadingError.modelNotFound
		}
		
		let container = NSPersistentContainer(name: dataModelName, managedObjectModel: model)
		let description = NSPersistentStoreDescription(url: storeURL)
		container.persistentStoreDescriptions = [description]
		var loadError: Error?
		container.loadPersistentStores { loadError = $1 }
		try loadError.map { throw LoadingError.cannotLoadPersistentStores($0) }
		
		return container
	}
}

private extension NSManagedObjectModel {
	convenience init?(name: String, in bundle: Bundle) {
		guard let modelURL = bundle.url(forResource: name, withExtension: "momd") else {
			return nil
		}
		self.init(contentsOf: modelURL)
	}
}
