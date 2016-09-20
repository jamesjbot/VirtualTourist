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
import CoreData

class FlickrClient {
    
    
    // MARK: Variables
    let appdel = UIApplication.sharedApplication().delegate as! AppDelegate
    var photoSearchResultsArray : [[String:AnyObject]] = [[String:AnyObject]]()
    //var pinLocation: Pin?
    var urlPhotoID = [NSURL:NSManagedObjectID]()
    
    // MARK: Singleton
    
    private let context: NSManagedObjectContext = ((UIApplication.sharedApplication().delegate as! AppDelegate).stack?.context)!
    private let backgroundContext: NSManagedObjectContext = ((UIApplication.sharedApplication().delegate as! AppDelegate).stack?.backgroundContext)!
    
    private init(){}
    
    class func sharedInstance() -> FlickrClient {
        struct Singleton {
            static var sharedInstance = FlickrClient()
        }
        return Singleton.sharedInstance
    }
    
    
    func searchForPicturesByLatLonByPin(location: Pin ,completionHandlerTopLevel: (success: Bool, error: NSError?) -> Void ) {
    
        //self.pinLocation = location
        
        let methodParameters = [
            Constants.FlickrParameterKeys.Method : Constants.FlickrParameterValues.SearchMethod,
            Constants.FlickrParameterKeys.APIKey : Constants.FlickrParameterValues.APIKey,
            Constants.FlickrParameterKeys.SafeSearch : Constants.FlickrParameterValues.UseSafeSearch,
            Constants.FlickrParameterKeys.Extras : Constants.FlickrParameterValues.MediumURL,
            Constants.FlickrParameterKeys.Format : Constants.FlickrParameterValues.ResponseFormat,
            Constants.FlickrParameterKeys.NoJSONCallback : Constants.FlickrParameterValues.DisableJSONCallback,
        //print("\(#function) \(#line)THe type of methodsparams is \(methodParameters.dynamicType)")
            Constants.FlickrParameterKeys.Lat : location.latitude!,
            Constants.FlickrParameterKeys.Lon : location.longitude!
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
                    // Perform model updates
                    let photosElement = dict!["photos"]
                    self.photoSearchResultsArray = photosElement!["photo"] as! [[String:AnyObject]]
                    // Notify caller of task completion
                    completionHandlerTopLevel(success: true, error: nil)
                    return
                }
            }
        }
        task.resume()
    }
    
    func populateCoreDataWithSearchResults(completionHandler: (success: Bool, error: NSError?) -> Void ){
        // Add photos to core data
        for element in photoSearchResultsArray {
            dispatch_async(dispatch_get_main_queue()){
                () -> Void in
                self.prt(#file, line: #line, msg: "Creating coredataphoto next")
                let _ = Photo(image: nil, url: self.constructImageURL(element),  context: self.context)
                self.prt(#file, line: #line, msg: "After creating coredataphoto")
                do {                    try self.context.save()
                    print("\(#function) \(#line)Coredata save changes committed")

                } catch let error {
                    print("\(#function) \(#line)\(#line) Error saving placeholders in coredata\(error) ")
                    completionHandler(success: false,error: nil)
                }
            }
        }
        print("\(#function) \(#line) Completed Iterating thru photoSearchResults doesn't mean I completed adding elements to coredata")
        let frc = sanityCheck()
        print("Before saving FRC now has \(frc.fetchedObjects?.count)")
        do {
            try appdel.stack?.saveContext()
        } catch let error {
            print("Some error occured during saving background context \(error)")
        }
        print("After saving FRC now has \(frc.fetchedObjects?.count)")
        completionHandler(success: true, error: nil)
    }
    
    func downloadImage( aturl: NSURL, forPin: Pin, updateMangedObjectID: NSManagedObjectID) {
        let session = NSURLSession.sharedSession()
        //let request = NSURLRequest(URL: url)
        let task = session.dataTaskWithURL(aturl){
            (data, response, error) -> Void in
            //print("\(#function) \(#line)Finshed downloading images \(response)")
            if error == nil {
                self.prt(#function, line: #line, msg: "-----------------> Attempting to put image in to Coredata")
                if data == nil {
                    print("\(#function) \(#line)Image data is nil, the type is \(data.dynamicType)")
                    fatalError("Data returned nil")
                }
                //let image = UIImage(data: data!)
                
                //print(image)
                //let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
                print("\(#function) \(#line)===========>\(#function) Adding photo to context")
                //let context = (appDelegate.stack?.context)!
                    let photoForUpdate = self.context.objectWithID(updateMangedObjectID)
                    photoForUpdate.setValue(data, forKey: "imageData")
                    photoForUpdate.setValue(forPin, forKey: "pin")
                    do {
                        try self.context.save()
                        print("\(#function) \(#line)-----------------> Successfully added images to coredata")
                    } catch let error {
                        print("\(#function) \(#line)\(#line) \(#file) \n Error saving context \(error)")
                    }
            }
        }
        task.resume()
        //Photo(input: floatingAnnotation, context: (appDelegate.stack?.context)!)

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
            //print("\(#function) \(#line)Here is the answer")
            //print(parsedResult)
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
    
    
    func sanityCheck() -> NSFetchedResultsController {
        print("\(#function) \(#line)executeFetchResultsController() Called")
        let request = NSFetchRequest(entityName: "Photo")
        request.sortDescriptors = [NSSortDescriptor(key: "pin", ascending: true)]
        // For debugging
        request.sortDescriptors = []
        let appDel = UIApplication.sharedApplication().delegate as! AppDelegate
        let moc = appDel.stack?.backgroundContext
        let frc = NSFetchedResultsController(fetchRequest: request, managedObjectContext: moc!, sectionNameKeyPath: nil, cacheName: nil)
        
        do {
            try frc.performFetch()
            print("\(#function) \(#line)Number of objects retrieved with fetch request \(frc.fetchedObjects?.count)")
        } catch {
            fatalError("Failed to initialize FetchedResultsControler \(error)")
        }
        print("\(#function) \(#line)exiting initializefetchrequest")
        return frc
    }
    
}

extension FlickrClient {
    func prt(file: String, line: Int, msg: String){
        for index in file.characters.indices {
            if file[index] == "/" && !file.substringFromIndex(index.successor()).containsString("/"){
                let filename = file.substringFromIndex(index.successor())
                print("\(filename) \(line) \(msg)")
            }
        }
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

