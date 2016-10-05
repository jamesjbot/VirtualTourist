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
    @IBOutlet weak var imageView: UIImageView?
    internal var coreDataObjectID : NSManagedObjectID!
    internal var url : String!
    internal var didUserSelect: Bool = false
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        let normalBackground = UIView()
        let selectedBackground = UIView()
        normalBackground.backgroundColor = UIColor.whiteColor()
        selectedBackground.backgroundColor = UIColor.whiteColor()
        backgroundView = normalBackground
        didUserSelect = false
    }
    
    override func prepareForReuse() {
        coreDataObjectID = nil
        url = nil
        didUserSelect = false
    }
}
