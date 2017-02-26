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

fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}

fileprivate func <= <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l <= r
  default:
    return !(rhs < lhs)
  }
}


class PhotoAlbumViewController: UIViewController, UICollectionViewDataSource {

    // MARK: - Constants
    
    fileprivate enum DataPopulationState {
        case bothCoreDataAndSearchEmpty
        case onlySearchAvailable
        case onlyCoreDataAvailable
        case bothCoreDataAndSearchAvailable
    }
    
    fileprivate enum BottomButtonState {
        case newCollection
        case delete
    }
    
    fileprivate enum Constants {
        static let DequeIdentifier = "PVCell"
    }
    
    fileprivate let NumberOfColumns = CGFloat(3)
    fileprivate let NumberOfSpacesBetweenColumns = CGFloat(2)
    fileprivate let coredata = (UIApplication.shared.delegate as! AppDelegate).stack
    fileprivate let mainContext: NSManagedObjectContext = ((UIApplication.shared.delegate as! AppDelegate).stack?.mainContext)!
    fileprivate let sectionInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    fileprivate let minimumSpacing = CGFloat(1)
    fileprivate let flickrClient = FlickrClient.sharedInstance()
    
    // MARK: - Variables
    fileprivate var insertedIndexPaths: [IndexPath]!
    fileprivate var deletedIndexPaths: [IndexPath]!
    fileprivate var updateIndexPaths: [IndexPath]!
    fileprivate var newSelectedIndexPaths: [IndexPath]! = [IndexPath]()
    fileprivate var localPhotoURLs = [URL]()
    fileprivate var dbAvailability: DataPopulationState = DataPopulationState.bothCoreDataAndSearchAvailable
    fileprivate var currentBottomButtonState : BottomButtonState = BottomButtonState.newCollection {
        didSet{
            switch currentBottomButtonState{
            case .delete:
                bottomButton.setTitle("Delete", for: UIControlState())
            case .newCollection:
                bottomButton.setTitle("New Collection", for: UIControlState())
            }
        }
    }
    internal var location: Pin!
    fileprivate var photoMainFrc : NSFetchedResultsController<Photo>?
    fileprivate var sizeOfCell: CGFloat!
    fileprivate var flowLayout : UICollectionViewFlowLayout?
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var bottomButton: UIButton!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionGrid: UICollectionView!
    @IBOutlet weak var initialActivityIndicator: UIActivityIndicatorView!
    
    // MARK: - IBActions
    
