//
//  ViewController.swift
//  VirtualTourist
//
//  Created by James Jongsurasithiwat on 8/22/16.
//  Copyright © 2016 James Jongs. All rights reserved.
//

import UIKit
import MapKit

class MainMapViewController: UIViewController {

    // MARK: Constants
    let centerCoord = CLLocationCoordinate2D(latitude: 39.5, longitude: -98.35)
    
    // MARK: Variables
    
    var editingEnabled : Bool = false
    var floatingAnnotation: MKAnnotation!
    
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
                        self.tapPinsHeight.constant = 50
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
            // Clear out floating annotation
            floatingAnnotation = nil
        default:
            break
        }
        mapView.addGestureRecognizer(sender)
    }
    
    func showAllAnnotations(){
        print(mapView.annotations)
    }
    

    
    // MARK: Functions
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Zoom to a comfortable level
        let span = MKCoordinateSpanMake(63 , 63)
        let region = MKCoordinateRegion(center: centerCoord , span: span)
        mapView.setRegion(region, animated: true)
        
        mapView.addGestureRecognizer(longPressRecognizer)
    }
    

    
    
}

