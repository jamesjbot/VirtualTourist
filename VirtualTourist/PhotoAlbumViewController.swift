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
    
    // MARK: - Debug statements
    
    
    // MARK: - Constants
    
    let PHOTOALBUMCELLIDENTIFIER = "PVCell"
    private var sectionInsets = UIEdgeInsets(top: 5, left: 8, bottom: 50, right: 8)
    private let minimumSpacing = CGFloat(1)
    private let flickrClient = FlickrClient.sharedInstance()
    private let maximumImages = 21
    
    // MARK: - Variables
    
    var selectedPhotos = [Bool]()//(count: 21, repeatedValue: false)
    var localPhotoURLs = [NSURL]()
    enum BottomButtonState {
        case NewCollection
        case Delete
    }
    
    var currentBottomButtonState : BottomButtonState = BottomButtonState.NewCollection {
        didSet{
            if currentBottomButtonState == BottomButtonState.Delete {
                bottomButton.setTitle("Delete", forState: .Normal)
            } else {
                bottomButton.setTitle("New Collection", forState: .Normal)
            }}
    }
    
    var location: Pin!
    var frc : NSFetchedResultsController?
    private var sizeOfCell: CGFloat!
    private var flowLayout : UICollectionViewFlowLayout?
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var bottomButton: UIButton!
    
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var collectionGrid: UICollectionView!
    
    // MARK: - IBActions
    
    @IBAction func bottomButtonPressed(sender: AnyObject) {
        switch(currentBottomButtonState) {
        case BottomButtonState.Delete:
            let context  = (UIApplication.sharedApplication().delegate as! AppDelegate).stack?.context
            prt(#file, line: #line, msg: "perform block next")
            context?.performBlockAndWait(){
                for (index,b) in self.selectedPhotos.enumerate() {
                    if b {
                        self.prt(#file, line: #line, msg: "attempting to delete entry at index: \(index)")
                        self.prt(#file, line: #line, msg: "Collectiongrid before deletion \(self.collectionGrid.numberOfItemsInSection(0))")
                        self.prt(#file, line: #line, msg: "deleting object next")
                        let indexPath = NSIndexPath(forItem: index, inSection: 0)
                        let deletableObject = self.frc?.objectAtIndexPath(indexPath) as! NSManagedObject
                        context?.deleteObject(deletableObject)
                        self.prt(#file, line: #line, msg: "deleted object savingcontext")
                        print("Context is deleting these objects \(context?.deletedObjects)")
                        self.selectedPhotos[index] = false
                        self.prt(#file, line: #line, msg: "Context saved")
                        self.prt(#file, line: #line, msg: "now change did occur will fire and delete the object causing a rift in viewcontroller order")
                    }
                }
                do {
                    try context?.save()
                } catch let error {
                    context?.undo()
                    fatalError("Error saving context \(error)")
                }
                
                self.currentBottomButtonState = BottomButtonState.NewCollection
            }
        case BottomButtonState.NewCollection:
            print("To be implemented fetch new items now")
            flickrClient.loadNewCollection()
        }
    }
    
    
    

    
    // MARK: - Functions
    
    func resetSelectedPhotos() {
        for (i,_) in selectedPhotos.enumerate() {
            selectedPhotos[i] = false
        }
    }
    
    func populateSelectedPhotos(amt: Int){
        for _ in 0 ..< amt {
            selectedPhotos.append(Bool(false))
        }
    }
    
    
    func testingDeleteAllPhotos() {
        //Slow one by one way
        let slowWAy = true
        let appDel = UIApplication.sharedApplication().delegate as! AppDelegate
        if slowWAy {
            executeFetchResultsController()
            
            for photo in (frc?.fetchedObjects)! {
                let appDel = UIApplication.sharedApplication().delegate as! AppDelegate
                (appDel.stack?.context)!.deleteObject(photo as! Photo)
            }
            do {
                try appDel.stack?.context.save()
            } catch let error {
                fatalError("There was an error saving deletes \(error)")
            }
            
        } else { // fast way delete everything EVEN THE PINS
            (appDel.stack?.context)!.deletedObjects
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Testing
        prt(#file, line: #line, msg: "The following fetch is to delete data")
        testingDeleteAllPhotos()
        
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
        
        executeFetchResultsController()
        
        // Set this CollectionView to receive updates
        //self.frc?.delegate = self
        collectionGrid.dataSource = self
        collectionGrid.delegate = self
        collectionGrid.allowsMultipleSelection = true
        collectionGrid.allowsSelection = true
        self.frc?.delegate = self
        if frc?.fetchedObjects?.count < 1 {
            flickrClient.searchForPicturesByLatLonByPin(location){
                (success, error) -> Void in
                if success {
                    self.prt(#file, line: #line, msg: "------------------")
                    print("completed latlon search")
                    print("There are now \((self.frc?.fetchedObjects?.count)!) frc results" )
                    self.prt(#file, line: #line, msg: "But there are \(self.flickrClient.photoSearchResultsArray.count) photoSearchResults")
                    self.localPhotoURLs = self.flickrClient.visibleSearchResultsURL
                    // After loading CoreData register for changes

                    self.collectionGrid.reloadData()
                    print("I reloaded the data")
                }
            }
            prt(#file, line: #line, msg: "Quickly Exited completion handler, You must realize this")
        } else {
            // We have at least 1 save photo load it.
        }
        populateSelectedPhotos((frc?.fetchedObjects?.count)!)
    }
    
    func initializeFlowLayout() {
        
        flowLayout!.itemSize = CGSize(width: sizeOfCell, height: sizeOfCell)
        flowLayout!.minimumInteritemSpacing = minimumSpacing
        flowLayout!.minimumLineSpacing = minimumSpacing
        flowLayout!.sectionInset = sectionInsets
        collectionGrid.collectionViewLayout = flowLayout!
        
    }
    
    func setDeviceSpecificSizeOfCell(){
        self.sizeOfCell = (view.frame.width - 6*minimumSpacing)/3 - 5
    }
    
    func executeFetchResultsController(){
        prt(#file, line: #line, msg: "executeFetchResultsController() Called")
        let request = NSFetchRequest(entityName: "Photo")
        request.sortDescriptors = [NSSortDescriptor(key: "pin", ascending: true)]
        // For debugging
        request.sortDescriptors = []
        let appDel = UIApplication.sharedApplication().delegate as! AppDelegate
        let moc = appDel.stack?.context
        frc = NSFetchedResultsController(fetchRequest: request, managedObjectContext: moc!, sectionNameKeyPath: nil, cacheName: nil)
        
        do {
            try frc?.performFetch()
            prt(#file, line: #line, msg: "Number of objects retrieved with fetch request \(frc?.fetchedObjects?.count)")
        } catch {
            fatalError("Failed to initialize FetchedResultsControler \(error)")
        }
        prt(#file, line: #line, msg: "exiting initializefetchrequest")
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // Only display a maximum number of images
        // These lines of code are never run because I've limited the loading of CoreData to just 21 images
        if (frc?.fetchedObjects?.count)! > maximumImages {
            return maximumImages
        }
        return (frc?.fetchedObjects?.count)!
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        // Get a cell from the storyboard up to maximum allowed storyboard cell
        
        // Get data from model and populate it into dequeued storyboard cell
        
        // The storyboard cell knows whether it is selected or not.
        
        // When you scroll the collection view this is called
        
        prt(#file, line: #line, msg: "******cellForItemAtIndexPathCalled location:\(indexPath.item)")
        let coreDataPhoto = frc?.objectAtIndexPath(indexPath) as! Photo
        
        // We are dequeuing up to a maximum of 21 cell form the story board

        //prt(#file, line: #line, msg: "Dequeuing a UICell and inserting Incoming indexPath \(indexPath)")
        let cell = collectionGrid.dequeueReusableCellWithReuseIdentifier(PHOTOALBUMCELLIDENTIFIER, forIndexPath: indexPath) as! PhotoViewCell
        
        // Save identifying information into StoryBoardPhotoViewCell to debug
        cell.coreDataObjectID = coreDataPhoto.objectID
        cell.url = coreDataPhoto.url
        
        
        switch ((frc?.fetchedObjects![indexPath.item] as! Photo).imageData){
        case nil:
            print("cellForItemAtIndexPath photo is not in frc")
            cell.activityIndic.hidden = false
            cell.activityIndic.startAnimating()

            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)){
                () -> Void in
                self.flickrClient.downloadImageToCoreData(NSURL(string: coreDataPhoto.url!)!, forPin: self.location!, updateManagedObjectID: coreDataPhoto.objectID)
            }
            prt(#file, line: #line, msg: "\(#function) \(#line) Returning a Nil Cell")
        case _ :
            print("cellForItemAtIndexPath photo is present in frc")
            cell.activityIndic.hidden = true
            cell.activityIndic.stopAnimating()
            cell.imageView.image = UIImage(data: coreDataPhoto.imageData!)
            prt(#file, line: #line, msg: "Returning a Image Populated Cell")
        }
        
        // Selection Formatting of cell
        switch (selectedPhotos[indexPath.item]) {
        case true:
            cell.selected = true
        case false:
            cell.selected = false
        }
//        if coreDataPhoto.imageData == nil {
//            cell.activityIndic.hidden = false
//            cell.activityIndic.startAnimating()
//            dispatch_async(dispatch_get_main_queue()){
//                () -> Void in
//                self.flickrClient.downloadImage(NSURL(string: coreDataPhoto.url!)!, forPin: self.location!, updateManagedObjectID: coreDataPhoto.objectID)
//            }
//            prt(#file, line: #line, msg: "\(#function) \(#line) Returning a Nil Cell")
//        } else {
//            cell.activityIndic.hidden = true
//            cell.activityIndic.stopAnimating()
//            cell.imageView.image = UIImage(data: coreDataPhoto.imageData!)
//            switch (selectedPhotos[indexPath.item]) {
//            case true:
//                cell.selected = true
//            case false:
//                cell.selected = false
//            }
//            prt(#file, line: #line, msg: "Returning a Image Populated Cell")
//        }
        return cell
    }
}

// MARK: NSFetchedResultsControllerDelegate methods
extension PhotoAlbumViewController : NSFetchedResultsControllerDelegate {

    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        prt(#file, line: #line, msg: "controllerWillChangeContent called")
    }
    
    
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        prt(#file, line: #line, msg: "-----------------------------------------------------")
        prt(#file, line: #line, msg: "CoreData changed detected")
        prt(#file, line: #line, msg: "Did change object called Old index:\(indexPath?.item)")
        prt(#file, line: #line, msg: "Changing CollectionView Cell at New index:\((newIndexPath?.item))")
        prt(#file, line: #line, msg: "Type:\(anObject.dynamicType),\n objectDescription: \(anObject)")
        prt(#file, line: #line, msg: "The change type is: 1Insert, 2Delete, 3Move, 4Update\(type.rawValue)")
        
        self.prt(#file, line: #line, msg: "Collectiongrid before deletion \(self.collectionGrid.numberOfItemsInSection(0))")
        self.prt(#file, line: #line, msg: "FRC before deletion \(self.frc?.fetchedObjects?.count)")
        
        guard (newIndexPath?.item <= maximumImages && indexPath?.item <= maximumImages) else {
            print("Guard statment blocked didChangeObject")
            return
        }
        self.viewMangedObjectID()
        self.prt(#file, line: #line, msg: "Collectiongrid before deletion \(self.collectionGrid.numberOfItemsInSection(0))")
        
        // A hack to get collectionGrid in the correct state
        collectionGrid.reloadData()
        // now to check to make sure it is corrrct
        print("Check correct ness of models")
        self.viewMangedObjectID()
        
        //dispatch_sync(dispatch_get_main_queue()){
            switch (type){
            case .Insert:
                self.prt(#file, line: #line, msg: "Initial Loading")
                //collectionGrid.reloadItemsAtIndexPaths([newIndexPath!])
                //collectionGrid.reloadData()
                
                //self.collectionGrid.insertItemsAtIndexPaths([newIndexPath!])
                //let update = collectionGrid.insertItemsAtIndexPaths([newIndexPath])
                //            if frc?.fetchedObjects?.count != self.flickrClient.photoSearchResultsArray.count {
                //                return
                //            }
                self.prt(#file, line: #line, msg: "You should update the view controller now")
            case .Delete:
                self.prt(#file, line: #line, msg: "Collectiongrid before deletion \(self.collectionGrid.numberOfItemsInSection(0))")
                //fatalError("Delete is not currently acceptable")
                self.prt(#file, line: #line, msg: "this is a delete")
                //self.collectionGrid.deleteItemsAtIndexPaths([indexPath!])
            case .Move:
                fatalError("Should never occur")
                self.prt(#file, line: #line, msg: "this is a move")
                if indexPath != newIndexPath {
                    self.prt(#file, line: #line, msg: "Why are these different \(indexPath?.item) \(newIndexPath?.item)")
                }
                let cell = self.collectionGrid.cellForItemAtIndexPath(newIndexPath!) as! PhotoViewCell
                if cell.imageView.image != nil {
                    self.prt(#file, line: #line, msg: "Here is the problem <----------------- This image is already populated")
                }
                //collectionGrid.reloadItemsAtIndexPaths([indexPath!])
                //self.collectionGrid.deleteItemsAtIndexPaths([indexPath!])
                //self.collectionGrid.insertItemsAtIndexPaths([newIndexPath!])
                self.prt(#file, line: #line, msg: "This many Photo objects in coredata:\((self.frc?.fetchedObjects?.count)!)")
                for photo in (self.frc?.fetchedObjects)! {
                    print(photo)
                }
            //collectionGrid.reloadData()
            case .Update:
                //fatalError("Update is not curretnly acceptable")
                self.prt(#file, line: #line, msg: "this is an update")
                //self.collectionGrid.reloadItemsAtIndexPaths([indexPath!])
            }
            
        //}
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        //prt(#file, line: #line, msg: "Controller Did Change Content fired")
        collectionGrid.reloadData()
    }
    
}


// MARK: UICollectionViewDelegate
extension PhotoAlbumViewController: UICollectionViewDelegate {
    
    func collectionView(collectionView: UICollectionView, shouldSelectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        print("Should Select item called")
        return true
    }
    
    func collectionView(collectionView: UICollectionView, shouldDeselectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        print("Should Deselect item called")
        return true
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        print("You selected item at indexpath \(indexPath.item)")
        print("Before \(selectedPhotos)")
        selectedPhotos[indexPath.item] = true
        print("After \(selectedPhotos)")
        let cell = collectionGrid.cellForItemAtIndexPath(indexPath) as! PhotoViewCell
        //cell.imageView.alpha = 0.50
        print("Collectionview selection has this many selected now: \(collectionGrid.indexPathsForSelectedItems()!.count)")
        if currentBottomButtonState != BottomButtonState.Delete {
            currentBottomButtonState = BottomButtonState.Delete
        }
    }
    
    func collectionView(collectionView: UICollectionView, didDeselectItemAtIndexPath indexPath: NSIndexPath) {
        print("You deselected item at indexpath \(indexPath.item)")
        print("Before \(selectedPhotos)")
        selectedPhotos[indexPath.item] = false
        print("After \(selectedPhotos)")
        print("Collectionview selection has this many selected now: \(collectionGrid.indexPathsForSelectedItems()!.count)")
        let cell = collectionGrid.cellForItemAtIndexPath(indexPath) as! PhotoViewCell
        //cell.imageView.alpha = 1.0
        print("colleciton holds \(collectionGrid.indexPathsForSelectedItems()?.count)")
        
        if !thereAreSelectedPhotos() {
            currentBottomButtonState = BottomButtonState.NewCollection
        }
    }
    
    func collectionView(collectionView: UICollectionView, shouldHighlightItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        print("You asked whether \(indexPath.item) shold be higlighted")
        print(selectedPhotos)
        return true
    }
    
    func collectionView(collectionView: UICollectionView, didUnhighlightItemAtIndexPath indexPath: NSIndexPath) {
        print("Hey you unhighlighted something")
    }
    
    func collectionView(collectionView: UICollectionView, didHighlightItemAtIndexPath indexPath: NSIndexPath) {
        print("Hey you highlighted something")
    }
    
    func thereAreSelectedPhotos() -> Bool {
        for i in selectedPhotos {
            if i {
                return true
            }
        }
        return false
    }
}


extension PhotoAlbumViewController {

    func viewMangedObjectID(){
        let stuff = frc?.fetchedObjects as! [Photo]
        print("From the viewpoint of the frc")
        for (i,thing) in stuff.enumerate() {
            print("index: \(i) indexpath:\(frc?.indexPathForObject(thing)?.item) \n objid: \(thing.objectID) obj:\(thing.url) photopresent:\(thing.imageData != nil)")
        }
        print("From the viewpoint of the collectionview")
        for (i,thing) in (collectionGrid.visibleCells() as! [PhotoViewCell]).enumerate(){
            print("index: \(i) \(thing.url) objid: \(thing.coreDataObjectID) ")
        }
        print(collectionGrid)
        print("\n")
        if stuff.count == 21 {
            return
        }
    }
    
    
    func prt(file: String, line: Int, msg: String){
        for index in file.characters.indices {
            if file[index] == "/" && !file.substringFromIndex(index.successor()).containsString("/"){
                let filename = file.substringFromIndex(index.successor())
                print("\(filename) \(line) \(msg)")
            }
        }
        return
    }
}
