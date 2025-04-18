//
//  XPCProtocol.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 17/04/2025.
//

import Foundation

@objc public protocol XPCProtocol {

    func ping(withReply reply: @escaping (String) -> Void)
    func generateResponse(prompt: String, withReply reply: @escaping (String?, Error?) -> Void)
    func generateResponseStreaming(prompt: String, clientEndpoint: NSXPCListenerEndpoint)
}

@objc public protocol ClientProtocol {
    func receiveChunk(_ chunk: String)
    func receiveCompletion(errorData: Data?)
}
