//
//  InMemoryFeedStore.swift
//  FeedStoreChallenge
//
//  Created by Bogdan Poplauschi on 31/01/2021.
//  Copyright © 2021 Essential Developer. All rights reserved.
//

import Foundation

public final class InMemoryFeedStore: FeedStore {
	
	// MARK: - Types
	
	private struct Cache {
		let feed: [LocalFeedImage]
		let timestamp: Date
	}
	
	// MARK: - Properties
	
	private var cache: Cache?
	
	// MARK: - Init
	
	public init() {}
	
	// MARK: - FeedStore
	
	public func deleteCachedFeed(completion: @escaping DeletionCompletion) {
		cache = nil
		
		completion(nil)
	}
	
	public func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping InsertionCompletion) {
		cache = Cache(feed: feed, timestamp: timestamp)
		
		completion(nil)
	}
	
	public func retrieve(completion: @escaping RetrievalCompletion) {
		guard let cache = cache else {
			completion(.empty)
			return
		}
		
		completion(.found(feed: cache.feed, timestamp: cache.timestamp))
	}
}
