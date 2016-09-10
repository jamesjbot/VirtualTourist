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
    
    // MARK: - Debug statements
    
    
    
    // MARK: - Constants
    
    let PHOTOALBUMCELLIDENTIFIER = "PVCell"
    private var sectionInsets = UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)
    private let minimumSpacing = CGFloat(10)
    // MARK: - IBOutlets
    
    @IBOutlet weak var mapView: MKMapView!

    @IBOutlet weak var collectionGrid: UICollectionView!

    // MARK: - Variables
    
    var location: MKAnnotation!
    private var sizeOfCell: CGFloat!
    
    // MARK: - Functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Zoom to a comfortable level
        let span = MKCoordinateSpanMake(3 , 3)
        let region = MKCoordinateRegionMake(location.coordinate , span)
        mapView.setRegion(region, animated: true)
        mapView.addAnnotation(location)
        
        setDeviceSpecificSizeOfCell()
        
        collectionGrid.dataSource = self
        
        // Set size of cells on the collectionview
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.itemSize = CGSize(width: sizeOfCell, height: sizeOfCell)
        flowLayout.minimumInteritemSpacing = minimumSpacing
        flowLayout.minimumLineSpacing = minimumSpacing
        collectionGrid.collectionViewLayout = flowLayout
        
    }
    
    
    func setDeviceSpecificSizeOfCell(){
        print("The size of frame width is \(view.frame.width)")
        print("The size of the bounds is \(view.bounds)")
        self.sizeOfCell = (view.frame.width - 2*minimumSpacing)/3
        //self.sizeOfCell = view.frame.width
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // TODO Temporarily marked the max number of images
        return 21
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        print("Dequeuing a UICell and inserting Incoming indexPath \(indexPath)")
        let cell = collectionGrid.dequeueReusableCellWithReuseIdentifier(PHOTOALBUMCELLIDENTIFIER, forIndexPath: indexPath) as! PhotoViewCell
        cell.imageView.image = nil
        cell.activityIndic.startAnimating()
        return cell
    }

}

