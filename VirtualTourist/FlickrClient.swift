//
//  FlickrClient.swift
//  VirtualTourist
//
//  Created by James Jongsurasithiwat on 9/6/16.
//  Copyright © 2016 James Jongs. All rights reserved.
//

//import Foundation
import UIKit
import MapKit
import CoreData
import GameplayKit

class FlickrClient {
    
    // MARK: Variables
    
    internal var photoSearchResultsArray : [[String:AnyObject]] = [[String:AnyObject]]()
    
    private var newCollection:[NSURL] = [NSURL]()
    
    private var pinLocation: Pin?
    
    private let coreData = (UIApplication.sharedApplication().delegate as! AppDelegate).stack
    
    // MARK: Singleton Function
    
    private init(){}
    class func sharedInstance() -> FlickrClient {
        struct Singleton {
            static var sharedInstance = FlickrClient()
        }
        return Singleton.sharedInstance
    }
    
    // MARK: Functions
    
    // Create a boundingBox for flickr search parameters
    private func boundingboxConstruct() -> String {
        if let latitude : Double = Double((pinLocation?.latitude!)!),
            let longitude : Double = Double((pinLocation?.longitude)!) {
            let minimumLon = max(longitude - Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.0)
            let minimumLat = max(latitude - Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.0)
            let maximumLon = min(longitude + Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.1)
            let maximumLat = min(latitude + Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.1)
            return "\(minimumLon),\(minimumLat),\(maximumLon),\(maximumLat)"
        } else {
            return "0,0,0,0"
        }
    }
    
    // Use Flickr's RESTful api to get search results and store locally
    internal func searchForPicturesByLatLonByPinByAsync(inputLocation: Pin ,
                                        completionHandlerTopLevel: ((success: Bool, results: NSData?, error: NSError?) -> Void )?
        ){
        pinLocation = inputLocation
        let methodParameters = [
            Constants.FlickrParameterKeys.Method : Constants.FlickrParameterValues.SearchMethod,
            Constants.FlickrParameterKeys.APIKey : Constants.FlickrParameterValues.APIKey,
            Constants.FlickrParameterKeys.BoundingBox : boundingboxConstruct(),
            Constants.FlickrParameterKeys.SafeSearch : Constants.FlickrParameterValues.UseSafeSearch,
            Constants.FlickrParameterKeys.Extras : Constants.FlickrParameterValues.MediumURL,
            Constants.FlickrParameterKeys.Format : Constants.FlickrParameterValues.ResponseFormat,
            Constants.FlickrParameterKeys.NoJSONCallback : Constants.FlickrParameterValues.DisableJSONCallback,
            Constants.FlickrParameterKeys.Lat : pinLocation!.latitude!,
            Constants.FlickrParameterKeys.Lon : pinLocation!.longitude!
        ]
        let searchURL = createURLFromParameters(methodParameters)
        let searchRequest = NSURLRequest(URL: searchURL)
        let session = NSURLSession.sharedSession()
        session.configuration.timeoutIntervalForRequest = 10
        let task = session.dataTaskWithRequest(searchRequest){
            (data, response, error) in
            self.guardChecks(data, response: response, error: error) {
                (requestSuccess, error) -> Void in
                if !requestSuccess && completionHandlerTopLevel != nil
                {
                    if let completionHandlerTopLevel = completionHandlerTopLevel {
                        let userInfo : [NSObject:AnyObject]? = [NSLocalizedDescriptionKey: "Error Searching Flickr\n\((error?.localizedDescription)!)\nPlease backout to main map and try again"]
                        completionHandlerTopLevel(success: false, results: nil, error: NSError(domain: "FlickrClient", code: 2, userInfo: userInfo))
                    }
                    return
                }
                self.parseResults(data) {
                    (dict, error) -> Void in
                    if error != nil {
                        if let completionHandlerTopLevel = completionHandlerTopLevel {
                            let userInfo : [NSObject:AnyObject]? = [NSLocalizedDescriptionKey: "Error Searching Flickr\nPlease backout to main map and try again"]
                            completionHandlerTopLevel(success: false, results: nil, error: NSError(domain: "FlickrClient", code: 2, userInfo: userInfo))
                        }
                        return
                    }
                    // Perform model updates
                    let photosElement = dict![Constants.FlickrResponseKeys.Photos]
                    self.photoSearchResultsArray = photosElement![Constants.FlickrResponseKeys.Photo] as! [[String:AnyObject]]
                    if let completionHandlerTopLevel = completionHandlerTopLevel {
                        completionHandlerTopLevel(success: true, results: photosElement![Constants.FlickrResponseKeys.Photo] as? NSData, error: nil)
                    }
                }
            }
        }
        task.resume()
    }
    
    // From the search results, load only up the maximum allowed photos
    private func seperateNewCollectionFromResults(){
        // Load local visible records
        let shownImages = (photoSearchResultsArray.count < Constants.Flickr.MaximumShownImages ?
            photoSearchResultsArray.count : Constants.Flickr.MaximumShownImages)
        let acceptableRange = photoSearchResultsArray.count - shownImages
        let randomBaseIndex = GKRandomDistribution(lowestValue: 0,highestValue: acceptableRange).nextInt()
        newCollection.removeAll()
        var index = 0
        for x in randomBaseIndex ..< randomBaseIndex+shownImages {
            index += 1
            newCollection.append(constructImageURL(photoSearchResultsArray[x]))
        }
    }
    
