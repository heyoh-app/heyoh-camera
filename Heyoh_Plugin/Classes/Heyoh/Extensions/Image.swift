//
//  Image.swift
//  HeyohPlugin
//
//  Created by Markiyan Kostiv on 09.10.2021.
//  Copyright © 2021 com.heyoh. All rights reserved.
//

import CoreImage
import Foundation

extension NSObject {
    func loadImage(image_name: String) -> CIImage {
        let bundle = Bundle(for: type(of: self))
        guard let rotatedImage = bundle.image(forResource: image_name), let data = rotatedImage.tiffRepresentation, let ciImage = CIImage(data: data) else {
            assertionFailure()
            return CIImage()
        }

        return ciImage
    }
}
