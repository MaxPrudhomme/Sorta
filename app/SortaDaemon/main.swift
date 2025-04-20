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
        let clientConnection = NSXPCConnection(listenerEndpoint: clientEndpoint)
        clientConnection.remoteObjectInterface = NSXPCInterface(with: ClientProtocol.self)
        clientConnection.invalidationHandler = { [weak clientConnection] in clientConnection?.invalidate() }
        clientConnection.interruptionHandler = { [weak clientConnection] in clientConnection?.invalidate() }
        clientConnection.resume()
        
        guard let clientProxy = clientConnection.remoteObjectProxyWithErrorHandler({ error in
                self.logger.error("Main : Error getting client proxy: \(error.localizedDescription)")
                clientConnection.invalidate()
            }) as? ClientProtocol
        else {
            logger.error("Main : Failed to create client proxy.")
            clientConnection.invalidate()
            return
        }
        Task {
            logger.info("Main : Starting model generation task...")
            await model.generateResponseStream(to: prompt, system: "You are a helpful assistant that answers truthfully and accurately to user queries.", chunkHandler: { chunk in clientProxy.receiveChunk(chunk) },
                completionHandler: { error in
                    var errorData: Data? = nil
                    if let error = error {
                        self.logger.error("Main : Stream generation failed: \(error.localizedDescription)")
                        do {
                            let nsError = error as NSError
                            errorData = try NSKeyedArchiver.archivedData(withRootObject: nsError, requiringSecureCoding: false)
                            self.logger.info("Main : Archived error for sending.")
                        } catch {
                            self.logger.error("Main : Failed to archive error: \(error.localizedDescription)")
                            let genericError = NSError(domain: "DaemonError", code: -99, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize original error"])
                             errorData = try? NSKeyedArchiver.archivedData(withRootObject: genericError, requiringSecureCoding: false)
                        }
                    } else {
                        self.logger.info("Main : Stream generation successful. Sending completion.")
                    }
                    clientProxy.receiveCompletion(errorData: errorData)
                    self.logger.info("Main : Invalidating connection back to client.")
                    clientConnection.invalidate()
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
