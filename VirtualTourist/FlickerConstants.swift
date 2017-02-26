//
//  FlickerConstants.swift
//  VirtualTourist
//
//  Created by James Jongsurasithiwat on 12/20/16.
//  Copyright © 2016 James Jongs. All rights reserved.
//

import Foundation

extension FlickrClient {
    struct Constants {
        // MARK: Flickr
        struct Flickr {
            static let APIScheme = "https"
            static let APIHost = "api.flickr.com"
            static let APIPath = "/services/rest"
            static let ImageSize = "m"
            static let MaximumShownImages = 21
            
            static let SearchBBoxHalfWidth = 1.0
            static let SearchBBoxHalfHeight = 1.0
            static let SearchLatRange = (-90.0, 90.0)
            static let SearchLonRange = (-180.0, 180.0)
        }
        
        // MARK: Flickr Parameter Keys
        struct FlickrParameterKeys {
            static let Method = "method"
            static let APIKey = "api_key"
            static let Extras = "extras"
            static let SafeSearch = "safe_search"
            static let Format = "format"
            static let NoJSONCallback = "nojsoncallback"
            static let Lat = "lat"
            static let Lon = "lon"
            static let BoundingBox = "bbox"
        }
        
        // MARK: Flickr Parameter Values
        struct FlickrParameterValues {
            static let SearchMethod = "flickr.photos.search"
            static let APIKey = "cf3e089c7821258a56d0dfc84b14a4a2"
            static let MediumURL = "medium_url"
            static let UseSafeSearch = "1"
            static let ResponseFormat = "json"
            static let DisableJSONCallback = "1"
        }
        
        // MARK: Flickr Response Keys
        struct FlickrResponseKeys {
            static let Status = "stat"
            static let Photos = "photos"
            static let Photo = "photo"
            static let MediumURL = "url_m"
            static let Total = "total"
        }
        
        // MARK: Flickr Response Values
        struct FlickrRespnseValues {
            static let OKStatus = "ok"
        }
        
        // MARK: Flickr URL Construction
        struct FlickrURLConstructValue {
            static let Farm = "farm"
            static let Server = "server"
            static let Secret = "secret"
            static let Id = "id"
        }
    }
}

