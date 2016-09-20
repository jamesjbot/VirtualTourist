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

class PhotoAlbumViewController: UIViewController, UICollectionViewDataSource, NSFetchedResultsControllerDelegate {
    
    // MARK: - Debug statements
    
    
    
    // MARK: - Constants
    
    let PHOTOALBUMCELLIDENTIFIER = "PVCell"
    private var sectionInsets = UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)
    private let minimumSpacing = CGFloat(10)
    private let flickrClient = FlickrClient.sharedInstance()
    private let maximumImages = 21
    // MARK: - IBOutlets
    
    @IBOutlet weak var mapView: MKMapView!

    @IBOutlet weak var collectionGrid: UICollectionView!

    // MARK: - Variables
    
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
                        print("\(#function) \(#line)The populating of CoreData succeded \(success)")
                    }
                    //self.collectionGrid.reloadData()
                    //print(self.flickrClient.photoSearchResultsArray)
                }
            }
        }
    }
    
    func initializeFlowLayout() {

        flowLayout!.itemSize = CGSize(width: sizeOfCell, height: sizeOfCell)
        flowLayout!.minimumInteritemSpacing = minimumSpacing
        flowLayout!.minimumLineSpacing = minimumSpacing
        collectionGrid.collectionViewLayout = flowLayout!
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
            print("\(#function) \(#line)Number of objects retrieved with fetch request \(frc?.fetchedObjects?.count)")
        } catch {
            fatalError("Failed to initialize FetchedResultsControler \(error)")
        }
        print("\(#function) \(#line)exiting initializefetchrequest")
    }
    
    
    func setDeviceSpecificSizeOfCell(){
        self.sizeOfCell = (view.frame.width - 2*minimumSpacing)/3
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
        print("\(#function) \(#line)******cellForItemAtIndexPathCalled location:\(indexPath.item)")
        let managedPhoto = frc?.objectAtIndexPath(indexPath) as! Photo
        
        //print("\(#function) \(#line)Dequeuing a UICell and inserting Incoming indexPath \(indexPath)")
        let cell = collectionGrid.dequeueReusableCellWithReuseIdentifier(PHOTOALBUMCELLIDENTIFIER, forIndexPath: indexPath) as! PhotoViewCell
        
        if managedPhoto.imageData == nil {
            cell.activityIndic.hidden = false
            cell.activityIndic.startAnimating()
            dispatch_async(dispatch_get_main_queue()){
                () -> Void in
                self.flickrClient.downloadImage(NSURL(string: managedPhoto.url!)!, forPin: self.location!, updateMangedObjectID: managedPhoto.objectID)
            }
            print("\(#function) \(#line)\(#function) \(#line) Returning a Nil Cell")
        } else {
            cell.activityIndic.hidden = true
            cell.activityIndic.stopAnimating()
            cell.imageView.image = UIImage(data: managedPhoto.imageData!)
            print("\(#function) \(#line)Returning a Image Populated Cell")
        }
        
        return cell
    }

    // MARK: NSFetchedResultsControllerDelegate methods
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        print("\(#function) \(#line)controllerWillChangeContent called")
    }
    
    
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        //print("\(#function) \(#line)controller did change section called")
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        print("\(#function) \(#line)-----------------------------------------------------")
        print("\(#function) \(#line)CoreData changed detected")
        print("\(#function) \(#line)Did change object called Old index:\(indexPath?.item)")
        print("\(#function) \(#line)Chaging CollectionView Cell at New index:\((newIndexPath?.item))")
        print("\(#function) \(#line)\(anObject.dynamicType) object: \(anObject)")
        print("\(#function) \(#line)The type is: \(type)")
        
        guard (newIndexPath?.item <= maximumImages && indexPath?.item <= maximumImages) else {
            print("Guard statment blocked didChangeObject")
            return
        }
        
        switch (type){
        case .Insert:
            print("\(#function) \(#line)Initial Loading")
            //collectionGrid.reloadItemsAtIndexPaths([newIndexPath!])
            //collectionGrid.reloadData()
            
            //collectionGrid.insertItemsAtIndexPaths([newIndexPath!])
            //let update = collectionGrid.insertItemsAtIndexPaths([newIndexPath])
            if frc?.fetchedObjects?.count != self.flickrClient.photoSearchResultsArray.count {
                return
            }
            prt(#file, line: #line, msg: "You should update the view controller now")
        case .Delete:
            //fatalError("Delete is not currently acceptable")
            print("\(#function) \(#line)this is a delete")
            collectionGrid.deleteItemsAtIndexPaths([indexPath!])
        case .Update:
            //fatalError("Update is not curretnly acceptable")
            print("\(#function) \(#line)this is an update")
            collectionGrid.reloadItemsAtIndexPaths([indexPath!])
        case .Move:
            fatalError("Should never occur")
            print("\(#function) \(#line)this is a move")
            if indexPath != newIndexPath {
                print("\(#function) \(#line)Why are these different \(indexPath?.item) \(newIndexPath?.item)")
            }
            let cell = collectionGrid.cellForItemAtIndexPath(newIndexPath!) as! PhotoViewCell
            if cell.imageView.image != nil {
                print("\(#function) \(#line)Here is the problem <----------------- This image is already populated")
            }
            //collectionGrid.reloadItemsAtIndexPaths([indexPath!])
            //collectionGrid.deleteItemsAtIndexPaths([indexPath!])
            //collectionGrid.insertItemsAtIndexPaths([newIndexPath!])
            print("\(#function) \(#line)This many Photo objects in coredata:\((frc?.fetchedObjects?.count)!)")
            for photo in (frc?.fetchedObjects)! {
                print(photo)
            }
            //collectionGrid.reloadData()
        }
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        //print("\(#function) \(#line)Controller Did Change Content fired")
        collectionGrid.reloadData()
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
