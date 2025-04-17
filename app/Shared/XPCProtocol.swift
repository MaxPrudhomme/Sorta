//
//  XPCProtocol.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 17/04/2025.
//

import Foundation

@objc public protocol XPCProtocol {

  func process(prompt: String, withReply reply: @escaping (String?, Error?) -> Void)
}
