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
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var mapView: MKMapView!

    @IBOutlet weak var collectionGrid: UICollectionView!

    // MARK: - Variables
    
    var location: Pin!
    
    private var sizeOfCell: CGFloat!
    
    var fetchedResultsController : NSFetchedResultsController?
    
    // MARK: - Functions
    
    func testingDeleteAllPhotos() {
        //Slow one by one way
        let slowWAy = true
        if slowWAy {
            executeFetchResultsController()
            for photo in (fetchedResultsController?.fetchedObjects)! {
                let appDel = UIApplication.sharedApplication().delegate as! AppDelegate
                (appDel.stack?.context)!.deleteObject(photo as! Photo)
            }
            

        } else { // fast way delete everything EVEN THE PINS
            let appDel = UIApplication.sharedApplication().delegate as! AppDelegate
            (appDel.stack?.context)!.deletedObjects
        }

        
        
        
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Testing
        testingDeleteAllPhotos()
        
        // Zoom to a comfortable level
        let span = MKCoordinateSpanMake(3 , 3)
        let cll = CLLocationCoordinate2D(latitude: location.latitude as! Double, longitude: location.longitude as! Double)
        let region = MKCoordinateRegionMake(cll, span)
        mapView.setRegion(region, animated: true)
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2D(latitude: location.latitude as! Double, longitude: location.longitude as! Double)
        mapView.addAnnotation(annotation)
        
        setDeviceSpecificSizeOfCell()
        
        collectionGrid.dataSource = self
        
        executeFetchResultsController()
        
        // Set size of cells on the collectionview
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.itemSize = CGSize(width: sizeOfCell, height: sizeOfCell)
        flowLayout.minimumInteritemSpacing = minimumSpacing
        flowLayout.minimumLineSpacing = minimumSpacing
        collectionGrid.collectionViewLayout = flowLayout
        
        flickrClient.searchForPicturesByLatLonByPin(location){
            (success, error) -> Void in
            if success {
                print("completed latlon search")
            }
        }
    }
    
    func executeFetchResultsController(){
        print("initializeFetchResultsController Called")
        let request = NSFetchRequest(entityName: "Photo")
        request.sortDescriptors = [NSSortDescriptor(key: "pin", ascending: true)]
        let appDel = UIApplication.sharedApplication().delegate as! AppDelegate
        let moc = appDel.stack?.context
        fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: moc!, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController?.delegate = self
        do {
            try fetchedResultsController?.performFetch()
            print("Number of objects retrieved with fetch request \(fetchedResultsController?.fetchedObjects?.count)")
        } catch {
            fatalError("Failed to initialize FetchedResultsControler \(error)")
        }
        print("exiting initializefetchrequest")
    }
    
    
    func setDeviceSpecificSizeOfCell(){
        //print("The size of frame width is \(view.frame.width)")
        //print("The size of the bounds is \(view.bounds)")
        self.sizeOfCell = (view.frame.width - 2*minimumSpacing)/3
        //self.sizeOfCell = view.frame.width
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // TODO Temporarily marked the max number of images
        // This should return the size of the model
        // So a fetchrequest would work
        return (fetchedResultsController?.fetchedObjects?.count)!
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let photo = fetchedResultsController?.objectAtIndexPath(indexPath) as! Photo
        
        //print("Dequeuing a UICell and inserting Incoming indexPath \(indexPath)")
        let cell = collectionGrid.dequeueReusableCellWithReuseIdentifier(PHOTOALBUMCELLIDENTIFIER, forIndexPath: indexPath) as! PhotoViewCell
        
        if photo.imageData == nil {
            cell.activityIndic.hidden = false
            cell.activityIndic.startAnimating()
        } else {
            cell.activityIndic.hidden = true
            cell.activityIndic.stopAnimating()
            cell.imageView.image = UIImage(data: photo.imageData!)
        }
        


        return cell
    }

    // MARK: NSFetchedResultsControllerDelegate methods
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        print("controllerWillChangeContent called")
    }
    
    
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        print("controller did change section called")
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        print("Did change object called Old path:\(indexPath?.row) New path:\(newIndexPath?.row)! object: anObject")
        print("The type is: \(type.rawValue))")
        switch (type){
        case .Insert:
            print("this is an insert")
            collectionGrid.reloadData()
        case .Delete:
            print("this is a delete")
            collectionGrid.reloadData()
        case .Update:
            print("this is an update")
        case .Move:
            print("this is a move")
            collectionGrid.reloadData()
        }
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        print("Controller Did Change Content fired")
    }
    
}

extension PhotoAlbumViewController {
    

}
