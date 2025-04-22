//
//  main.swift
//  SortaDaemon
//
//  Created by Max PRUDHOMME on 17/04/2025.
//

import Foundation
import os

class HelperDelegate: NSObject, NSXPCListenerDelegate, XPCProtocol {
    private let model = Model()
    private let logger = Logger(subsystem: "com.maxprudhomme.sortadaemon", category: "HelperDelegate")
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection conn: NSXPCConnection) -> Bool {
        conn.exportedInterface = NSXPCInterface(with: XPCProtocol.self)
        conn.exportedObject = self
        conn.resume()
        return true
    }

    func ping(withReply reply: @escaping (String) -> Void) {
        reply("Pong")
    }
    
    func generateResponseStreaming(prompt: String, clientEndpoint: NSXPCListenerEndpoint) {
        Task {
            await model.generateResponseStream(
                to: prompt,
                system: "You are a helpful assistant...",
                clientEndpoint: clientEndpoint,
                completionHandler: { error in
                    if let error = error {
                        self.logger.error("Generation failed: \(error.localizedDescription)")
                    } else {
                        self.logger.info("Generation completed successfully")
                    }
                }
            )
        }
    }
}

let listener = NSXPCListener(machServiceName: "com.maxprudhomme.sortadaemon")
let delegate = HelperDelegate()
listener.delegate = delegate
listener.resume()

print("Daemon entered main loop")

RunLoop.main.run()
