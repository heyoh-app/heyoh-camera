//
//  Main.swift
//  SimpleDALPlugin
//
//  Created by 池上涼平 on 2020/04/25.
//  Copyright © 2020 com.seanchas116. All rights reserved.
//

import CoreMediaIO
import Foundation

@_cdecl("HeyohPluginMain")
public func HeyohPluginMain(allocator _: CFAllocator, requestedTypeUUID _: CFUUID) -> CMIOHardwarePlugInRef {
    NSLog("HeyohPlugin")
    return pluginRef
}
