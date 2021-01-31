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

extension LocalFeedImage {
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

class CoreDataFeedStore: FeedStore {
	
	typealias PersistentStore = (class: NSPersistentStore.Type, type: String)
	
	private let persistentContainer: NSPersistentContainer
	private let managedContext: NSManagedObjectContext
	private let dataModelName = "FeedDataModel"
	
	init(storeURL: URL, persistentStore: PersistentStore? = nil) {
		let model = NSManagedObjectModel(name: dataModelName, in: Bundle(for: CoreDataFeedStore.self))
		persistentContainer = NSPersistentContainer(dataModelName: dataModelName, model: model, storeURL: storeURL, persistentStore: persistentStore)
		managedContext = persistentContainer.newBackgroundContext()
	}
	
	func deleteCachedFeed(completion: @escaping DeletionCompletion) {
		let context = self.managedContext
		
		context.perform {
			self.deleteCache()
			
			completion(nil)
		}
	}
	
	func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping InsertionCompletion) {
		let context = self.managedContext
		
		context.perform {
			self.deleteCache()
			
			let _ = CDFeed(context: context).populate(from: feed, timestamp: timestamp, in: context)
			
			try! context.save()
			
			completion(nil)
		}
	}
	
	func retrieve(completion: @escaping RetrievalCompletion) {
		let context = self.managedContext
		
		context.perform {
			do {
				guard let cachedFeed = try context.fetch(CDFeed.fetchRequest()).first as? CDFeed else {
					completion(.empty)
					return
				}
				
				completion(
					.found(
						feed: cachedFeed.feed.compactMap({ LocalFeedImage(from: $0 as? CDFeedImage) }),
						timestamp: cachedFeed.timestamp
					)
				)
			} catch {
				completion(.failure(error))
			}
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
	convenience init(dataModelName: String, model: NSManagedObjectModel, storeURL: URL, persistentStore: CoreDataFeedStore.PersistentStore?) {
		
		let description = NSPersistentStoreDescription(url: storeURL)
		self.init(name: dataModelName, managedObjectModel: model)
		persistentStoreDescriptions = [description]
		
		try? persistentStoreCoordinator.add(persistentStore: persistentStore, with: storeURL)
		
		loadPersistentStores { _, _ in }
	}
}

private extension NSPersistentStoreCoordinator {
	func add(persistentStore: CoreDataFeedStore.PersistentStore?, with storeURL: URL) throws {
		guard let persistentStore = persistentStore else {
			return
		}
		
		NSPersistentStoreCoordinator.registerStoreClass(persistentStore.class, forStoreType: persistentStore.type)
		do {
			try addPersistentStore(ofType: persistentStore.type, configurationName: nil, at: storeURL, options: nil)
		} catch {
			throw error
		}
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
		let sut = makeSUT()

		assertThatRetrieveHasNoSideEffectsOnNonEmptyCache(on: sut)
	}
	
	func test_insert_deliversNoErrorOnEmptyCache() {
		let sut = makeSUT()

		assertThatInsertDeliversNoErrorOnEmptyCache(on: sut)
	}
	
	func test_insert_deliversNoErrorOnNonEmptyCache() {
		let sut = makeSUT()

		assertThatInsertDeliversNoErrorOnNonEmptyCache(on: sut)
	}
	
	func test_insert_overridesPreviouslyInsertedCacheValues() {
		let sut = makeSUT()

		assertThatInsertOverridesPreviouslyInsertedCacheValues(on: sut)
	}
	
	func test_delete_deliversNoErrorOnEmptyCache() {
		let sut = makeSUT()

		assertThatDeleteDeliversNoErrorOnEmptyCache(on: sut)
	}
	
	func test_delete_hasNoSideEffectsOnEmptyCache() {
		let sut = makeSUT()

		assertThatDeleteHasNoSideEffectsOnEmptyCache(on: sut)
	}
	
	func test_delete_deliversNoErrorOnNonEmptyCache() {
		let sut = makeSUT()

		assertThatDeleteDeliversNoErrorOnNonEmptyCache(on: sut)
	}
	
	func test_delete_emptiesPreviouslyInsertedCache() {
		let sut = makeSUT()

		assertThatDeleteEmptiesPreviouslyInsertedCache(on: sut)
	}
	
	func test_storeSideEffects_runSerially() {
		let sut = makeSUT()

		assertThatSideEffectsRunSerially(on: sut)
	}
	
	// - MARK: Helpers
	
	private func makeSUT(storeURL: URL? = nil, persistentStore: CoreDataFeedStore.PersistentStore? = nil) -> FeedStore {
		return CoreDataFeedStore(storeURL: storeURL ?? URL(fileURLWithPath: "/dev/null"), persistentStore: persistentStore)
	}
		
	private func cachesDirectory() -> URL {
		FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
	}
}

extension CoreDataFeedStoreTests: FailableRetrieveFeedStoreSpecs {

	func test_retrieve_deliversFailureOnRetrievalError() {
		MockPersistentStore.mockExecuteError = anyNSError()
		let sut = makeSUT(persistentStore: (MockPersistentStore.self, MockPersistentStore.storeType))

		assertThatRetrieveDeliversFailureOnRetrievalError(on: sut)
	}

	func test_retrieve_hasNoSideEffectsOnFailure() {
//		MockPersistentStore.mockExecuteError = anyNSError()
//		let sut = makeSUT(persistentStoreClass: MockPersistentStore.self, persistentStoreType: MockPersistentStore.storeType)
//
//		assertThatRetrieveHasNoSideEffectsOnFailure(on: sut)
	}
}

class MockPersistentStore: NSIncrementalStore {
	
	static let storeType: String = "Tests.MockPersistentStore"
	
	static var mockExecuteError: Error?
			
	override func loadMetadata() throws {
	}
	
	override class func metadataForPersistentStore(with url: URL) throws -> [String : Any] {
		return [NSStoreTypeKey: MockPersistentStore.storeType, NSStoreUUIDKey: ""]
	}
					
	override func execute(_ request: NSPersistentStoreRequest, with context: NSManagedObjectContext?) throws -> Any {
		if let error = MockPersistentStore.mockExecuteError {
			throw error
		}
		return [CDFeed]() as Any
	}
	
	override func newValuesForObject(with objectID: NSManagedObjectID, with context: NSManagedObjectContext) throws -> NSIncrementalStoreNode {
		if let error = MockPersistentStore.mockExecuteError {
			throw error
		}
		return NSIncrementalStoreNode()
	}
	
	override func obtainPermanentIDs(for array: [NSManagedObject]) throws -> [NSManagedObjectID] {
		if let error = MockPersistentStore.mockExecuteError {
			throw error
		}
		return []
	}
}

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
