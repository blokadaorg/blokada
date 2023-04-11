// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

import Foundation
import NetworkExtension
import os
import Factory

// This is our override of wg-ios that adds the ability to perform protected HTTP requests.
class BlockaPacketTunnelProvider: PacketTunnelProvider {
    private var env = Env()

    private func performProtectedHttpRequest(url: String, method: String, body: String, completionHandler: @escaping ((Error?, String?) -> Void)) {
        
        let data = Data(body.utf8)
        let url = URL(string: url)!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(env.getUserAgent(), forHTTPHeaderField: "User-Agent")

        if !body.isEmpty {
            request.httpBody = data
            request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                return completionHandler(error, nil)
            }
            
            if let r = response as? HTTPURLResponse, r.statusCode != 200 {
                return completionHandler("code:\(r.statusCode)", nil)
            }
            
            guard let data = data else {
                return completionHandler(nil, nil)
            }
            completionHandler(nil, String(decoding: data, as: UTF8.self))
        }

        task.resume()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        guard let completionHandler = completionHandler else { return }

        if messageData.count == 1 {
            return super.handleAppMessage(messageData, completionHandler: completionHandler)
        }

        let data = String.init(data: messageData, encoding: String.Encoding.utf8)!
        let params = data.components(separatedBy: " ")
        let command = params[0]
        NELogger.v("BlockaPTP: command received: \(command)")

        switch command {
        case "request":
            let url = params[1]
            let method = params[2]
            let body = data.components(separatedBy: " :body: ")[1]

            NELogger.v("BlockaPTP: request: \(method) \(url), body len: \(body.count)")

            performProtectedHttpRequest(url: url, method: method, body: body, completionHandler: { error, response in
                self.respond(command: command, error: error, response: response ?? "", completionHandler: completionHandler)
            })
        default:
            NELogger.v("BlockaPTP: message ignored, responding OK")
            let data = "".data(using: String.Encoding.utf8)
            completionHandler(data)
        }
    }

    private func respond(command: String, error: Error?, response: String, completionHandler: ((Data?) -> Void)) {
        var data = response.data(using: String.Encoding.utf8)
        if (error != nil) {
            NELogger.e("BlockaPTP: \(command) responded with error: \(error)")
            data = ("error: " + error!.localizedDescription).data(using: String.Encoding.utf8)
        } else {
            NELogger.v("BlockaPTP: \(command) responded with OK")
        }

        completionHandler(data)
    }

}
