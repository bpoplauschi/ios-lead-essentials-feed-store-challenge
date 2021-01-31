//
//  Copyright © 2019 Essential Developer. All rights reserved.
//

import XCTest
import FeedStoreChallenge

import CoreData

class CDFeedImage: NSManagedObject {
	@NSManaged var id: UUID
	@NSManaged var imageDescription: String?
	@NSManaged var imageLocation: String?
	@NSManaged var url: URL
	@NSManaged var feed: CDFeed
}

extension CDFeedImage {
	func populate(from feedImage: LocalFeedImage) -> CDFeedImage {
		id = feedImage.id
		imageDescription = feedImage.description
		imageLocation = feedImage.location
		url = feedImage.url
		return self
	}
}

class CDFeed: NSManagedObject {
	@NSManaged var timestamp: Date
	@NSManaged var feed: NSOrderedSet
}

extension CDFeed {
	func populate(from feed: [LocalFeedImage], timestamp: Date, in context: NSManagedObjectContext) -> CDFeed {
		self.feed = NSOrderedSet(array: feed.map { CDFeedImage(context: context).populate(from: $0) })
		self.timestamp = timestamp
		return self
	}
}

extension CDFeed {
	var fetchRequest: NSFetchRequest<CDFeed> {
		NSFetchRequest<CDFeed>(entityName: CDFeed.entity().name!)
	}
}

class CoreDataFeedStore: FeedStore {
	
	private let persistentContainer: NSPersistentContainer
	private let managedContext: NSManagedObjectContext
	private let dataModelName = "FeedDataModel"
	private let devNullURL = URL(fileURLWithPath: "/dev/null")
	
	init() {
		let model = NSManagedObjectModel(name: dataModelName, in: Bundle(for: CoreDataFeedStore.self))
		persistentContainer = NSPersistentContainer(dataModelName: dataModelName, model: model, storeURL: devNullURL)
		managedContext = persistentContainer.viewContext
	}
	
	func deleteCachedFeed(completion: @escaping DeletionCompletion) {
	}
	
	func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping InsertionCompletion) {
		let context = self.managedContext
		
		context.perform {
			let _ = CDFeed(context: context).populate(from: feed, timestamp: timestamp, in: context)
			
			try! context.save()
			completion(nil)
		}
	}
	
	func retrieve(completion: @escaping RetrievalCompletion) {
		let context = self.managedContext
		
		context.perform {
			guard let cachedFeed = try! context.fetch(CDFeed.fetchRequest()).first as? CDFeed else {
				completion(.empty)
				return
			}
			
			completion(.found(feed: cachedFeed.feed.compactMap({ $0 as? CDFeedImage }).map {
				return LocalFeedImage(id: $0.id, description: $0.imageDescription, location: $0.imageLocation, url: $0.url)
			}, timestamp: cachedFeed.timestamp))
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

class CoreDataFeedStoreTests: XCTestCase, FeedStoreSpecs {
	
	func test_retrieve_deliversEmptyOnEmptyCache() {
		let sut = makeSUT()

		assertThatRetrieveDeliversEmptyOnEmptyCache(on: sut)
	}
	
	func test_retrieve_hasNoSideEffectsOnEmptyCache() {
		let sut = makeSUT()

		assertThatRetrieveHasNoSideEffectsOnEmptyCache(on: sut)
	}
	
	func test_retrieve_deliversFoundValuesOnNonEmptyCache() {
		let sut = makeSUT()

		assertThatRetrieveDeliversFoundValuesOnNonEmptyCache(on: sut)
	}
	
	func test_retrieve_hasNoSideEffectsOnNonEmptyCache() {
		//		let sut = makeSUT()
		//
		//		assertThatRetrieveHasNoSideEffectsOnNonEmptyCache(on: sut)
	}
	
	func test_insert_deliversNoErrorOnEmptyCache() {
		//		let sut = makeSUT()
		//
		//		assertThatInsertDeliversNoErrorOnEmptyCache(on: sut)
	}
	
	func test_insert_deliversNoErrorOnNonEmptyCache() {
		//		let sut = makeSUT()
		//
		//		assertThatInsertDeliversNoErrorOnNonEmptyCache(on: sut)
	}
	
	func test_insert_overridesPreviouslyInsertedCacheValues() {
		//		let sut = makeSUT()
		//
		//		assertThatInsertOverridesPreviouslyInsertedCacheValues(on: sut)
	}
	
	func test_delete_deliversNoErrorOnEmptyCache() {
		//		let sut = makeSUT()
		//
		//		assertThatDeleteDeliversNoErrorOnEmptyCache(on: sut)
	}
	
	func test_delete_hasNoSideEffectsOnEmptyCache() {
		//		let sut = makeSUT()
		//
		//		assertThatDeleteHasNoSideEffectsOnEmptyCache(on: sut)
	}
	
	func test_delete_deliversNoErrorOnNonEmptyCache() {
		//		let sut = makeSUT()
		//
		//		assertThatDeleteDeliversNoErrorOnNonEmptyCache(on: sut)
	}
	
	func test_delete_emptiesPreviouslyInsertedCache() {
		//		let sut = makeSUT()
		//
		//		assertThatDeleteEmptiesPreviouslyInsertedCache(on: sut)
	}
	
	func test_storeSideEffects_runSerially() {
		//		let sut = makeSUT()
		//
		//		assertThatSideEffectsRunSerially(on: sut)
	}
	
	// - MARK: Helpers
	
	private func makeSUT() -> FeedStore {
		return CoreDataFeedStore()
	}
	
}

//  ***********************
//
//  Uncomment the following tests if your implementation has failable operations.
//
//  Otherwise, delete the commented out code!
//
//  ***********************

//extension CoreDataFeedStoreTests: FailableRetrieveFeedStoreSpecs {
//
//	func test_retrieve_deliversFailureOnRetrievalError() {
////		let sut = makeSUT()
////
////		assertThatRetrieveDeliversFailureOnRetrievalError(on: sut)
//	}
//
//	func test_retrieve_hasNoSideEffectsOnFailure() {
////		let sut = makeSUT()
////
////		assertThatRetrieveHasNoSideEffectsOnFailure(on: sut)
//	}
//
//}

//extension FeedStoreChallengeTests: FailableInsertFeedStoreSpecs {
//
//	func test_insert_deliversErrorOnInsertionError() {
////		let sut = makeSUT()
////
////		assertThatInsertDeliversErrorOnInsertionError(on: sut)
//	}
//
//	func test_insert_hasNoSideEffectsOnInsertionError() {
////		let sut = makeSUT()
////
////		assertThatInsertHasNoSideEffectsOnInsertionError(on: sut)
//	}
//
//}

//extension FeedStoreChallengeTests: FailableDeleteFeedStoreSpecs {
//
//	func test_delete_deliversErrorOnDeletionError() {
////		let sut = makeSUT()
////
////		assertThatDeleteDeliversErrorOnDeletionError(on: sut)
//	}
//
//	func test_delete_hasNoSideEffectsOnDeletionError() {
////		let sut = makeSUT()
////
////		assertThatDeleteHasNoSideEffectsOnDeletionError(on: sut)
//	}
//
//}
