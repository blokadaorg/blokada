//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2020 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import UIKit

class BlockaApiService {

    static let shared = BlockaApiService()

    private let log = Logger("BlockaApi")

    private let baseUrl = "https://api.blocka.net"

    private let decoder = initJsonDecoder()
    private let encoder = initJsonEncoder()

    private let network = NetworkService.shared

    private init() {
        // singleton
    }

    static func userAgent() -> String {
        return "blokada/\(Env.appVersion) (ios-\(UIDevice.current.systemVersion) ios \(Env.buildType) \(Env.cpu) apple \(Env.deviceModel) touch api compatible)"
    }

    func postAccount(done: @escaping Callback<Account>) {
        self.request(url: self.baseUrl + "/v1/account", method: "POST", done: { (error, result) in
            guard error == nil else {
                done(error, nil)
                return
            }

            guard let stringData = result else {
                done("postAccount: request returned nil result", nil)
                return
            }

            let jsonData = stringData.data(using: .utf8)
            guard let json = jsonData else {
                done("postAccount: parsing api response failed", nil)
                return
            }

            do {
                let account = try self.decoder.decode(AccountWrapper.self, from: json)
                done(nil, account.account)
            } catch {
                self.log.e("postAccount: failed".cause(error))
                done("postAccount: failed decoding api json response".cause(error), nil)
            }
        })
    }

    func getAccount(id: AccountId, done: @escaping Callback<Account>) {
        self.request(url: self.baseUrl + "/v1/account?account_id=" + id, done: { (error, result) in
            guard error == nil else {
                done(error, nil)
                return
            }

            guard let stringData = result else {
                done("getAccount: request returned nil result", nil)
                return
            }

            let jsonData = stringData.data(using: .utf8)
            guard let json = jsonData else {
                done("getAccount: parsing api response failed", nil)
                return
            }

            do {
                let account = try self.decoder.decode(AccountWrapper.self, from: json)
                done(nil, account.account)
            } catch {
                self.log.e("getAccount: failed".cause(error))
                done("getAccount: failed decoding api json response".cause(error), nil)
            }
        })
    }

    func getDevice(id: AccountId, done: @escaping Callback<DevicePayload>) {
        self.request(url: self.baseUrl + "/v1/device?account_id=" + id, done: { (error, result) in
            guard error == nil else {
                done(error, nil)
                return
            }

            guard let stringData = result else {
                done("getDevice: request returned nil result", nil)
                return
            }

            let jsonData = stringData.data(using: .utf8)
            guard let json = jsonData else {
                done("getDevice: parsing api response failed", nil)
                return
            }

            do {
                let val = try self.decoder.decode(DevicePayload.self, from: json)
                done(nil, val)
            } catch {
                self.log.e("getDevice: failed".cause(error))
                done("getDevice: failed decoding api json response".cause(error), nil)
            }
        })
    }
    
    func postDevice(request: DeviceRequest, done: @escaping Callback<Void>) {
        guard let body = request.toJson() else {
            onMain { done("Failed encoding Device", nil) }
            return
        }

        self.request(url: self.baseUrl + "/v1/device", method: "PUT", body: body, done: { (error, result) in
            guard error == nil else {
                done(error, nil)
                return
            }

            guard result != nil else {
                done("postDevice: request returned nil result", nil)
                return
            }

            done(nil, ())
        })
    }

    func getCurrentAccount(done: @escaping Callback<Account>) {
        self.getAccount(id: Config.shared.accountId(), done: done)
    }

    func getCurrentDevice(done: @escaping Callback<DevicePayload>) {
        self.getDevice(id: Config.shared.accountId(), done: done)
    }

    func getGateways(done: @escaping Callback<[Gateway]>) {
        self.request(url: self.baseUrl + "/v2/gateway", done: { (error, result) in
            guard error == nil else {
                done(error, nil)
                return
            }

            guard let stringData = result else {
                done("getGateways: request returned nil result", nil)
                return
            }

            let jsonData = stringData.data(using: .utf8)
            guard let json = jsonData else {
                done("getGateways: parsing api response failed", nil)
                return
            }

            do {
                let gateways = try self.decoder.decode(Gateways.self, from: json)
                done(nil, gateways.gateways)
            } catch {
                self.log.e("getGateways: failed".cause(error))
                done("getGateways: failed decoding api json response".cause(error), nil)
            }
        })
    }