    // Receives action from the user to either Delete Selected Photos or Download a new Collection
    @IBAction func bottomButtonPressed(_ sender: AnyObject) {
        switch currentBottomButtonState {
        case BottomButtonState.delete:
            
            //Save references to maincontext managedobjects for later deletion
            var objects = [Photo]()
            newSelectedIndexPaths = newSelectedIndexPaths.sorted(by: sortFunc)
            for i in newSelectedIndexPaths {
                let temp : Photo = (photoMainFrc?.object(at: i))! as Photo
                objects.append(temp)
                let cell = collectionGrid.dequeueReusableCell(withReuseIdentifier: Constants.DequeIdentifier, for: i) as! PhotoViewCell
                cell.didUserSelect = false
                cell.activityIndic.isHidden = true
            }
            
            // Delete main context managed objects
            for i in objects {
                mainContext.delete(i)
            }
            
            // Clear the selection array so reused cells will display correctly
            newSelectedIndexPaths.removeAll()
            
            updateBottomButton()
            
        // Release selection array, reset UI, and then get a new collection from the web
        case BottomButtonState.newCollection:
            
            // Remove all selections
            newSelectedIndexPaths.removeAll()
            updateBottomButton()
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
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is MainMapViewController {
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
            // Stop the main center animation we have data.
            if self.photoMainFrc?.fetchedObjects?.count > 0 {
                self.performUpdatesOnMain(){ self.initialActivityIndicator.stopAnimating() }
            }
        }
        
        flickrClient.searchForPicturesByLatLonByPinByAsync(self.location){
            (success, results, error) -> Void in
            self.performUpdatesOnMain(){
                self.initialActivityIndicator.stopAnimating()
            }
            if self.photoMainFrc?.fetchedObjects?.count == 0 && error != nil {
                self.displayAlertWindow("Loading Error", msg: (error?.localizedDescription)!, actions: nil)
            } else {
                self.decideHowToProceedOnDataAvailability()
            }
        }
        
        currentBottomButtonState = BottomButtonState.newCollection
        
        initializeMapConfiguration()
        
        // CollectionView configuration
        setDeviceSpecificSizeOfCell()
        
        // Set size of cells on the collectionview
        initializeFlowLayout()
        
        // Set this CollectionView to receive updates
        collectionGrid.allowsMultipleSelection = true
        collectionGrid.allowsSelection = true
        photoMainFrc?.delegate = self
    }
    
    fileprivate func initializeMapConfiguration(){
        // MapView configuration
        let span = MKCoordinateSpanMake(3 , 3)
        let cll = CLLocationCoordinate2D(latitude: location.latitude as! Double, longitude: location.longitude as! Double)
        let region = MKCoordinateRegionMake(cll, span)
        mapView.setRegion(region, animated: true)
        let annotation = MKPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2D(latitude: location.latitude as! Double, longitude: location.longitude as! Double)
        mapView.addAnnotation(annotation)
    }
    
    // Initialize the CollectionViewFlowlayout
    fileprivate func initializeFlowLayout() {
        flowLayout = UICollectionViewFlowLayout()
        flowLayout!.itemSize = CGSize(width: sizeOfCell, height: sizeOfCell)
        flowLayout!.minimumInteritemSpacing = minimumSpacing
        flowLayout!.minimumLineSpacing = minimumSpacing
        flowLayout!.sectionInset = sectionInsets
        collectionGrid.collectionViewLayout = flowLayout!
    }
    
    // Sets the size of CollectionViewCells
    fileprivate func setDeviceSpecificSizeOfCell(){
        sizeOfCell = (view.frame.width - NumberOfSpacesBetweenColumns*minimumSpacing - sectionInsets.left - sectionInsets.right)/NumberOfColumns
    }
    
    fileprivate func decideHowToProceedOnDataAvailability(){
        if photoMainFrc?.fetchedObjects?.count < 1 { // Coredata empty
            if flickrClient.photoSearchResultsArray.count < 1 { // Search Empty
                dbAvailability = DataPopulationState.bothCoreDataAndSearchEmpty
            } else { // Search Full
                dbAvailability = DataPopulationState.onlySearchAvailable
            }
        } else { // Coredata Full
            if flickrClient.photoSearchResultsArray.count < 1 {// Search Empty
                dbAvailability = DataPopulationState.onlyCoreDataAvailable
            } else {// Search Full
                dbAvailability = DataPopulationState.bothCoreDataAndSearchAvailable
            }
        }
        
        // The act of coredata fetching results will populate the screen naturally
        
        // Reset selection array
        newSelectedIndexPaths.removeAll()
        switch dbAvailability {
        case .bothCoreDataAndSearchAvailable:
            // Do nothing CollectionView will initially load itself from the database
            break
        case .bothCoreDataAndSearchEmpty:
            displayAlertWindow("No Photos", msg: "No pictures taken at this location\n go back and choose another location. Press 'OK' to go back to main map!", actions: nil)
            break
        case .onlyCoreDataAvailable:
            // Do nothing CollectionView will initially load itself from the database
            break
        case .onlySearchAvailable:
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
    
    // Fetches photos from Coredata
    fileprivate func executeFetchResultsController(on location : Pin, completionHandler: (_ success: Bool?, _ error: NSError?)-> Void ){
        let request = NSFetchRequest<Photo>(entityName: "Photo")
        request.sortDescriptors = []
        request.predicate = NSPredicate(format: "pin = %@", argumentArray: [location])
        photoMainFrc = NSFetchedResultsController(fetchRequest: request, managedObjectContext: mainContext, sectionNameKeyPath: nil, cacheName: nil)
        do {
            try photoMainFrc?.performFetch()
        } catch {
            let userInfo : [AnyHashable: Any]? = [NSLocalizedDescriptionKey: "Error Reading Photos\nPlease try again"]
            completionHandler(false, NSError(domain: "PhotoAlbum", code: 0, userInfo: userInfo))
            return
        }
        // This is need to signal viewDidLoad
        completionHandler(true, nil)
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
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
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Constants.DequeIdentifier, for: indexPath) as! PhotoViewCell
        cell.isSelected = false
        cell.imageView!.alpha = 1.0
        cell.imageView?.image = nil
        cell.activityIndic.isHidden = true
        cell.activityIndic.stopAnimating()
        let coreDataPhoto = (photoMainFrc?.object(at: indexPath))! as Photo
        if newSelectedIndexPaths.contains(indexPath){
            cell.imageView?.alpha = 0.5
        } else {
            cell.imageView?.alpha = 1.0
        }
        
        switch (coreDataPhoto.imageData != nil){
        case true:
            let data : Data = coreDataPhoto.imageData!
            let im = UIImage(data: data)
            cell.activityIndic.isHidden = true
            cell.activityIndic.stopAnimating()
            cell.imageView?.image = im
            cell.coreDataObjectID = coreDataPhoto.objectID
            cell.url = coreDataPhoto.url
            return cell
            
        case false:
            cell.activityIndic.isHidden = false
            cell.activityIndic.startAnimating()
            cell.imageView!.image = nil
            cell.coreDataObjectID = coreDataPhoto.objectID
            cell.url = coreDataPhoto.url
            DispatchQueue.main.async{
                () -> Void in
                self.flickrClient.downloadImageToCoreData(URL(string: coreDataPhoto.url!)!, forPin: self.location!, updateManagedObjectID: coreDataPhoto.objectID, index: indexPath)
            }
            return cell
        }
    }
}

// MARK: NSFetchedResultsControllerDelegate methods
extension PhotoAlbumViewController : NSFetchedResultsControllerDelegate {
    
    // Create blank index path arrays that we will fill when changes come in.
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        insertedIndexPaths = [IndexPath]()
        deletedIndexPaths = [IndexPath]()
        updateIndexPaths = [IndexPath]()
    }
    
    // Collect changed indexPaths in designated array
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        // No indexpaths past the maximum amount of allowable images
        // This will constrain the number of images on screen.
        guard ((newIndexPath as NSIndexPath?)?.item <= FlickrClient.Constants.Flickr.MaximumShownImages && (indexPath as NSIndexPath?)?.item <= FlickrClient.Constants.Flickr.MaximumShownImages) else {
            return
        }
        
        switch (type){
        case .insert:
            insertedIndexPaths.append(newIndexPath!)
        case .delete:
            deletedIndexPaths.append(indexPath!)
        case .move:
            // No action needed for this response
            break
        case .update:
            updateIndexPaths.append(indexPath!)
        }
    }
    
