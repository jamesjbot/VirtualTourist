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

class PhotoAlbumViewController: UIViewController, UICollectionViewDataSource {
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var mapView: MKMapView!

    @IBOutlet weak var collectionGrid: UICollectionView!

    // MARK: - Variables
    
    var location: MKAnnotation!
    
    // MARK: - Functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Zoom to a comfortable level
        let span = MKCoordinateSpanMake(3 , 3)
        let region = MKCoordinateRegionMake(location.coordinate , span)
        mapView.setRegion(region, animated: true)
        mapView.addAnnotation(location)
        collectionGrid.dataSource = self
        
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionGrid.dequeueReusableCellWithReuseIdentifier("Cell", forIndexPath: indexPath)
        return cell
    }
    
}