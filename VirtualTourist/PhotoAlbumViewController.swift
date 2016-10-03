//
//  PhotoAlbumViewController.swift
//  VirtualTourist
//
//  Created by James Jongsurasithiwat on 9/4/16.
//  Copyright © 2016 James Jongs. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController, UICollectionViewDataSource {
    

    
    private var insertedIndexPaths: [NSIndexPath]!
    private var deletedIndexPaths: [NSIndexPath]!
    private var updateIndexPaths: [NSIndexPath]!
    private var newSelectedIndexPaths: [NSIndexPath]! = [NSIndexPath]()

    // MARK: - Debug statements
    
    private let coredata = (UIApplication.sharedApplication().delegate as! AppDelegate).stack
    private let mainContext: NSManagedObjectContext = ((UIApplication.sharedApplication().delegate as! AppDelegate).stack?.mainContext)!
    private let backgroundContext: NSManagedObjectContext = ((UIApplication.sharedApplication().delegate as! AppDelegate).stack?.backgroundContext)!
    private let persistentContext: NSManagedObjectContext = ((UIApplication.sharedApplication().delegate as! AppDelegate).stack?.persistingContext)!
    
    // MARK: - Constants
    
    enum DataPopulationState {
        case BothCoreDataAndSearchEmpty
        case OnlySearchAvailable
        case OnlyCoreDataAvailable
        case BothCoreDataAndSearchAvailable
    }
    
    enum BottomButtonState {
        case NewCollection
        case Delete
    }
    
    enum Constants {
        static let DequeIdentifier = "PVCell"
    }
    
    private var sectionInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    private let minimumSpacing = CGFloat(1)
    private let flickrClient = FlickrClient.sharedInstance()
    
    // MARK: - Variables
    
    var localPhotoURLs = [NSURL]()
    var dbAvailability: DataPopulationState = DataPopulationState.BothCoreDataAndSearchAvailable
    var currentBottomButtonState : BottomButtonState = BottomButtonState.NewCollection {
        didSet{
            switch currentBottomButtonState{
            case .Delete:
                bottomButton.setTitle("Delete", forState: .Normal)
            case .NewCollection:
                bottomButton.setTitle("New Collection", forState: .Normal)
            }
        }
    }
    var location: Pin!
    var photoMainFrc : NSFetchedResultsController?
    private var sizeOfCell: CGFloat!
    private var flowLayout : UICollectionViewFlowLayout?
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var bottomButton: UIButton!
    
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var collectionGrid: UICollectionView!
    
    // MARK: - IBActions
    // Receives action from the user to either Delete Selected Photos or Download a new Collection
    @IBAction func bottomButtonPressed(sender: AnyObject) {
        switch currentBottomButtonState {
        case BottomButtonState.Delete:
            
            //Save references to maincontext managedobjects for later deletion
            let context  = (UIApplication.sharedApplication().delegate as! AppDelegate).stack?.mainContext
            var objects = [Photo]()
            newSelectedIndexPaths = newSelectedIndexPaths.sort(sortFunc)
            for i in newSelectedIndexPaths {
                let temp : Photo = photoMainFrc?.objectAtIndexPath(i) as! Photo
                objects.append(temp)
                var cell = self.collectionGrid.dequeueReusableCellWithReuseIdentifier(Constants.DequeIdentifier, forIndexPath: i) as! PhotoViewCell
                cell.didUserSelect = false
                cell.activityIndic.hidden = true
            }
            
            // Delete main context managed objects
            for i in objects {
                context?.deleteObject(i)
            }
            
            // Clear the selection array so reused cells will display correctly
            newSelectedIndexPaths.removeAll()
            
            // Save managedobject changes into the persistent context
            do {
                try context!.save()
            } catch let error {
                fatalError()
            }
            updateBottomButton()
            
        // Release selection array, reset UI, and then get a new collection from the web
        case BottomButtonState.NewCollection:
            // Remove all selections
            newSelectedIndexPaths.removeAll()
            updateBottomButton()
            flickrClient.pinLocation = location
            flickrClient.populateCoreDataWithSearchResultsInFlickrClient(){
                (success, error ) -> Void in
                if error != nil {
                    self.displayAlertWindow("Loading Error", msg: (error?.localizedDescription)!, actions: nil)
                }
            }
        }
    }
    
    // MARK: - Functions
    
    // When returning back to previous screen save all results to the database
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.destinationViewController is MainMapViewController {
            coredata?.saveToFile()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Fetch CoreData model.
        executeFetchResultsController(on: location){
            (success, error ) -> Void in
            if error != nil {
                self.displayAlertWindow("Loading Error", msg: (error?.localizedDescription)!, actions: nil)
            }
        }

        self.flickrClient.searchForPicturesByLatLonByPinByAsync(self.location){
            (success, results, error) -> Void in
            if success {
                self.decideHowToProceedOnDataAvailability()
            } else {
                self.displayAlertWindow("Loading Error", msg: (error?.localizedDescription)!, actions: nil)
            }
        }
        
        currentBottomButtonState = BottomButtonState.NewCollection
        
        // MapView configuration
        let span = MKCoordinateSpanMake(3 , 3)
        let cll = CLLocationCoordinate2D(latitude: location.latitude as! Double, longitude: location.longitude as! Double)
        let region = MKCoordinateRegionMake(cll, span)
        mapView.setRegion(region, animated: true)
        let annotation = MKPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2D(latitude: location.latitude as! Double, longitude: location.longitude as! Double)
        mapView.addAnnotation(annotation)
        
        // CollectionView configuration
        setDeviceSpecificSizeOfCell()
        // Set size of cells on the collectionview
        flowLayout = UICollectionViewFlowLayout()
        initializeFlowLayout()
        
        // Set this CollectionView to receive updates
        collectionGrid.dataSource = self
        collectionGrid.delegate = self
        collectionGrid.allowsMultipleSelection = true
        collectionGrid.allowsSelection = true
        self.photoMainFrc?.delegate = self
    }
    
    func decideHowToProceedOnDataAvailability(){
        if photoMainFrc?.fetchedObjects?.count < 1 { // Coredata empty
            if flickrClient.photoSearchResultsArray.count < 1 { // Search Empty
                dbAvailability = DataPopulationState.BothCoreDataAndSearchEmpty
            } else { // Search Full
                dbAvailability = DataPopulationState.OnlySearchAvailable
            }
        } else { // Coredata Full
            if flickrClient.photoSearchResultsArray.count < 1 {// Search Empty
                dbAvailability = DataPopulationState.OnlyCoreDataAvailable
            } else {// Search Full
                dbAvailability = DataPopulationState.BothCoreDataAndSearchAvailable
            }
        }
        
        // The act of coredta fetching results will populate the screen
        // Reset selection array
        newSelectedIndexPaths.removeAll()
        switch dbAvailability {
        case .BothCoreDataAndSearchAvailable:
            // Do nothing CollectionView will initially load itself from the database
            break
        case .BothCoreDataAndSearchEmpty:
            self.displayAlertWindow("No Photos", msg: "No pictures taken at this location\n go back and choose another location. Press 'OK' to go back to main map!", actions: [self.dismissAction()])
            break
        case .OnlyCoreDataAvailable:
            // Do nothing CollectionView will initially load itself from the database
            break
        case .OnlySearchAvailable:
            assert(photoMainFrc?.fetchedObjects!.count < 1 )
            flickrClient.populateCoreDataWithSearchResultsInFlickrClient(){
                (success, error ) -> Void in
                if error != nil {
                    self.displayAlertWindow("Loading Error", msg: (error?.localizedDescription)!, actions: nil)
                }
            }
            break
        }
    }
    
    // Initialize the CollectionViewFlowlayout
    func initializeFlowLayout() {
        flowLayout!.itemSize = CGSize(width: sizeOfCell, height: sizeOfCell)
        flowLayout!.minimumInteritemSpacing = minimumSpacing
        flowLayout!.minimumLineSpacing = minimumSpacing
        flowLayout!.sectionInset = sectionInsets
        collectionGrid.collectionViewLayout = flowLayout!
    }
    
    // Sets the size of CollectionViewCells
    func setDeviceSpecificSizeOfCell(){
        self.sizeOfCell = (view.frame.width - 6*minimumSpacing)/3 - 5
    }
    
    // Fetches photos from Coredata
    func executeFetchResultsController(on location : Pin, completionHandler: (success: Bool?, error: NSError?)-> Void ){
        let request = NSFetchRequest(entityName: "Photo")
        request.sortDescriptors = []
        let p = NSPredicate(format: "pin = %@", argumentArray: [location])
        request.predicate = p
        photoMainFrc = NSFetchedResultsController(fetchRequest: request, managedObjectContext: mainContext, sectionNameKeyPath: nil, cacheName: nil)
        do {
            try self.photoMainFrc?.performFetch()
        } catch {
            let userInfo : [NSObject:AnyObject]? = [NSLocalizedDescriptionKey: "Error Reading Photos\nPlease try again"]
            completionHandler(success: false, error: NSError(domain: "PhotoAlbum", code: 0, userInfo: userInfo))
            return
        }
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // Only display a maximum number of images
        guard photoMainFrc?.fetchedObjects?.count != nil else {
            return 0
        }
        if (photoMainFrc?.fetchedObjects?.count)! >= FlickrClient.Constants.Flickr.MaximumShownImages {
            return FlickrClient.Constants.Flickr.MaximumShownImages
        }
        return (photoMainFrc?.fetchedObjects?.count)!
    }
    
    // Download initiated on async task on mainqueue
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        var cell = collectionView.dequeueReusableCellWithReuseIdentifier(Constants.DequeIdentifier, forIndexPath: indexPath) as! PhotoViewCell
        cell.selected = false
        cell.imageView!.alpha = 1.0
        cell.imageView?.image = nil
        cell.activityIndic.hidden = true
        cell.activityIndic.stopAnimating()
        let coreDataPhoto = self.photoMainFrc?.objectAtIndexPath(indexPath) as! Photo
        if newSelectedIndexPaths.contains(indexPath){
            cell.imageView?.alpha = 0.5
        } else {
            cell.imageView?.alpha = 1.0
        }
        
        switch (coreDataPhoto.imageData != nil){
        case true:
            let data : NSData = coreDataPhoto.imageData!
            let im = UIImage(data: data)
            cell.activityIndic.stopAnimating()
            cell.activityIndic.hidden = true
            cell.coreDataObjectID = coreDataPhoto.objectID
            cell.imageView?.image = im
            cell.url = coreDataPhoto.url
            return cell
            
        case false:
            cell.activityIndic.hidden = false
            cell.activityIndic.startAnimating()
            cell.imageView!.image = nil
            cell.coreDataObjectID = coreDataPhoto.objectID
            cell.url = coreDataPhoto.url
            dispatch_async(dispatch_get_main_queue()){
                () -> Void in
                self.flickrClient.downloadImageToCoreData(NSURL(string: coreDataPhoto.url!)!, forPin: self.location!, updateManagedObjectID: coreDataPhoto.objectID, index: indexPath)
            }
            return cell
        }
    }
}

