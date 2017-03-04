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
    convenience init(image: UIImage!, url: URL, context: NSManagedObjectContext) {
        let ent = NSEntityDescription.entity(forEntityName: "Photo", in: context)
        self.init(entity: ent!, insertInto: context)
        self.url = url.absoluteString
        dataIsNil = true
    }
    
    func setImage(_ input: Data){
        imageData = input
        dataIsNil = false
    }
}
