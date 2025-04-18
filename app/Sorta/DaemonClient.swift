//
//  DaemonClient.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 17/04/2025.
//

import Foundation

class DaemonClient: ObservableObject {
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case error(Swift.Error)
    }

    @Published var connectionState: ConnectionState = .disconnected
    
    private var connection: NSXPCConnection?
    private let serviceName = "com.maxprudhomme.sortadaemon"

    private var activeListener: NSXPCListener?
    private var activeListenerDelegate: ClientListenerDelegate?
    
    init() {}

    func connect() {
        connectionState = .connecting
        connection = NSXPCConnection(machServiceName: serviceName, options: [])
        connection?.remoteObjectInterface = NSXPCInterface(with: XPCProtocol.self)
        connection?.resume()
        connectionState = .connected
    }
    
    func disconnect() {
        connection?.invalidate()
        connection = nil
        connectionState = .disconnected
        
        activeListener?.invalidate()
        activeListener = nil
        activeListenerDelegate = nil
    }
    
    func ping(withReply reply: @escaping (String) -> Void) {
        let proxy = connection?.remoteObjectProxyWithErrorHandler { error in print("XPC error:", error) } as? XPCProtocol

        proxy?.ping { result in
            reply(result)
        }
    }
    
    func generateResponse(prompt: String, withReply reply: @escaping (String?, Error?) -> Void) {
        let proxy = connection?.remoteObjectProxyWithErrorHandler { error in
            print("XPC error:", error)
            reply(nil, error)
        } as? XPCProtocol

        guard let daemonProxy = proxy else {
            reply(nil, NSError(domain: "com.maxprudhomme.sortadaemon.client", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not get XPC proxy."]))
            return
        }

        daemonProxy.generateResponse(prompt: prompt, withReply: reply)
    }

    func generateResponseStreaming(prompt: String, chunkHandler: @escaping (String) -> Void, completionHandler: @escaping (Error?) -> Void) {
        activeListener?.invalidate()
        activeListener = nil
        activeListenerDelegate = nil
        print("DaemonClient: Preparing for new streaming request.")

        guard let connection = connection else {
            print("DaemonClient: Streaming failed - Not connected.")
            DispatchQueue.main.async {
                completionHandler(
                    NSError(
                        domain: "DaemonClient",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Not connected"]
                    )
                )
            }
            return
        }
        guard let daemonProxy = connection.remoteObjectProxyWithErrorHandler({ error in
            print("DaemonClient: XPC error on main connection: \(error)")
            DispatchQueue.main.async { completionHandler(error) }
            self.activeListener?.invalidate()
            self.activeListener = nil
            self.activeListenerDelegate = nil
        }) as? XPCProtocol else {
            print("DaemonClient: Streaming failed - Could not get proxy.")
            DispatchQueue.main.async {
                completionHandler(
                    NSError(
                        domain: "DaemonClient",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Proxy failed"]
                    )
                )
            }
            return
        }

        let listener = NSXPCListener.anonymous()
        self.activeListener = listener

        let delegate = ClientListenerDelegate(
            listener: listener,
            chunkHandler: chunkHandler,
            completionHandler: completionHandler
        )
        listener.delegate = delegate
        self.activeListenerDelegate = delegate

        listener.resume()
        print("DaemonClient: Anonymous listener resumed.")

        let endpoint = listener.endpoint

        print("DaemonClient: Calling generateResponseStreaming with endpoint...")
        daemonProxy.generateResponseStreaming(
            prompt: prompt,
            clientEndpoint: endpoint
        )
    }
}

private class ClientListenerDelegate: NSObject, NSXPCListenerDelegate, ClientProtocol {
    private let chunkHandler: (String) -> Void
    private let completionHandler: (Error?) -> Void
    private weak var listener: NSXPCListener?

    init(listener: NSXPCListener, chunkHandler: @escaping (String) -> Void, completionHandler: @escaping (Error?) -> Void) {
        self.listener = listener
        self.chunkHandler = chunkHandler
        self.completionHandler = completionHandler
        print("ClientListenerDelegate: Initialized.")
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        print("ClientListenerDelegate: Daemon connected back.")
        newConnection.exportedInterface = NSXPCInterface(with: ClientProtocol.self)
        newConnection.exportedObject = self
        newConnection.invalidationHandler = { print("ClientListenerDelegate: Connection from daemon invalidated.") }
        newConnection.interruptionHandler = { print("ClientListenerDelegate: Connection from daemon interrupted.") }
        newConnection.resume()
        return true
    }

    func receiveChunk(_ chunk: String) {
        DispatchQueue.main.async {
            self.chunkHandler(chunk)
        }
    }

    func receiveCompletion(errorData: Data?) {
        print("ClientListenerDelegate: Received completion.")
        var finalError: Error? = nil
        if errorData != nil {
            print("ClientListenerDelegate: Attempting to unarchive error...")
            if let data = errorData {
                print("ClientListenerDelegate: Attempting to unarchive error...")
                do {
                    let allowedClasses = [NSError.self, NSDictionary.self, NSString.self, NSNumber.self, NSArray.self, NSValue.self]
                    
                    if let unarchivedError = try NSKeyedUnarchiver.unarchivedObject(ofClasses: allowedClasses, from: data) as? Error {
                        finalError = unarchivedError
                        print("ClientListenerDelegate: Unarchived error: \(finalError!)")
                    } else {
                        print("ClientListenerDelegate: Failed to cast unarchived data to Error after unarchiving.")
                        finalError = NSError(domain: "ClientError", code: -3, userInfo: [NSLocalizedDescriptionKey:"Failed to decode error object from daemon"])
                    }
                } catch {
                    print("ClientListenerDelegate: Error during unarchiving: \(error)")
                    finalError = error
                }
            } else {
                print("ClientListenerDelegate: Completion received with no error data (Success).")
            }
            handleCompletionWithError(finalError)
        }
    }

    func handleCompletionWithError(_ error: Error?) {
         DispatchQueue.main.async {
             self.completionHandler(error)
             print("ClientListenerDelegate: Invalidating listener.")
             self.listener?.invalidate()
         }
    }

}
