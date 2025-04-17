//
//  XPCClient.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 17/04/2025.
//

import Foundation

class XPCClient: ObservableObject {
    private let connection: NSXPCConnection

    init() {
        connection = NSXPCConnection(machServiceName: "com.maxprudhomme.sortadaemon", options: [])
        connection.remoteObjectInterface = NSXPCInterface(with: XPCProtocol.self)
        connection.resume()
    }

    deinit {
        connection.invalidate()
    }

    func process(prompt: String, _ completion: @escaping (String) -> Void) {
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in print("XPC error:", error) } as? XPCProtocol

        proxy?.process(prompt: prompt) { reply, err in
            if let r = reply {
                completion(r)
            } else {
                completion("❌ error: \(err!)")
            }
        }
    }
}