    func getLeases(id: AccountId, done: @escaping Callback<[Lease]>) {
        self.request(url: self.baseUrl + "/v1/lease?account_id=" + id, done: { (error, result) in
            guard error == nil else {
                done(error, nil)
                return
            }

            guard let stringData = result else {
                done("getLeases: request returned nil result", nil)
                return
            }

            let jsonData = stringData.data(using: .utf8)
            guard let json = jsonData else {
                done("getLeases: parsing api response failed", nil)
                return
            }

            do {
                let leases = try self.decoder.decode(Leases.self, from: json)
                done(nil, leases.leases)
            } catch {
                self.log.e("getLeases: failed".cause(error))
                done("getLeases: failed decoding api json response".cause(error), nil)
            }
        })
    }

    func getCurrentLease(done: @escaping Callback<Lease>) {
        self.getLeases(id: Config.shared.accountId()) { error, leases in
            guard error == nil else {
                done(error, nil)
                return
            }

            guard let leases = leases else {
                // A valid case, no leases at all
                done(nil, nil)
                return
            }

            let current = leases.first(where: { it in
                it.public_key == Config.shared.publicKey()
            })

            if let c = current {
                done(nil, c)
            } else {
                // A valid case, no lease for this device
                done(nil, nil)
                return
            }
        }
    }

    func postLease(request: LeaseRequest, done: @escaping Callback<Lease>) {
        guard let body = request.toJson() else {
            onMain { done("Failed encoding LeaseRequest", nil) }
            return
        }

        self.request(url: self.baseUrl + "/v1/lease", method: "POST", body: body, done: { (error, result) in
            guard error == nil else {
                if let e = error as? NetworkError {
                    switch e {
                      case .http(let code):
                        if code == 403 {
                            return done(CommonError.tooManyLeases, nil)
                        } else {
                            return done(error, nil)
                        }
                      @unknown default:
                        return done(error, nil)
                    }
                } else {
                    done(error, nil)
                    return
                }
            }

            guard let stringData = result else {
                done("postLease: request returned nil result", nil)
                return
            }

            let jsonData = stringData.data(using: .utf8)
            guard let json = jsonData else {
                done("postLease: parsing api response failed", nil)
                return
            }

            do {
                let lease = try self.decoder.decode(LeaseWrapper.self, from: json)
                done(nil, lease.lease)
            } catch {
                self.log.e("postLease: failed".cause(error))
                self.log.v(stringData)
                done(error, nil)
            }
        })
    }

    func deleteLease(request: LeaseRequest, done: @escaping Callback<Void>) {
        guard let body = request.toJson() else {
            return onMain { done("Failed encoding LeaseRequest", nil) }
        }

        self.request(url: self.baseUrl + "/v1/lease", method: "DELETE", body: body, done: { (error, result) in
            return done(error, nil)
        })
    }

    func deleteLeasesWithAliasOfCurrentDevice(id: AccountId, done: @escaping Callback<Void>) {
        self.getLeases(id: id) { error, leases in
            if let error = error {
                return done(error, nil)
            }

            if let lease = leases?.first(where: { $0.alias == Env.aliasForLease }) {
                let leaseRequest = LeaseRequest(
                    account_id: lease.account_id,
                    public_key: lease.public_key,
                    gateway_id: lease.gateway_id,
                    alias: lease.alias
                )

                self.log.w("Deleting one active lease for current alias")
                return self.deleteLease(request: leaseRequest, done: done)
            } else {
                return done("Found no lease for current alias", nil)
            }
        }
    }
    
    func getActivity(id: AccountId, done: @escaping Callback<[Activity]>) {
        self.request(url: self.baseUrl + "/v1/activity?account_id=" + id, done: { (error, result) in
            guard error == nil else {
                done(error, nil)
                return
            }

            guard let stringData = result else {
                done("getActivity: request returned nil result", nil)
                return
            }

            let jsonData = stringData.data(using: .utf8)
            guard let json = jsonData else {
                done("getActivity: parsing api response failed", nil)
                return
            }

            do {
                let activities = try self.decoder.decode(ActivityWrapper.self, from: json)
                done(nil, activities.activity)
            } catch {
                self.log.e("getActivity: failed".cause(error))
                done("getActivity: failed decoding api json response".cause(error), nil)
            }
        })
    }

    func getCurrentDeviceActivity(done: @escaping Callback<[Activity]>) {
        self.getActivity(id: Config.shared.accountId()) { error, activity in
            guard error == nil else {
                done(error, nil)
                return
            }

            guard let activity = activity else {
                done("No activity result returned", nil)
                return
            }

            let thisDevice = Config.shared.deviceName()
            // TODO: Including empty device because we cannot set device name in Plus mode
            done(nil, activity.filter { it in it.device_name == thisDevice || it.device_name.isEmpty })
        }
    }
    
