//
//  Utilities.swift
//  Compound
//
//  Created by Andrew Coyle on 10/9/24.
//

import Foundation
#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#else
import AppKit
public typealias PlatformImage = NSImage
#endif