// MARK: NSFetchedResultsControllerDelegate methods
extension PhotoAlbumViewController : NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        insertedIndexPaths = [NSIndexPath]()
        deletedIndexPaths = [NSIndexPath]()
        updateIndexPaths = [NSIndexPath]()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
        guard (newIndexPath?.item <= FlickrClient.Constants.Flickr.MaximumShownImages && indexPath?.item <= FlickrClient.Constants.Flickr.MaximumShownImages) else {
            return
        }
        switch (type){
        case .Insert:
            insertedIndexPaths.append(newIndexPath!)
        case .Delete:
            deletedIndexPaths.append(indexPath!)
        case .Move:
            // No action needed for this response
            break
        case .Update:
            updateIndexPaths.append(indexPath!)
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        collectionGrid.performBatchUpdates({ () -> Void in
            for indexPath in self.insertedIndexPaths {
                self.collectionGrid.insertItemsAtIndexPaths([indexPath])
            }
            // Sort from largest to smallest indexpath, so deletes don't occur on nonexistent cell
            self.deletedIndexPaths = self.deletedIndexPaths.sort(self.sortFunc)
            
            for indexPath in self.deletedIndexPaths {
                self.collectionGrid.deleteItemsAtIndexPaths([indexPath])
            }
            
            for indexPath in self.updateIndexPaths {
                self.collectionGrid.reloadItemsAtIndexPaths([indexPath])
            }
            } , completion: nil)
    }
}


