//
//  PhotoViewCell.swift
//  VirtualTourist
//
//  Created by James Jongsurasithiwat on 9/9/16.
//  Copyright © 2016 James Jongs. All rights reserved.
//

import UIKit
import CoreData

class PhotoViewCell: UICollectionViewCell {
    
    @IBOutlet weak var activityIndic: UIActivityIndicatorView!
    @IBOutlet weak var imageView: UIImageView!
    var coreDataObjectID : NSManagedObjectID!
    var url : String!
    override var selected: Bool {
        didSet{
            //print("Someone assigned a value to me a photo View cell of \(selected) with and old value of: \(oldValue)")
            
            imageView.alpha = selected ? 0.5 : 1.0
            //print("Alpha is now \(imageView.alpha)")
        }
        
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        let normalBackground = UIView()
        let selectedBackground = UIView()
        normalBackground.backgroundColor = UIColor.blueColor()
        selectedBackground.backgroundColor = UIColor.whiteColor()
        backgroundView = normalBackground
        selectedBackgroundView = selectedBackground
    }

}
