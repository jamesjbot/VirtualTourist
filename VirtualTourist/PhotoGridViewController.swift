//
//  DetailViewController.swift
//  VirtualTourist
//
//  Created by James Jongsurasithiwat on 9/4/16.
//  Copyright © 2016 James Jongs. All rights reserved.
//

import Foundation
import UIKit
import MapKit

class PhotoGridViewController: UIViewController {
    
    // MARK: - IBOUTLET
    
    @IBOutlet weak var mapView: MKMapView!

    @IBOutlet weak var collectionGrid: UICollectionView!

    // MARK: - VARIABLES
    
    var location: MKAnnotation!
    
    // MARK: - FUNCTIONS
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Zoom to a comfortable level
        let span = MKCoordinateSpanMake(3 , 3)
        let region = MKCoordinateRegionMake(location.coordinate , span)
        mapView.setRegion(region, animated: true)
        mapView.addAnnotation(location)
        
    }
}