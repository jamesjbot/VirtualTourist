//
//  FlickrClient.swift
//  VirtualTourist
//
//  Created by James Jongsurasithiwat on 9/6/16.
//  Copyright © 2016 James Jongs. All rights reserved.
//

import Foundation

class FlickrClient {
    
    
    // MARK: Singleton
    
    private init(){}
    
    class func sharedInstance() -> FlickrClient {
        struct Singleton {
            static var sharedInstance = FlickrClient()
        }
        return Singleton.sharedInstance
    }
    
}


extension FlickrClient {
    struct Constants {
        struct Flickr {
            static let APIScheme = "https"
            static let APIHost = "api.flickr.com"
            static let APIPath = "/services/rest"
            static let apiKey = "cf3e089c7821258a56d0dfc84b14a4a2"
        }
    }
}

