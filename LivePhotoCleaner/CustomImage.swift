//
//  CustomImage.swift
//  LivePhotosCleanUp
//
//  Created by Marco Schillinger on 12.01.21.
//

import UIKit

struct CustomImage: Hashable, Identifiable {

    let id: String

    var image: UIImage
    var selected = false
    
    var overlayTransparency: Double {
        if selected {
            return Constants.partTransparent
        } else {
            return Constants.transparent
        }
    }
}
