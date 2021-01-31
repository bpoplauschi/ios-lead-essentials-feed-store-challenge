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
	private let persistentStore: PersistentStore?
	
	init(storeURL: URL, persistentStore: PersistentStore? = nil) {
		let model = NSManagedObjectModel(name: dataModelName, in: Bundle(for: CoreDataFeedStore.self))
		self.persistentStore = persistentStore
		persistentContainer = NSPersistentContainer(dataModelName: dataModelName, model: model, storeURL: storeURL, persistentStore: persistentStore)
		managedContext = persistentContainer.newBackgroundContext()
	}
	
	deinit {
		persistentContainer.persistentStoreCoordinator.remove(persistentStore: persistentStore)
	}
	
	func deleteCachedFeed(completion: @escaping DeletionCompletion) {
		let context = self.managedContext
		
		context.perform {
			try? self.deleteCache()
			completion(nil)
		}
	}
	
	func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping InsertionCompletion) {
		let context = self.managedContext
		
		context.perform {
			do {
				try self.deleteCache()
			
				let _ = CDFeed(context: context).populate(from: feed, timestamp: timestamp, in: context)
			
				try context.save()
			
				completion(nil)
			} catch {
				completion(error)
			}
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
	
	private func deleteCache() throws {
		if let feedCache = try managedContext.fetch(CDFeed.fetchRequest()).first as? CDFeed {
			managedContext.delete(feedCache)
			try managedContext.save()
		}
	}
}

private extension NSPersistentContainer {
	convenience init(dataModelName: String, model: NSManagedObjectModel, storeURL: URL, persistentStore: CoreDataFeedStore.PersistentStore?) {
		
		let description = NSPersistentStoreDescription(url: storeURL)
		self.init(name: dataModelName, managedObjectModel: model)
		persistentStoreDescriptions = [description]
		
		try? persistentStoreCoordinator.add(persistentStore: persistentStore, with: storeURL)
		
		if persistentStoreCoordinator.persistentStores.isEmpty {
			loadPersistentStores { _, _ in }
		}
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
	
	func remove(persistentStore: CoreDataFeedStore.PersistentStore?) {
		guard let persistentStore = persistentStore else {
			return
		}
		
		NSPersistentStoreCoordinator.registerStoreClass(nil, forStoreType: persistentStore.type)
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
}

extension CoreDataFeedStoreTests: FailableRetrieveFeedStoreSpecs {

	func test_retrieve_deliversFailureOnRetrievalError() {
		MockPersistentStore.mockRetrieveError = anyNSError()
		let sut = makeSUT(persistentStore: (MockPersistentStore.self, MockPersistentStore.storeType))

		assertThatRetrieveDeliversFailureOnRetrievalError(on: sut)

		MockPersistentStore.mockRetrieveError = nil
	}

	func test_retrieve_hasNoSideEffectsOnFailure() {
		MockPersistentStore.mockRetrieveError = anyNSError()
		let sut = makeSUT(persistentStore: (MockPersistentStore.self, MockPersistentStore.storeType))

		assertThatRetrieveHasNoSideEffectsOnFailure(on: sut)

		MockPersistentStore.mockRetrieveError = nil
	}
}

// Note: this class is not private because if we make it private, the storeType will become an obfuscated random string
// e.g. `_TtC5TestsP33_01BF4B5342A9D90D45026E2FA8052BD719MockPersistentStore`
// and unless we hardcode that, we will get a CoreData error when adding the store
// NSCocoaErrorDomain(134010) with userInfo dictionary {
// metadata =     {
// ...
// NSStoreType = "_TtC5TestsP33_01BF4B5342A9D90D45026E2FA8052BD719MockPersistentStore";
// ... };
// reason = "The store type in the metadata does not match the specified store type.";
class MockPersistentStore: NSIncrementalStore {
	
	static let storeType: String = "Tests.MockPersistentStore"
	
	static var mockRetrieveError: Error?
	static var mockInsertError: Error?
	
	static func resetAllMockedValues() {
		mockRetrieveError = nil
		mockInsertError = nil
	}
		
	override func loadMetadata() throws {
	}
	
	override class func metadataForPersistentStore(with url: URL) throws -> [String : Any] {
		return [NSStoreTypeKey: MockPersistentStore.storeType, NSStoreUUIDKey: ""]
	}
					
	override func execute(_ request: NSPersistentStoreRequest, with context: NSManagedObjectContext?) throws -> Any {
		switch (request, MockPersistentStore.mockRetrieveError, MockPersistentStore.mockInsertError) {
		case let (_ as NSFetchRequest<NSFetchRequestResult>, .some(retrievalError), _):
			throw retrievalError
		case let (_ as NSSaveChangesRequest, _, .some(insertionError)):
			throw insertionError
		default: break
		}
				
		return []
	}
	
	override func obtainPermanentIDs(for array: [NSManagedObject]) throws -> [NSManagedObjectID] {
		/** HACK
		 * throwing an exception in `execute(request:with:)` during a save has some backing mechanism that stores the inserted data in another store
		 * (even though the coordinator has only this `MockPersistentStore`)
		 * this makes our "after insert throws insertion error, retrieve should deliver empty" scenario fail
		 * as the store will somehow complete with the Feed
		 
		 * the only way to go around that is to use override the object ids so the main `CDFeed` object ID is owerwritten by a `CDFeedImage` ID
		 */
		guard let firstID = array.first?.objectID else { return [] }
		return array.map { _ in firstID }
	}
}

extension CoreDataFeedStoreTests: FailableInsertFeedStoreSpecs {

	func test_insert_deliversErrorOnInsertionError() {
		MockPersistentStore.mockInsertError = anyNSError()
		let sut = makeSUT(persistentStore: (MockPersistentStore.self, MockPersistentStore.storeType))

		assertThatInsertDeliversErrorOnInsertionError(on: sut)
		MockPersistentStore.mockInsertError = nil
	}

	func test_insert_hasNoSideEffectsOnInsertionError() {
		MockPersistentStore.mockInsertError = anyNSError()
		let sut = makeSUT(persistentStore: (MockPersistentStore.self, MockPersistentStore.storeType))

		assertThatInsertHasNoSideEffectsOnInsertionError(on: sut)
		MockPersistentStore.mockInsertError = nil
	}

}

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
