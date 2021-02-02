//
//  CoreDataFeedStore.swift
//  FeedStoreChallenge
//
//  Created by Bogdan P on 31/01/2021.
//  Copyright © 2021 Essential Developer. All rights reserved.
//

import CoreData

public final class CoreDataFeedStore: FeedStore {
	
	// MARK: - Types
	
	public enum CoreDataFeedStoreError: Error {
		case cannotCreateManagedObjectModel(name: String, bundle: Bundle)
	}
	
	// MARK: - Properties
	
	private let persistentContainer: NSPersistentContainer
	private let managedContext: NSManagedObjectContext
	
	// MARK: - Init
	
	public init(storeURL: URL) throws {
		let bundle = Bundle(for: CoreDataFeedStore.self)
		persistentContainer = try NSPersistentContainer.load(dataModelName: "FeedDataModel", storeURL: storeURL, in: bundle)
		managedContext = persistentContainer.newBackgroundContext()
	}
	
	// MARK: - FeedStore
	
	public func deleteCachedFeed(completion: @escaping DeletionCompletion) {
		let context = self.managedContext
		
		context.perform {
			do {
				try self.deleteCache()
				completion(nil)
			} catch {
				completion(error)
			}
		}
	}
	
	public func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping InsertionCompletion) {
		let context = self.managedContext
		
		context.perform {
			do {
				try self.deleteCache()
				CoreDataFeedHelper.insert(feed: feed, timestamp: timestamp, in: context)
				try context.save()
				completion(nil)
			} catch {
				completion(error)
			}
		}
	}
	
	public func retrieve(completion: @escaping RetrievalCompletion) {
		let context = self.managedContext
		
		context.perform {
			do {
				guard let cachedFeed = try context.fetch(CDFeed.fetchRequest()).first as? CDFeed else {
					completion(.empty)
					return
				}
				let (feed, timestamp) = CoreDataFeedHelper.mapToFeed(cachedFeed)
				completion(.found(feed: feed, timestamp: timestamp))
			} catch {
				completion(.failure(error))
			}
		}
	}
	
	// MARK: - Helpers
	
	private func deleteCache() throws {
		if let feedCache = try managedContext.fetch(CDFeed.fetchRequest()).first as? CDFeed {
			managedContext.delete(feedCache)
			try managedContext.save()
		}
	}
}

private extension NSPersistentContainer {
	
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

private extension CDFeed {
	var fetchRequest: NSFetchRequest<CDFeed> {
		NSFetchRequest<CDFeed>(entityName: CDFeed.entity().name!)
	}
}