    // Two performwaitandblocks in background context
    internal func populateCoreDataWithSearchResultsInFlickrClient(completionHandler: ((success: Bool, error: NSError?) -> Void)){
        
        seperateNewCollectionFromResults()
        
        // In Coredata, remove the photos registered to this pin
        let bfrc = getBackgroundContextFetchedResultsController()
        guard bfrc != nil else {
            let userInfo : [NSObject:AnyObject]? = [NSLocalizedDescriptionKey: "Error Saving Photos\nPlease try again"]
            completionHandler(success: false, error: NSError(domain: "FlickrClient", code: 5, userInfo: userInfo))
            return
        }
        
        //Remove photos
        coreData!.backgroundContext.performBlockAndWait(){
            do {
                try bfrc!.performFetch()
            } catch {
                let userInfo : [NSObject:AnyObject]? = [NSLocalizedDescriptionKey: "Error Removing Photos\nPlease try again"]
                completionHandler(success: false, error: NSError(domain: "FlickrClient", code: 3, userInfo: userInfo))
                return
            }
            for i in bfrc!.fetchedObjects! {
                self.coreData!.backgroundContext.deleteObject(i as! NSManagedObject)
            }
        }
        
        // Add new photos to core data, and save the related pin
        coreData!.backgroundContext.performBlockAndWait()
            { () -> Void in
                for url in self.newCollection {
                    // Load the new photo for saving
                    let photo2BSaved = Photo(image: nil, url: url,  context: self.coreData!.backgroundContext)
                    // Convert main context pin location to the background context, and register thie photo to our pin
                    photo2BSaved.pin = self.coreData!.backgroundContext.objectWithID((self.pinLocation?.objectID)!) as? Pin
                }
                do {
                    try self.coreData!.backgroundContext.save()
                } catch {
                    let userInfo : [NSObject:AnyObject]? = [NSLocalizedDescriptionKey: "Error Searching Flickr\nPlease backout to main map and try again"]
                    completionHandler(success: false, error: NSError(domain: "FlickrClient", code: 3, userInfo: userInfo))
                    return
                }
        }
        completionHandler(success: true, error: nil)
    }
    
    // Download images in the background then update Coredata when complete
    internal func downloadImageToCoreData( aturl: NSURL, forPin: Pin, updateManagedObjectID: NSManagedObjectID, index: NSIndexPath?) {
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithURL(aturl){
            (data, response, error) -> Void in
            if error == nil {
                if data == nil {
                    return
                }
                self.coreData!.backgroundContext.performBlockAndWait(){
                    let photoForUpdate = self.coreData!.backgroundContext.objectWithID(updateManagedObjectID) as! Photo
                    let outputData : NSData = UIImagePNGRepresentation(UIImage(data: data!)!)!
                    photoForUpdate.setImage(outputData)
                    do {
                        try self.coreData!.backgroundContext.save()
                    }
                    catch {
                        return
                    }
                }
            }
        }
        task.resume()
    }
    
    internal func prefetchImages(location: Pin){
        pinLocation = location
        searchForPicturesByLatLonByPinByAsync(location){
            (success, results, error) -> Void in
            if success {
                self.populateCoreDataWithSearchResultsInFlickrClient(){
                    (success, error) -> Void in
                    if success {
                        let bfrc = self.getBackgroundContextFetchedResultsController()
                        for i in bfrc?.fetchedObjects as! [Photo] {
                            dispatch_async(dispatch_get_main_queue()){
                                self.downloadImageToCoreData(NSURL(string: i.url!)!, forPin: location, updateManagedObjectID: i.objectID, index: nil)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: Utilities
    
    private func constructImageURL(photo: [String : AnyObject]) -> NSURL {
        let farm = photo[Constants.FlickrURLConstructValue.Farm]!
        let server = photo[Constants.FlickrURLConstructValue.Server]!
        let secret = photo[Constants.FlickrURLConstructValue.Secret]!
        let id = photo[Constants.FlickrURLConstructValue.Id]!
        return NSURL(string:"https://farm\(farm).staticflickr.com/\(server)/\(id)_\(secret)_\(Constants.Flickr.ImageSize).jpg")!
    }
    
    private func parseResults(data: NSData?, completionHandlerForParsingData: (parsedDictinary: NSDictionary?, error: NSError?) -> Void){
        var parsedResult: NSDictionary
        do {
            parsedResult = try NSJSONSerialization.JSONObjectWithData(data!, options: .AllowFragments) as! NSDictionary
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
    
    private func getBackgroundContextFetchedResultsController() -> NSFetchedResultsController? {
        let request = NSFetchRequest(entityName: "Photo")
        request.sortDescriptors = []
        let p = NSPredicate(format: "pin = %@", argumentArray: [pinLocation!])
        request.predicate = p
        let frc = NSFetchedResultsController(fetchRequest: request, managedObjectContext: coreData!.backgroundContext, sectionNameKeyPath: nil, cacheName: nil)
        do {
            try frc.performFetch()
        } catch {
            return nil
        }
        return frc
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

