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
    
    fileprivate var newCollection:[URL] = [URL]()
    
    fileprivate var pinLocation: Pin?
    
    fileprivate let coreData = (UIApplication.shared.delegate as! AppDelegate).stack
    
    // MARK: Singleton Function
    
    fileprivate init(){}
    class func sharedInstance() -> FlickrClient {
        struct Singleton {
            static var sharedInstance = FlickrClient()
        }
        return Singleton.sharedInstance
    }
    
    // MARK: Functions
    
    // Create a boundingBox for flickr search parameters
    fileprivate func boundingboxConstruct() -> String {
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
    internal func searchForPicturesByLatLonByPinByAsync(_ inputLocation: Pin ,
                                        completionHandlerTopLevel: ((_ success: Bool, _ results: Data?, _ error: NSError?) -> Void )?
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
        ] as [String : Any]
        let searchURL = createURLFromParameters(methodParameters as [String : AnyObject])
        let searchRequest = URLRequest(url: searchURL)
        print(searchRequest.url)
        let session = URLSession.shared
        session.configuration.timeoutIntervalForRequest = 10
        let task = session.dataTask(with:searchRequest) {
            (data, response, error) -> Void in
            self.guardChecks(data, response: response, error: error as NSError?) {
                (requestSuccess, error) -> Void in
                if !requestSuccess && completionHandlerTopLevel != nil
                {
                    if let completionHandlerTopLevel = completionHandlerTopLevel {
                        let userInfo : [AnyHashable: Any]? = [NSLocalizedDescriptionKey: "Error Searching Flickr\n\((error?.localizedDescription)!)\nPlease backout to main map and try again"]
                        completionHandlerTopLevel(false, nil, NSError(domain: "FlickrClient", code: 2, userInfo: userInfo))
                    }
                    return
                }
                self.parseResults(data) {
                    (dict, error) -> Void in
                    if error != nil {
                        if let completionHandlerTopLevel = completionHandlerTopLevel {
                            let userInfo : [AnyHashable : Any]? = [NSLocalizedDescriptionKey: "Error Searching Flickr\nPlease backout to main map and try again"]
                            completionHandlerTopLevel(false, nil, NSError(domain: "FlickrClient", code: 2, userInfo: userInfo))
                        }
                        return
                    }
                    // Perform model updates
                    let photosElement = dict![Constants.FlickrResponseKeys.Photos]
                    print(photosElement)
                    let photoResults = photosElement as! [String:AnyObject]
                    self.photoSearchResultsArray = photoResults[Constants.FlickrResponseKeys.Photo] as! [[String : AnyObject]]
                    if let completionHandlerTopLevel = completionHandlerTopLevel {
                        completionHandlerTopLevel(true, photosElement as? Data, nil)
                    }
                }
            }
            return ()
        }
        task.resume()
    }
    
    // From the search results, load only up the maximum allowed photos
    fileprivate func seperateNewCollectionFromResults(){
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
    internal func populateCoreDataWithSearchResultsInFlickrClient(_ completionHandler: @escaping ((_ success: Bool, _ error: NSError?) -> Void)){
        
        seperateNewCollectionFromResults()
        
        // In Coredata, remove the photos registered to this pin
        let bfrc = getBackgroundContextFetchedResultsController()
        guard bfrc != nil else {
            let userInfo : [AnyHashable: Any]? = [NSLocalizedDescriptionKey: "Error Saving Photos\nPlease try again"]
            completionHandler(false, NSError(domain: "FlickrClient", code: 5, userInfo: userInfo))
            return
        }
        
        //Remove photos
        coreData!.backgroundContext.performAndWait(){
            do {
                try bfrc!.performFetch()
            } catch {
                let userInfo : [AnyHashable: Any]? = [NSLocalizedDescriptionKey: "Error Removing Photos\nPlease try again"]
                completionHandler(false, NSError(domain: "FlickrClient", code: 3, userInfo: userInfo))
                return
            }
            for i in bfrc!.fetchedObjects! {
                self.coreData!.backgroundContext.delete(i as NSManagedObject)
            }
        }
        
        // Add new photos to core data, and save the related pin
        coreData!.backgroundContext.performAndWait()
            { () -> Void in
                for url in self.newCollection {
                    // Load the new photo for saving
                    let photo2BSaved = Photo(image: nil, url: url,  context: self.coreData!.backgroundContext)
                    // Convert main context pin location to the background context, and register thie photo to our pin
                    photo2BSaved.pin = self.coreData!.backgroundContext.object(with: (self.pinLocation?.objectID)!) as? Pin
                }
                
                do {
                    try self.coreData!.backgroundContext.save()
                } catch {
                    let userInfo : [AnyHashable: Any]? = [NSLocalizedDescriptionKey: "Error Searching Flickr\nPlease backout to main map and try again"]
                    completionHandler(false, NSError(domain: "FlickrClient", code: 3, userInfo: userInfo))
                    return
                }
        }
        completionHandler(true, nil)
    }
    
    // Download images in the background then update Coredata when complete
    internal func downloadImageToCoreData( _ aturl: URL, forPin: Pin, updateManagedObjectID: NSManagedObjectID, index: IndexPath?) {
        let session = URLSession.shared
        let task = session.dataTask(with: aturl, completionHandler: {
            (data, response, error) -> Void in
            if error == nil {
                if data == nil {
                    return
                }
                self.coreData!.backgroundContext.performAndWait(){
                    let photoForUpdate = self.coreData!.backgroundContext.object(with: updateManagedObjectID) as! Photo
                    let outputData : Data = UIImagePNGRepresentation(UIImage(data: data!)!)!
                    photoForUpdate.setImage(outputData)
                    do {
                        try self.coreData!.backgroundContext.save()
                    }
                    catch {
                        return
                    }
                }
            }
        })
        task.resume()
    }
    
    internal func prefetchImages(_ location: Pin){
        pinLocation = location
        searchForPicturesByLatLonByPinByAsync(location){
            (success, results, error) -> Void in
            if success {
                self.populateCoreDataWithSearchResultsInFlickrClient(){
                    (success, error) -> Void in
                    if success {
                        let bfrc = self.getBackgroundContextFetchedResultsController()
                        for i in (bfrc?.fetchedObjects)! as [Photo] {
                            DispatchQueue.main.async{
                                self.downloadImageToCoreData(URL(string: i.url!)!, forPin: location, updateManagedObjectID: i.objectID, index: nil)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: Utilities
    
    fileprivate func constructImageURL(_ photo: [String : AnyObject]) -> URL {
        print("photo:\n\(photo)")
        let farm = photo[Constants.FlickrURLConstructValue.Farm]!
        let server = photo[Constants.FlickrURLConstructValue.Server]!
        let secret = photo[Constants.FlickrURLConstructValue.Secret]!
        let id = photo[Constants.FlickrURLConstructValue.Id]!
        return URL(string:"https://farm\(farm).staticflickr.com/\(server)/\(id)_\(secret)_\(Constants.Flickr.ImageSize).jpg")!
    }
    
    fileprivate func parseResults(_ data: Data?, completionHandlerForParsingData: (_ parsedDictinary: NSDictionary?, _ error: NSError?) -> Void){
        var parsedResult: NSDictionary
        do {
            parsedResult = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as! NSDictionary
            completionHandlerForParsingData(parsedResult, nil)
            return
        } catch {
            let userInfo : [AnyHashable: Any]? = [NSLocalizedDescriptionKey: "Error Parsing Information\n Please try again"]
            completionHandlerForParsingData(nil, NSError(domain: "FlickrClient", code: 1, userInfo: userInfo))
            return
        }
    }
    
    fileprivate func guardChecks(_ data: Data?, response: URLResponse?, error: NSError?, completionHandlerForGuardChecks: @escaping (_ requestSuccess: Bool, _ error: NSError?)-> Void){
        
        func sendError(_ error: String) {
            let userInfo = [NSLocalizedDescriptionKey : error]
            completionHandlerForGuardChecks(false, NSError(domain: "FlickrClient", code: 1, userInfo: userInfo))
        }
        
        // GUARD: For any error
        guard (error == nil) else { // Handle error...
            sendError((error!.localizedDescription))
            return
        }
        
        // GUARD: There was no error from server; however server did not take further action
        guard (response as! HTTPURLResponse).statusCode != 403 else {
            sendError("Server not responding to request")
            return
        }
        
        // GUARD: Did we get successful 2XX response?
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode , statusCode >= 200 && statusCode <= 299 else {
            sendError("Your request returned a status code other than 2xx \((response as? HTTPURLResponse)!.statusCode)")
            return
        }
        
        // GUARD: Was there data returned?
        guard let _ = data else {
            sendError("No data was returned by the request!")
            return
        }
        
        completionHandlerForGuardChecks(true, nil)
    }
    
    fileprivate func createURLFromParameters(_ paramenters: [String:AnyObject]) -> URL {
        var components = URLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [URLQueryItem]()
        
        for (key, value) in paramenters {
            let queryItem = URLQueryItem(name: key, value: "\(value)")
            components.queryItems?.append(queryItem)
        }
        return components.url!
    }
    
    fileprivate func getBackgroundContextFetchedResultsController() -> NSFetchedResultsController<Photo>? {
        let request = NSFetchRequest<Photo>(entityName: "Photo")
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

