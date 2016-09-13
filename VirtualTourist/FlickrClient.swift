//
//  FlickrClient.swift
//  VirtualTourist
//
//  Created by James Jongsurasithiwat on 9/6/16.
//  Copyright © 2016 James Jongs. All rights reserved.
//

import Foundation
import UIKit

class FlickrClient {
    
    
    // MARK: Singleton
    
    private init(){}
    
    class func sharedInstance() -> FlickrClient {
        struct Singleton {
            static var sharedInstance = FlickrClient()
        }
        return Singleton.sharedInstance
    }
    
    
    private func searchForPicturesByLatLon() {
        let methodParameters = [
            Constants.FlickrParameterKeys.Method : Constants.FlickrParameterValues.SearchMethod,
            Constants.FlickrParameterKeys.APIKey : Constants.FlickrParameterValues.APIKey,
            Constants.FlickrParameterKeys.SafeSearch : Constants.FlickrParameterValues.UseSafeSearch,
            Constants.FlickrParameterKeys.Extras : Constants.FlickrParameterValues.MediumURL,
            
        ]
    }
    
    private func createURLFromParameters(paramenters: [String:AnyObject]) -> NSURL {
        let components = NSURLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [NSURLQueryItem]()
        
        for (key, value) in paramenters {
            let queryItem = NSURLQueryItem(name: key, value: "\(value)")
            components.queryItems?.append(queryItem)
        }
        return components.URL!
    }
    
    func asyncLoadImage( completion: (photo: UIImage, error: NSError?) -> Void) {
        
    }
    
    
}


extension FlickrClient {
    struct Constants {
        // MARK: Flickr
        struct Flickr {
            static let APIScheme = "https"
            static let APIHost = "api.flickr.com"
            static let APIPath = "/services/rest"
            
        }
        
        // MARK: Flickr Parameter Keys
        struct FlickrParameterKeys {
            static let Method = "method"
            static let APIKey = "api_key"
            static let Extras = "extras"
            static let SafeSearch = "safe_search"
            static let Format = "format"
            static let NoJSONCallback = "nojsoncallback"
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
            static let Photo = "photos"
            static let MediumURL = "url_m"
            static let Total = "total"
        }
        
        // MARK: Flickr Response Values
        struct FlickrRespnseValues {
            static let OKStatus = "ok"
        }
    }
}

