//
//  CoreDataFeedHelper.swift
//  FeedStoreChallenge
//
//  Created by Bogdan P on 31/01/2021.
//  Copyright © 2021 Essential Developer. All rights reserved.
//

import Foundation
import CoreData

internal final class CoreDataFeedHelper {
	internal static func insert(feed: [LocalFeedImage], timestamp: Date, in context: NSManagedObjectContext) {
		let result = CDFeed(context: context)
		result.feed = NSOrderedSet(array: feed.map { populate(storableFeedImage: CDFeedImage(context: context), with: $0) })
		result.timestamp = timestamp
	}
	
	internal static func mapToFeed(_ cacheFeed: CDFeed) -> (feed: [LocalFeedImage], timestamp: Date) {
		let feed = cacheFeed.feed.compactMap({   mapToFeedImage($0 as? CDFeedImage) })
		return (feed, cacheFeed.timestamp)
	}
	
	// MARK: - Helpers
	
	private static func populate(storableFeedImage: CDFeedImage, with feedImage: LocalFeedImage) -> CDFeedImage {
		storableFeedImage.id = feedImage.id
		storableFeedImage.imageDescription = feedImage.description
		storableFeedImage.imageLocation = feedImage.location
		storableFeedImage.url = feedImage.url
		
		return storableFeedImage
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
