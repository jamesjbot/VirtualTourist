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

class MainMapViewController: UIViewController, MKMapViewDelegate {

    // MARK: Constants
    let centerCoord = CLLocationCoordinate2D(latitude: 39.5, longitude: -98.35)
    
    let tapPinsLabelHeight: CGFloat = 50
    
    // MARK: Variables
    
    var editingEnabled : Bool = false
    
    var floatingAnnotation: MKAnnotation!
    
    var zoomToAnnotation: MKAnnotation!
    
    // MARK: IBOutlets
    @IBOutlet weak var tapPinsHeight: NSLayoutConstraint!
    
    @IBOutlet var longPressRecognizer: UILongPressGestureRecognizer!
    
    @IBOutlet weak var editButton: UIBarButtonItem!

    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var tapPinsToDeleteLabel: UILabel!
    
    
    // MARK: IBActions
    
    @IBAction func editButtonPressed(sender: UIBarButtonItem) {
        if editingEnabled {
            editingEnabled = false
            // Remove Tap Pins label from view
            UIView.animateWithDuration(1.0, delay: 0.0, options: [], animations: {
                self.tapPinsHeight.constant = 0
                self.view.layoutIfNeeded()
                }, completion: nil)
        } else {
            editingEnabled = true
            // Show Tap Pins label in view
            UIView.animateWithDuration(1.0, delay: 0.0, options: [], animations: {
                        self.tapPinsHeight.constant = self.tapPinsLabelHeight
                self.view.layoutIfNeeded()
                }, completion: nil)
        }
    }
    
    @IBAction func handleLongPress(sender: UILongPressGestureRecognizer) {
        mapView.removeGestureRecognizer(sender)        
        // Always set a pin down
        // when the pin state is changed delete old pin and replace with new pin
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
            
            // Create coredata pin
            let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
            // Create a pin in the managed objectcontext
            Pin(input: floatingAnnotation, context: (appDelegate.stack?.context)!)
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
        mapView.addAnnotations(loadCoreData())
    }
    
    func save() {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        let stack = appDelegate.stack
        do {
            try stack?.saveContext()
        } catch {
            print("Error saving points")
        }
    }
    
    
    // Function to call ManagedObjectContext and fetch stored objects
    func loadCoreData() -> [MKAnnotation] {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        let moc = appDelegate.stack?.context
        let pinFetch = NSFetchRequest(entityName: "Pin")
        do {
            let fetchedPins = try moc!.executeFetchRequest(pinFetch) as! [Pin]
            var annotations : [MKAnnotation] = []
            for pin in fetchedPins {
                let annotation = MKPointAnnotation()
                annotation.coordinate = CLLocationCoordinate2D(latitude: pin.latitude as! Double, longitude: pin.longitude as! Double)
                annotations.append(annotation)
            }
            return annotations
        } catch {
            fatalError("Failed to fetch pins: \(error)")
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.destinationViewController is PhotoGridViewController {
            let pgvc = segue.destinationViewController as! PhotoGridViewController
            pgvc.location = zoomToAnnotation
        }
    }
    
    // MARK: - MKMapViewDelegate functions
    
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        // Save the annotation for injection into the target segue
        zoomToAnnotation = view.annotation
        performSegueWithIdentifier("transistionToPhotoGrid", sender: self)
    }

    
    
}

