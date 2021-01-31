//
//  CoreDataFeedMapper.swift
//  FeedStoreChallenge
//
//  Created by Bogdan P on 31/01/2021.
//  Copyright © 2021 Essential Developer. All rights reserved.
//

import Foundation
import CoreData

internal final class CoreDataFeedMapper {
	internal static func mapToStorableFeed(feed: [LocalFeedImage], timestamp: Date, in context: NSManagedObjectContext) -> CDFeed {
		let result = CDFeed(context: context)
		result.feed = NSOrderedSet(array: feed.map { mapToStorableFeedImage($0, in: context) })
		result.timestamp = timestamp
		
		return result
	}
	
	internal static func mapToFeed(_ cacheFeed: CDFeed) -> (feed: [LocalFeedImage], timestamp: Date) {
		let feed = cacheFeed.feed.compactMap({ mapToFeedImage($0 as? CDFeedImage) })
		return (feed, cacheFeed.timestamp)
	}
	
	// MARK: - Helpers
	
	private static func mapToStorableFeedImage(_ feedImage: LocalFeedImage, in context: NSManagedObjectContext) -> CDFeedImage {
		let result = CDFeedImage(context: context)
		result.id = feedImage.id
		result.imageDescription = feedImage.description
		result.imageLocation = feedImage.location
		result.url = feedImage.url
		
		return result
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
