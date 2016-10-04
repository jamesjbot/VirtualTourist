//
//  Photo.swift
//  VirtualTourist
//
//  Created by James Jongsurasithiwat on 9/6/16.
//  Copyright © 2016 James Jongs. All rights reserved.
//

import Foundation
import CoreData
import UIKit

class Photo: NSManagedObject {

    // Insert code here to add functionality to your managed object subclass
    convenience init(image: UIImage!, url: NSURL, context: NSManagedObjectContext) {
        let ent = NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)
        self.init(entity: ent!, insertIntoManagedObjectContext: context)
        self.url = url.absoluteString
        dataIsNil = true
    }
    
    func setImage(input: NSData){
        imageData = input
        dataIsNil = false
    }
}
