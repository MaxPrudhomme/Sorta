//
//  DaemonClient.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 17/04/2025.
//


import Foundation

class DaemonClient: ObservableObject {
    private let connection: NSXPCConnection

    init() {
        connection = NSXPCConnection(machServiceName: "com.maxprudhomme.sortadaemon", options: [])
        connection.remoteObjectInterface = NSXPCInterface(with: XPCProtocol.self)
        connection.resume()
    }

    deinit {
        connection.invalidate()
    }

    func ping(withReply reply: @escaping (String) -> Void) {
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in print("XPC error:", error) } as? XPCProtocol

        proxy?.ping { result in
            reply(result)
        }
    }
    
    func generateResponse(prompt: String, withReply reply: @escaping (String?, Error?) -> Void) {
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            print("XPC error:", error)
            reply(nil, error)
        } as? XPCProtocol

        guard let daemonProxy = proxy else {
            reply(nil, NSError(domain: "com.maxprudhomme.sortadaemon.client", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not get XPC proxy."]))
            return
        }

        daemonProxy.generateResponse(prompt: prompt, withReply: reply)
    }

}
