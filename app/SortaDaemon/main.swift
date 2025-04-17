//
//  main.swift
//  SortaDaemon
//
//  Created by Max PRUDHOMME on 17/04/2025.
//

import Foundation

class HelperDelegate: NSObject, NSXPCListenerDelegate, XPCProtocol {
  func listener(_ listener: NSXPCListener,
                shouldAcceptNewConnection conn: NSXPCConnection) -> Bool {
    // Export our protocol on the new connection:
    conn.exportedInterface =
      NSXPCInterface(with: XPCProtocol.self)
    conn.exportedObject = self
    conn.resume()
    return true
  }

  func process(prompt: String, withReply reply: @escaping (String?, Error?) -> Void) {
    let out = prompt + " 😊"
    reply(out, nil)
  }
}

let listener = NSXPCListener(machServiceName: "com.maxprudhomme.sortadaemon")
let delegate = HelperDelegate()
listener.delegate = delegate
listener.resume()

RunLoop.main.run()
