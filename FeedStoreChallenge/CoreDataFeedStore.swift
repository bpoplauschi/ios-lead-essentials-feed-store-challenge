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

private class CoreDataFeedMapper {
	static func mapToStorableFeed(feed: [LocalFeedImage], timestamp: Date, in context: NSManagedObjectContext) -> CDFeed {
		let result = CDFeed(context: context)
		result.feed = NSOrderedSet(array: feed.map { mapToStorableFeedImage($0, in: context) })
		result.timestamp = timestamp
		
		return result
	}
	
	private static func mapToStorableFeedImage(_ feedImage: LocalFeedImage, in context: NSManagedObjectContext) -> CDFeedImage {
		let result = CDFeedImage(context: context)
		result.id = feedImage.id
		result.imageDescription = feedImage.description
		result.imageLocation = feedImage.location
		result.url = feedImage.url
		
		return result
	}
	
	static func mapToFeed(_ cacheFeed: CDFeed) -> (feed: [LocalFeedImage], timestamp: Date) {
		let feed = cacheFeed.feed.compactMap({ mapToFeedImage($0 as? CDFeedImage) })
		return (feed, cacheFeed.timestamp)
	}
	
	private static func mapToFeedImage(_ cacheFeedImage: CDFeedImage?) -> LocalFeedImage? {
		guard let cacheFeedImage = cacheFeedImage else { return nil }
		
		return LocalFeedImage(
			id: cacheFeedImage.id,
			description: cacheFeedImage.imageDescription,
			location: cacheFeedImage.imageLocation,
			url: cacheFeedImage.url
		)
	}
}
