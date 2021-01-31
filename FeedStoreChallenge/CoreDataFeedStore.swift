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
			
			let _ = CDFeed(context: context).populate(from: feed, timestamp: timestamp, in: context)
			
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
			
			completion(
				.found(
					feed: cachedFeed.feed.compactMap({ LocalFeedImage(from: $0 as? CDFeedImage) }),
					timestamp: cachedFeed.timestamp
				)
			)
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

private extension CDFeed {
	func populate(from feed: [LocalFeedImage], timestamp: Date, in context: NSManagedObjectContext) -> CDFeed {
		self.feed = NSOrderedSet(array: feed.map { CDFeedImage(context: context).populate(from: $0) })
		self.timestamp = timestamp
		return self
	}
}

private extension CDFeedImage {
	func populate(from feedImage: LocalFeedImage) -> CDFeedImage {
		id = feedImage.id
		imageDescription = feedImage.description
		imageLocation = feedImage.location
		url = feedImage.url
		return self
	}
}

private extension LocalFeedImage {
	init?(from cacheFeedImage: CDFeedImage?) {
		guard let cacheFeedImage = cacheFeedImage else { return nil }
		
		self.init(
			id: cacheFeedImage.id,
			description: cacheFeedImage.imageDescription,
			location: cacheFeedImage.imageLocation,
			url: cacheFeedImage.url
		)
	}
}