// MARK: UICollectionViewDelegate
extension PhotoAlbumViewController: UICollectionViewDelegate {
    
    func collectionView(collectionView: UICollectionView, shouldSelectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func collectionView(collectionsView: UICollectionView, shouldDeselectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        // Whenever a cell is tapped we will toggle its presence in the selectedIndexes array
        if let index = newSelectedIndexPaths.indexOf(indexPath) {
            newSelectedIndexPaths.removeAtIndex(index)
        } else {
            newSelectedIndexPaths.append(indexPath)
        }
        
        updateBottomButton()
        // Force cell to rerender
        let _ = collectionView.dequeueReusableCellWithReuseIdentifier(Constants.DequeIdentifier, forIndexPath: indexPath) as! PhotoViewCell
        collectionView.reloadItemsAtIndexPaths([indexPath])
    }
    
    // Changes bottom button's text and functionality
    func updateBottomButton(){
        if newSelectedIndexPaths.count > 0 {
            currentBottomButtonState = BottomButtonState.Delete
        } else {
            currentBottomButtonState = BottomButtonState.NewCollection
        }
    }
}

extension PhotoAlbumViewController {
    
    // MARK: Utility
    
    func sortFunc(i0: NSIndexPath, i1: NSIndexPath) -> Bool {
        return i0.item > i1.item
    }
    
    // MARK: Specialized alert displays for UIViewControllers
    func displayAlertWindow(title: String, msg: String, actions: [UIAlertAction]?){
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            let alertWindow: UIAlertController = UIAlertController(title: title, message: msg, preferredStyle: UIAlertControllerStyle.Alert)
            alertWindow.addAction(self.dismissAction())
            if let array = actions {
                for action in array {
                    alertWindow.addAction(action)
                }
            }
            self.presentViewController(alertWindow, animated: true, completion: nil)
        }
    }
    
    func dismissAction()-> UIAlertAction {
        return UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil)
    }
}