    // Commit changes to the collection grid.
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        collectionGrid.performBatchUpdates({ () -> Void in
            // Insert new index paths.
            for indexPath in self.insertedIndexPaths {
                self.collectionGrid.insertItems(at: [indexPath])
            }
            
            // Sort from largest to smallest indexpath, so deletes don't occur on nonexistent cell
            // This will delete indexPaths at the end first.
            self.deletedIndexPaths = self.deletedIndexPaths.sorted(by: self.sortFunc)
            
            // Delete end index paths
            for indexPath in self.deletedIndexPaths {
                self.collectionGrid.deleteItems(at: [indexPath])
            }
            
            // Update index paths when data like image data has changed.
            for indexPath in self.updateIndexPaths {
                self.collectionGrid.reloadItems(at: [indexPath])
            }
            
            // Push all change to file.
            //self.coredata?.saveToFile()
            self.coredata?.savePhotoAlbumChangesToFile()
            } , completion: nil)
    } // end of controllerDidChangeContent
}

// MARK: UICollectionViewDelegate
extension PhotoAlbumViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func collectionView(_ collectionsView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Whenever a cell is tapped we will toggle its presence in the selectedIndexes array
        if let index = newSelectedIndexPaths.index(of: indexPath) {
            newSelectedIndexPaths.remove(at: index)
        } else {
            newSelectedIndexPaths.append(indexPath)
        }
        
        updateBottomButton()
        // Force cell to rerender
        collectionView.reloadItems(at: [indexPath])
    }
    
    // Changes bottom button's text and functionality
    func updateBottomButton(){
        if newSelectedIndexPaths.count > 0 {
            currentBottomButtonState = BottomButtonState.delete
        } else {
            currentBottomButtonState = BottomButtonState.newCollection
        }
    }
}

extension PhotoAlbumViewController {
    
    // MARK: Utility
    
    // Function to performUIUpdates on main queue
    fileprivate func performUpdatesOnMain(_ updates: @escaping () -> Void) {
        DispatchQueue.main.async {
            updates()
        }
    }
    
    fileprivate func sortFunc(_ i0: IndexPath, i1: IndexPath) -> Bool {
        return (i0 as NSIndexPath).item > (i1 as NSIndexPath).item
    }
    
    // MARK: Specialized alert displays for UIViewControllers
    fileprivate func displayAlertWindow(_ title: String, msg: String, actions: [UIAlertAction]?){
        DispatchQueue.main.async { () -> Void in
            let alertWindow: UIAlertController = UIAlertController(title: title, message: msg, preferredStyle: UIAlertControllerStyle.alert)
            alertWindow.addAction(self.dismissAction())
            if let array = actions {
                for action in array {
                    alertWindow.addAction(action)
                }
            }
            self.present(alertWindow, animated: true, completion: nil)
        }
    }
    
    fileprivate func dismissAction()-> UIAlertAction {
        return UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.default, handler: nil)
    }
}

