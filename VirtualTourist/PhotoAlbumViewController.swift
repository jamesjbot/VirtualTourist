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
    // MARK: - IBOutlets
    
    @IBOutlet weak var bottomButton: UIButton!
    
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var collectionGrid: UICollectionView!
    
    // MARK: - IBActions
    
    @IBAction func tapDetected(sender: UITapGestureRecognizer) {
        prt(#file, line: #line, msg: "\(sender.state)")
    }
    @IBAction func bottomButtonPressed(sender: AnyObject) {
        switch(currentBottomButtonState) {
        case BottomButtonState.Delete:
            let indexpaths = collectionGrid.indexPathsForSelectedItems()
            //            for index in indexpaths {
            //                print(collectionGrid.cellForItemAtIndexPath(index).ishightlite)
            //            }
            let context  = (UIApplication.sharedApplication().delegate as! AppDelegate).stack?.context
            prt(#file, line: #line, msg: "perform block next")
            context?.performBlockAndWait(){
                for (index,b) in self.selectedPhotos.enumerate() {
                    if b {
                        self.prt(#file, line: #line, msg: "attempting to delete entry at index: \(index)")
                        //let junk = self.collectionGrid.cellForItemAtIndexPath(index)
                        do {
                            self.prt(#file, line: #line, msg: "Collectiongrid before deletion \(self.collectionGrid.numberOfItemsInSection(0))")
                            self.prt(#file, line: #line, msg: "next get cell")
                            //let cell = (self.collectionGrid.cellForItemAtIndexPath(index) as! PhotoViewCell)
                            self.prt(#file, line: #line, msg: "get object id")
                            //let objectID = cell.coreDataObjectID
                            self.prt(#file, line: #line, msg: "deleting object next")
                            let indexPath = NSIndexPath(forItem: index, inSection: 0)
                            let deletableObject = self.frc?.objectAtIndexPath(indexPath)
                            context?.deleteObject(deletableObject! as! NSManagedObject)
                            self.prt(#file, line: #line, msg: "deleted object savingcontext")
                            try context?.save()
                            self.selectedPhotos[index] = false
                            self.prt(#file, line: #line, msg: "Context saved")
                            self.prt(#file, line: #line, msg: "now change did occur will fire and delete the object causing a rift in viewcontroller order")
                        } catch let error {
                            context?.undo()
                            fatalError("Error saving context \(error)")
                        }
                    }
                }
                print("Deleting these paths \(indexpaths)")
            }
        case BottomButtonState.NewCollection:
            print("fetch new items now")
        }
    }
    
    
    
    // MARK: - Variables
    
    var selectedPhotos = [Bool](count: 21, repeatedValue: false)
    
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
            }
        }
    }
    
    var location: Pin!
    
    var frc : NSFetchedResultsController?
    
    private var sizeOfCell: CGFloat!
    
    private var flowLayout : UICollectionViewFlowLayout?
    
    // MARK: - Functions
    
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
        frc?.delegate = self
        collectionGrid.dataSource = self
        collectionGrid.delegate = self
        collectionGrid.allowsMultipleSelection = true
        collectionGrid.allowsSelection = true
        
        if frc?.fetchedObjects?.count < 1 {
            flickrClient.searchForPicturesByLatLonByPin(location){
                (success, error) -> Void in
                if success {
                    self.prt(#file, line: #line, msg: "------------------")
                    print("completed latlon search")
                    print("There are now \((self.frc?.fetchedObjects?.count)!) frc results" )
                    self.prt(#file, line: #line, msg: "But there are \(self.flickrClient.photoSearchResultsArray.count) photoSearchResults")
                    self.flickrClient.populateCoreDataWithSearchResults(){
                        (success, error) -> Void in
                        self.prt(#file, line: #line, msg: "The populating of CoreData succeded \(success)")
                    }
                    //self.collectionGrid.reloadData()
                }
            }
        }
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
        if (frc?.fetchedObjects?.count)! > maximumImages {
            return maximumImages
        }
        return (frc?.fetchedObjects?.count)!
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        // Get a cell from the storyboard up to maximum allowed storyboard cell
        
        // Get data from model and populate it into dequeued storyboard cell
        
        // The storyboard cell knows whether it is selected or not.
        
        prt(#file, line: #line, msg: "******cellForItemAtIndexPathCalled location:\(indexPath.item)")
        let coreDataPhoto = frc?.objectAtIndexPath(indexPath) as! Photo
        
        // We are dequeuing up to a maximum of 21 cell form the story board

        //prt(#file, line: #line, msg: "Dequeuing a UICell and inserting Incoming indexPath \(indexPath)")
        let cell = collectionGrid.dequeueReusableCellWithReuseIdentifier(PHOTOALBUMCELLIDENTIFIER, forIndexPath: indexPath) as! PhotoViewCell
        
        cell.coreDataObjectID = coreDataPhoto.objectID
        switch (cell.imageView.image){
        case nil:
            print("photo is nill")
        case _ :
            print("it's not nil")
        }
        if coreDataPhoto.imageData == nil {
            cell.activityIndic.hidden = false
            cell.activityIndic.startAnimating()
            dispatch_async(dispatch_get_main_queue()){
                () -> Void in
                self.flickrClient.downloadImage(NSURL(string: coreDataPhoto.url!)!, forPin: self.location!, updateMangedObjectID: coreDataPhoto.objectID)
            }
            prt(#file, line: #line, msg: "\(#function) \(#line) Returning a Nil Cell")
        } else {
            cell.activityIndic.hidden = true
            cell.activityIndic.stopAnimating()
            cell.imageView.image = UIImage(data: coreDataPhoto.imageData!)
            switch (selectedPhotos[indexPath.item]) {
            case true:
                cell.selected = true
            case false:
                cell.selected = false
            }
            prt(#file, line: #line, msg: "Returning a Image Populated Cell")
        }
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
        prt(#file, line: #line, msg: "The change type is: \(type.rawValue)")
        
        print(NSFetchedResultsChangeType.Insert.rawValue)
        print(NSFetchedResultsChangeType.Delete.rawValue)
        print(NSFetchedResultsChangeType.Move.rawValue)
        print(NSFetchedResultsChangeType.Update.rawValue)
        
        self.prt(#file, line: #line, msg: "Collectiongrid before deletion \(self.collectionGrid.numberOfItemsInSection(0))")
        
        guard (newIndexPath?.item <= maximumImages && indexPath?.item <= maximumImages) else {
            print("Guard statment blocked didChangeObject")
            return
        }
        self.prt(#file, line: #line, msg: "Collectiongrid before deletion \(self.collectionGrid.numberOfItemsInSection(0))")
        switch (type){
        case .Insert:
            prt(#file, line: #line, msg: "Initial Loading")
            //collectionGrid.reloadItemsAtIndexPaths([newIndexPath!])
            //collectionGrid.reloadData()
            
            //collectionGrid.insertItemsAtIndexPaths([newIndexPath!])
            //let update = collectionGrid.insertItemsAtIndexPaths([newIndexPath])
            if frc?.fetchedObjects?.count != self.flickrClient.photoSearchResultsArray.count {
                return
            }
            prt(#file, line: #line, msg: "You should update the view controller now")
        case .Delete:
            self.prt(#file, line: #line, msg: "Collectiongrid before deletion \(self.collectionGrid.numberOfItemsInSection(0))")
            //fatalError("Delete is not currently acceptable")
            prt(#file, line: #line, msg: "this is a delete")
        //collectionGrid.deleteItemsAtIndexPaths([indexPath!])
        case .Move:
            fatalError("Should never occur")
            prt(#file, line: #line, msg: "this is a move")
            if indexPath != newIndexPath {
                prt(#file, line: #line, msg: "Why are these different \(indexPath?.item) \(newIndexPath?.item)")
            }
            let cell = collectionGrid.cellForItemAtIndexPath(newIndexPath!) as! PhotoViewCell
            if cell.imageView.image != nil {
                prt(#file, line: #line, msg: "Here is the problem <----------------- This image is already populated")
            }
            //collectionGrid.reloadItemsAtIndexPaths([indexPath!])
            //collectionGrid.deleteItemsAtIndexPaths([indexPath!])
            //collectionGrid.insertItemsAtIndexPaths([newIndexPath!])
            prt(#file, line: #line, msg: "This many Photo objects in coredata:\((frc?.fetchedObjects?.count)!)")
            for photo in (frc?.fetchedObjects)! {
                print(photo)
            }
        //collectionGrid.reloadData()
        case .Update:
            //fatalError("Update is not curretnly acceptable")
            prt(#file, line: #line, msg: "this is an update")
            //collectionGrid.reloadItemsAtIndexPaths([indexPath!])
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        //prt(#file, line: #line, msg: "Controller Did Change Content fired")
        collectionGrid.reloadData()
    }
    
}


// MARK: UICollectionViewDelegate
extension PhotoAlbumViewController: UICollectionViewDelegate {
    
    func collectionView(collectionView: UICollectionView, shouldSelectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        print("Should select item called")
        return true
    }
    
    func collectionView(collectionView: UICollectionView, shouldDeselectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        print("Should ")
        return true
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        print("You selected item at indexpath \(indexPath.item)")
        selectedPhotos[indexPath.item] = true
        let cell = collectionGrid.cellForItemAtIndexPath(indexPath) as! PhotoViewCell
        //cell.imageView.alpha = 0.50
        print("Collectionview selection has this many selected now: \(collectionGrid.indexPathsForSelectedItems()!.count)")
        if currentBottomButtonState != BottomButtonState.Delete {
            currentBottomButtonState = BottomButtonState.Delete
        }
    }
    
    func collectionView(collectionView: UICollectionView, didDeselectItemAtIndexPath indexPath: NSIndexPath) {
        print("You deselected item at indexpath \(indexPath.item)")
        selectedPhotos[indexPath.item] = false
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
    
    func prt(file: String, line: Int, msg: String){
        for index in file.characters.indices {
            if file[index] == "/" && !file.substringFromIndex(index.successor()).containsString("/"){
                let filename = file.substringFromIndex(index.successor())
                print("\(filename) \(line) \(msg)")
            }
        }
    }
}
