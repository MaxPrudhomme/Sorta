//
//  main.swift
//  SortaDaemon
//
//  Created by Max PRUDHOMME on 17/04/2025.
//

import Foundation

class HelperDelegate: NSObject, NSXPCListenerDelegate, XPCProtocol {
    private let model = Model()
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection conn: NSXPCConnection) -> Bool {
        conn.exportedInterface = NSXPCInterface(with: XPCProtocol.self)
        conn.exportedObject = self
        conn.resume()
        return true
    }

    func ping(withReply reply: @escaping (String) -> Void) {
        reply("Pong")
    }
    
    func generateResponse(prompt: String, withReply reply: @escaping (String?, Error?) -> Void) {
        Task {
            do {
                let response = try await model.generateResponse(to: prompt, system: "You are a helpful assistant that answer truthfully and accurately to user queries.")
                reply(response, nil)
            } catch {
                reply(nil, error)
            }
        }
    }
}

let listener = NSXPCListener(machServiceName: "com.maxprudhomme.sortadaemon")
let delegate = HelperDelegate()
listener.delegate = delegate
listener.resume()

print("Daemon entered main loop")

RunLoop.main.run()
