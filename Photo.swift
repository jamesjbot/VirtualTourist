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
    convenience init(image: UIImage!, context: NSManagedObjectContext) {
        if let ent = NSEntityDescription.entityForName("Photo", inManagedObjectContext: context){
            self.init(entity: ent, insertIntoManagedObjectContext: context)
            //Is this really needed?
            if image != nil {
                self.imageData = UIImagePNGRepresentation(image)
            }

        } else {
            fatalError("Unable to find entity Photo")
        }

    }
}