    func getBlockingExceptions(id: AccountId, done: @escaping Callback<[BlockingException]>) {
        self.request(url: self.baseUrl + "/v1/customlist?account_id=" + id, done: { (error, result) in
            guard error == nil else {
                done(error, nil)
                return
            }

            guard let stringData = result else {
                done("getBlockingExceptions: request returned nil result", nil)
                return
            }

            let jsonData = stringData.data(using: .utf8)
            guard let json = jsonData else {
                done("getBlockingExceptions: parsing api response failed", nil)
                return
            }

            do {
                let exceptions = try self.decoder.decode(ExceptionWrapper.self, from: json)
                done(nil, exceptions.customlist)
            } catch {
                self.log.e("getBlockingExceptions: failed".cause(error))
                done("getBlockingExceptions: failed decoding api json response".cause(error), nil)
            }
        })
    }

    func getCurrentBlockingExceptions(done: @escaping Callback<[BlockingException]>) {
        return self.getBlockingExceptions(id: Config.shared.accountId(), done: done)
    }

    func postBlockingException(request: BlockingExceptionRequest, method: String = "POST", done: @escaping Callback<Void>) {
        guard let body = request.toJson() else {
            onMain { done("Failed encoding BlockingExceptionRequest", nil) }
            return
        }

        self.request(url: self.baseUrl + "/v1/customlist", method: method, body: body, done: { (error, result) in
            guard error == nil else {
                done(error, nil)
                return
            }

            guard result != nil else {
                done("postBlockingExceptions: request returned nil result", nil)
                return
            }
        })
    }

    func getCurrentBlocklists(done: @escaping Callback<[Blocklist]>) {
        return self.getBlocklists(id: Config.shared.accountId(), done: done)
    }
    
    func getBlocklists(id: AccountId, done: @escaping Callback<[Blocklist]>) {
        self.request(url: self.baseUrl + "/v1/list?account_id=" + id, done: { (error, result) in
            guard error == nil else {
                done(error, nil)
                return
            }

            guard let stringData = result else {
                done("getBlocklists: request returned nil result", nil)
                return
            }

            let jsonData = stringData.data(using: .utf8)
            guard let json = jsonData else {
                done("getBlocklists: parsing api response failed", nil)
                return
            }

            do {
                let blocklists = try self.decoder.decode(BlocklistWrapper.self, from: json)
                done(nil, blocklists.lists)
            } catch {
                self.log.e("getBlocklists: failed".cause(error))
                done("getBlocklists: failed decoding api json response".cause(error), nil)
            }
        })
    }

    func postAppleCheckout(request: AppleCheckoutRequest, done: @escaping Callback<Account>) {
        guard let body = request.toJson() else {
            onMain { done("Failed encoding AppleCheckoutRequest", nil) }
            return
        }

        self.request(url: self.baseUrl + "/v1/apple/checkout", method: "POST", body: body, done: { (error, result) in
            guard error == nil else {
                done(error, nil)
                return
            }

            guard let stringData = result else {
                done("postAppleCheckout: request returned nil result", nil)
                return
            }

            let jsonData = stringData.data(using: .utf8)
            guard let json = jsonData else {
                done("postAppleCheckout: parsing api response failed", nil)
                return
            }

            do {
                let account = try self.decoder.decode(AccountWrapper.self, from: json)
                done(nil, account.account)
            } catch {
                self.log.v("postAppleCheckout: failed".cause(error))
                self.log.v(stringData)
                done("postAppleCheckout: failed decoding api json response".cause(error), nil)
            }
        })
    }

    func postAppleDeviceToken(request: AppleDeviceTokenRequest, done: @escaping (Error?) -> Void) {
        guard let body = request.toJson() else {
            return done("postAppleDeviceToken: failed encoding AppleDeviceTokenRequest")
        }

        self.request(url: self.baseUrl + "/v1/apple/device", method: "POST", body: body) { (error, _) in
            done(error)
        }
    }

    private func request(url: String, method: String = "GET", body: String = "", done: @escaping Callback<String>) {
        onBackground {
            let request = ["request", url, method, ":body:", body].joined(separator: " ")
            self.network.sendMessage(msg: request, skipReady: false, done: { error, result in
                onBackground {
                    if error != nil {
                        self.network.directRequest(url: url, method: method, body: body, done: done)
                    } else {
                        onMain { done(error, result) }
                    }
                }
            })
        }
     }

}
