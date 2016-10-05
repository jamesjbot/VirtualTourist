//
//  ViewController.swift
//  VirtualTourist
//
//  Created by James Jongsurasithiwat on 8/22/16.
//  Copyright © 2016 James Jongs. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class MainMapViewController: UIViewController, MKMapViewDelegate, NSFetchedResultsControllerDelegate {
    
    // MARK: Constants
    private let centerCoord = CLLocationCoordinate2D(latitude: 39.5, longitude: -98.35)
    
    private let tapPinsLabelHeight: CGFloat = 50
    
    // MARK: Variables
    var editingEnabled : Bool = false
    
    var floatingAnnotation: MKAnnotation!
    
    let coreDataStack = (UIApplication.sharedApplication().delegate as! AppDelegate).stack
    
    var fetchedResultsController: NSFetchedResultsController!
    
    var userSelectedPin: Pin!
    
    // MARK: IBOutlets
    @IBOutlet weak var prefetchSwitch: UISwitch!
    
    @IBOutlet weak var tapPinsHeight: NSLayoutConstraint!
    
    @IBOutlet var longPressRecognizer: UILongPressGestureRecognizer!
    
    @IBOutlet weak var editButton: UIBarButtonItem!
    
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var tapPinsToDeleteLabel: UILabel!
    
    // MARK: IBActions
    @IBAction func editButtonPressed(sender: UIBarButtonItem) {
        // Animate bottom Delete label by changing NSLayoutConstraint
        switch editingEnabled {
        case true:
            editingEnabled = false
            // Remove Tap Pins label from view
            UIView.animateWithDuration(0.3, delay: 0.0, options: [], animations: {
                self.tapPinsHeight.constant = 0
                self.view.layoutIfNeeded()
                }, completion: nil)
        case false:
            editingEnabled = true
            // Show Tap Pins label in view
            UIView.animateWithDuration(0.3, delay: 0.0, options: [], animations: {
                self.tapPinsHeight.constant = self.tapPinsLabelHeight
                self.view.layoutIfNeeded()
                }, completion: nil)
        }
    }
    
    @IBAction func handleLongPress(sender: UILongPressGestureRecognizer) {
        // Remove gesture recognizer for redundant calls to long press
        mapView.removeGestureRecognizer(sender)
        // Always set a pin down when user presses down
        // When the pin state is changed delete old pin and replace with new pin
        // When user release drop the pin and save it to the database
        switch sender.state {
        case UIGestureRecognizerState.Began:
            // Set floating annotation
            let coordinateOnMap = mapView.convertPoint(sender.locationInView(mapView), toCoordinateFromView: mapView)
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinateOnMap
            mapView.addAnnotation(annotation)
            floatingAnnotation = annotation
            
        case UIGestureRecognizerState.Changed:
            // Move floating annotation
            mapView.removeAnnotation(floatingAnnotation)
            let coordinateOnMap = mapView.convertPoint(sender.locationInView(mapView), toCoordinateFromView: mapView)
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinateOnMap
            mapView.addAnnotation(annotation)
            floatingAnnotation = annotation
            
        case UIGestureRecognizerState.Ended:
            insertPinIntoCoreData()
            // Clear out floating annotation
            floatingAnnotation = nil
            
        default:
            break
        }
        // Reenable gesture recognizer
        mapView.addGestureRecognizer(sender)
    }
    
    // MARK: Functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let request = NSFetchRequest(entityName: "Pin")
        request.sortDescriptors = []
        fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: (coreDataStack?.mainContext)!, sectionNameKeyPath: nil, cacheName: nil)
        do {
            try fetchedResultsController.performFetch()
        } catch {
            fatalError()
        }
        fetchedResultsController.delegate = self
        
        // Zoom to a comfortable level
        let span = MKCoordinateSpanMake(63 , 63)
        let region = MKCoordinateRegion(center: centerCoord , span: span)
        mapView.setRegion(region, animated: true)
        mapView.addGestureRecognizer(longPressRecognizer)
        mapView.delegate = self
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        // Remove annotation from snapshot view
        mapView.removeAnnotations(mapView.annotations)
        mapView.setNeedsDisplay()
        
        // Add persistent Pins
        let annotations = loadCoreData()
        mapView.addAnnotations(annotations)
        
        // This is to make sure when user returns from the PhotoAlbum, the top will say Virtual Tourist
        navigationController?.navigationBar.topItem?.title = "Virtual Tourist"
    }
    
    // Function to call ManagedObjectContext and fetch stored objects
    func loadCoreData() -> [MKAnnotation] {
        var annotations : [MKAnnotation] = []
        populateFRCandFetch()
        for pin in (fetchedResultsController.fetchedObjects! as! [Pin]) {
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: pin.latitude as! Double, longitude: pin.longitude as! Double)
            annotations.append(annotation)
        }
        return annotations
    }
    
    // Populate fetchresultscontroller and perform fetch
    func populateFRCandFetch() {
        coreDataStack?.mainContext.performBlockAndWait(){
            let request = NSFetchRequest(entityName: "Pin")
            request.sortDescriptors = []
            self.fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: (self.coreDataStack?.mainContext)!, sectionNameKeyPath: nil, cacheName: nil)
            do {
                try self.fetchedResultsController.performFetch()
            } catch {
                self.displayAlertWindow("Map View", msg: "Error retrieving pins\nPlease try again", actions: nil)
            }
        }
    }
    
    func deletePinInCoreData(at location: CLLocationCoordinate2D){
        let request = NSFetchRequest(entityName: "Pin")
        request.sortDescriptors = []
        let backgroundFetchResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: (coreDataStack?.backgroundContext)!, sectionNameKeyPath: nil, cacheName: nil)
        do {
            try backgroundFetchResultsController.performFetch()
        } catch {
            displayAlertWindow("Map View", msg: "Error accesing pin\nPlease try again", actions: nil)
        }
        for pin in fetchedResultsController.fetchedObjects! as! [Pin] {
            if pin.latitude == location.latitude && pin.longitude == location.longitude {
                backgroundFetchResultsController.managedObjectContext.performBlockAndWait(){
                    let bgPin = backgroundFetchResultsController.managedObjectContext.objectWithID(pin.objectID)
                    backgroundFetchResultsController.managedObjectContext.deleteObject(bgPin)
                    self.coreDataStack?.saveToFile()
                }
            }
        }
    }
    
    func insertPinIntoCoreData(){
        // Create coredata pin and immediately save
        coreDataStack?.backgroundContext.performBlockAndWait(){
            let newPin = Pin(input: self.floatingAnnotation, context: (self.coreDataStack?.backgroundContext)!)
            // Save pin in core data
            self.coreDataStack?.saveToFile()
            if self.prefetchSwitch.on {
                FlickrClient.sharedInstance().prefetchImages(newPin)
            }
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.destinationViewController is PhotoAlbumViewController {
            let destinationVC = segue.destinationViewController as! PhotoAlbumViewController
            destinationVC.location = userSelectedPin
            // When in the PhotoAlbumView controller the back button should say OK
            navigationController?.navigationBar.topItem?.title = "OK"
        }
    }
    
    // MARK: - MKMapViewDelegate functions
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        switch editingEnabled {
        case true:
            // Remove pin from core data
            deletePinInCoreData(at: (view.annotation?.coordinate)!)
            // Remove the pin from mapview
            mapView.removeAnnotation(view.annotation!)
        case false:
            // Locate the pin that matches the annotation view selected and segue to it
            var localpin : Pin?
            do {
                try fetchedResultsController.performFetch()
            } catch {
                displayAlertWindow("Map View", msg: "Error accesing pin\nPlease try again", actions: nil)
            }
            if let pinArray : [Pin] = (fetchedResultsController.fetchedObjects as! [Pin]) {
                for pin in pinArray {
                    if pin.latitude == view.annotation?.coordinate.latitude && pin.longitude == view.annotation?.coordinate.longitude {
                        localpin = pin
                        break
                    }
                }
            }
            if localpin != nil {
                userSelectedPin  = localpin
                performSegueWithIdentifier("transistionToPhotoGrid", sender: self)
            }
        }
    }
}

extension MainMapViewController {
    
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


