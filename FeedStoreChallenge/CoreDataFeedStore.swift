//
//  CoreDataFeedStore.swift
//  FeedStoreChallenge
//
//  Created by Bogdan P on 31/01/2021.
//  Copyright © 2021 Essential Developer. All rights reserved.
//

import CoreData

public final class CoreDataFeedStore: FeedStore {
	
	private static let dataModelName = "FeedDataModel"
	
	private let persistentContainer: NSPersistentContainer
	private let managedContext: NSManagedObjectContext
	private let devNullURL = URL(fileURLWithPath: "/dev/null")
	
	public init() {
		
		let model = NSManagedObjectModel(name: CoreDataFeedStore.dataModelName, in: Bundle(for: CoreDataFeedStore.self))
		persistentContainer = NSPersistentContainer(dataModelName: CoreDataFeedStore.dataModelName, model: model, storeURL: devNullURL)
		managedContext = persistentContainer.newBackgroundContext()
	}
	
	public func deleteCachedFeed(completion: @escaping DeletionCompletion) {
		let context = self.managedContext
		
		context.perform {
			self.deleteCache()
			
			completion(nil)
		}
	}
	
	public func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping InsertionCompletion) {
		let context = self.managedContext
		
		context.perform {
			self.deleteCache()
			
			let _ = CoreDataFeedMapper.mapToStorableFeed(feed: feed, timestamp: timestamp, in: context)
			
			try! context.save()
			
			completion(nil)
		}
	}
	
	public func retrieve(completion: @escaping RetrievalCompletion) {
		let context = self.managedContext
		
		context.perform {
			guard let cachedFeed = try! context.fetch(CDFeed.fetchRequest()).first as? CDFeed else {
				completion(.empty)
				return
			}
			
			let (feed, timestamp) = CoreDataFeedMapper.mapToFeed(cachedFeed)
			
			completion(.found(feed: feed, timestamp: timestamp))
		}
	}
	
	private func deleteCache() {
		if let feedCache = try! managedContext.fetch(CDFeed.fetchRequest()).first as? CDFeed {
			managedContext.delete(feedCache)
			try! managedContext.save()
		}
	}
}

private extension NSPersistentContainer {
	convenience init(dataModelName: String, model: NSManagedObjectModel, storeURL: URL) {
		let description = NSPersistentStoreDescription(url: storeURL)
		self.init(name: dataModelName, managedObjectModel: model)
		persistentStoreDescriptions = [description]
		loadPersistentStores { _, _ in }
	}
}

private extension NSManagedObjectModel {
	convenience init(name: String, in bundle: Bundle) {
		let modelURL = bundle.url(forResource: name, withExtension: "momd")!
		self.init(contentsOf: modelURL)!
	}
}

private extension CDFeed {
	var fetchRequest: NSFetchRequest<CDFeed> {
		NSFetchRequest<CDFeed>(entityName: CDFeed.entity().name!)
	}
}
