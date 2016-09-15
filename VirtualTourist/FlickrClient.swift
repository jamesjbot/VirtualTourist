//
//  FlickrClient.swift
//  VirtualTourist
//
//  Created by James Jongsurasithiwat on 9/6/16.
//  Copyright © 2016 James Jongs. All rights reserved.
//

import Foundation
import UIKit
import MapKit

class FlickrClient {
    
    
    // MARK: Singleton
    
    private init(){}
    
    class func sharedInstance() -> FlickrClient {
        struct Singleton {
            static var sharedInstance = FlickrClient()
        }
        return Singleton.sharedInstance
    }
    
    
    func searchForPicturesByLatLon(location: MKAnnotation ,completionHandlerTopLevel: (success: Bool, error: NSError?) -> Void ) {
        let methodParameters = [
            Constants.FlickrParameterKeys.Method : Constants.FlickrParameterValues.SearchMethod,
            Constants.FlickrParameterKeys.APIKey : Constants.FlickrParameterValues.APIKey,
            Constants.FlickrParameterKeys.SafeSearch : Constants.FlickrParameterValues.UseSafeSearch,
            Constants.FlickrParameterKeys.Extras : Constants.FlickrParameterValues.MediumURL,
            Constants.FlickrParameterKeys.Format : Constants.FlickrParameterValues.ResponseFormat,
            Constants.FlickrParameterKeys.NoJSONCallback : Constants.FlickrParameterValues.DisableJSONCallback,
            Constants.FlickrParameterKeys.Lat : location.coordinate.latitude.description,
            Constants.FlickrParameterKeys.Lon : location.coordinate.longitude.description
        ]
        let searchURL = createURLFromParameters(methodParameters)
        let searchRequest = NSURLRequest(URL: searchURL)
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(searchRequest){
            (data, response, error) in
            self.guardChecks(data, response: response, error: error) {
                (requestSuccess, error) -> Void in
                if !requestSuccess { completionHandlerTopLevel(success: false, error: error)
                    return
                }
                self.parseResults(data) {
                    (dict, error) -> Void in
                    if error != nil {
                        completionHandlerTopLevel(success: false, error: error)
                        return
                    }
                    print(dict.dynamicType)
                    // Perform model updates
                    print("this may be an array")
                    let photosElement = dict!["photos"]
                    let photoArray = photosElement!["photo"] as! [[String:AnyObject]]
                    for photo in photoArray {
                        // TODO Construct photo and put into CoreData
                    }
                    // Notify caller of task completion
                    completionHandlerTopLevel(success: true, error: nil)
                    return
                }
            }
        }
        task.resume()
    }
    
    private func constructImageURL(photo: [String : AnyObject]) -> NSURL {
        let farm = photo["farm"]!
        let server = photo["server"]!
        let secret = photo["secret"]!
        let id = photo["id"]!
        return NSURL(string:"https://farm\(farm).staticflickr.com/\(server)/\(id)_\(secret)_\(Constants.Flickr.ImageSize).jpg")!
    }
    
    
    private func parseResults(data: NSData?, completionHandlerForParsingData: (parsedDictinary: NSDictionary?, error: NSError?) -> Void){
        var parsedResult: NSDictionary
        do {
            parsedResult = try NSJSONSerialization.JSONObjectWithData(data!, options: .AllowFragments) as! NSDictionary
            print("Here is the answer")
            print(parsedResult)
            completionHandlerForParsingData(parsedDictinary: parsedResult, error: nil)
            return
        } catch {
            let userInfo : [NSObject:AnyObject]? = [NSLocalizedDescriptionKey: "Error Parsing Information\n Please try again"]
            completionHandlerForParsingData(parsedDictinary: nil, error: NSError(domain: "FlickrClient", code: 1, userInfo: userInfo))
            return
        }
    }
    
    
    private func guardChecks(data: NSData?, response: NSURLResponse?, error: NSError?, completionHandlerForGuardChecks: (requestSuccess: Bool, error: NSError?)-> Void){
        
        func sendError(error: String) {
            let userInfo = [NSLocalizedDescriptionKey : error]
            completionHandlerForGuardChecks(requestSuccess: false, error: NSError(domain: "FlickrClient", code: 1, userInfo: userInfo))
        }
        
        // GUARD: For any error
        guard (error == nil) else { // Handle error...
            sendError((error!.localizedDescription))
            return
        }
        
        // GUARD: There was no error from server; however server did not take further action
        guard (response as! NSHTTPURLResponse).statusCode != 403 else {
            sendError("Server not responding to request")
            return
        }
        
        // GUARD: Did we get successful 2XX response?
        guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
            sendError("Your request returned a status code other than 2xx \((response as? NSHTTPURLResponse)!.statusCode)")
            return
        }
        
        // GUARD: Was there data returned?
        guard let _ = data else {
            sendError("No data was returned by the request!")
            return
        }
        
        completionHandlerForGuardChecks(requestSuccess: true, error: nil)
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
            static let ImageSize = "m"
            
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

