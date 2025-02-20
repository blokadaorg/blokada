//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2023 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import Factory
import UIKit
import Combine
import StoreKit
import UserNotifications

class CommonBinding: CommonOps {

    let shareText = CurrentValueSubject<String?, Never>(nil)

    let links = CurrentValueSubject<[String : String], Never>([:])

    // Http
    private lazy var netx = Services.netx
    private var session: URLSession
    fileprivate let netxState = CurrentValueSubject<VpnStatus, Never>(VpnStatus.unknown)
    private var cancellables = Set<AnyCancellable>()
    
    @Injected(\.flutter) private var flutter

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval(15)
        configuration.timeoutIntervalForResource = TimeInterval(15)
        session = URLSession(configuration: configuration)

        CommonOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)

        onVpnStatus()
    }
    
    // Http

    func doGet(url: String, completion: @escaping (Result<String, Error>) -> Void) {
        if netxState.value == .activated || netxState.value == .reconfiguring {
            BlockaLogger.v("HttpBinding", "Making protected request")
            netx.makeProtectedRequest(url: url, method: "GET", body: "")
            .sink(
                onValue: { it in completion(.success(it)) },
                onFailure: { err in completion(.failure(err))}
            )
            .store(in: &cancellables)
            return
        }

        guard let url = URL(string: url) else {
            return completion(Result.failure("invalid url"))
        }

        var request = URLRequest(url: url)
        request.setValue(self.getUserAgent(), forHTTPHeaderField: "User-Agent")
        request.httpMethod = "GET"

        let task = self.session.dataTask(with: request) { payload, response, error in
            if let e = error {
                return completion(Result.failure(e))
            }

            guard let r = response as? HTTPURLResponse else {
                return completion(Result.failure("no response"))
            }

            guard r.statusCode == 200 else {
                return completion(Result.failure("code:\(r.statusCode)"))
            }

            guard let payload = payload else {
                return completion(Result.success(""))
            }

            return completion(Result.success(String(decoding: payload, as: UTF8.self)))
        }
        task.resume()
    }

    func doRequest(url: String, payload: String?, type: String,
                   completion: @escaping (Result<String, Error>) -> Void) {
        if netxState.value == .activated || netxState.value == .reconfiguring {
            BlockaLogger.v("HttpBinding", "Making protected request")
            netx.makeProtectedRequest(url: url, method: type.uppercased(), body: payload ?? "")
            .sink(
                onValue: { it in completion(.success(it)) },
                onFailure: { err in completion(.failure(err))}
            )
            .store(in: &cancellables)
            return
        }

        guard let url = URL(string: url) else {
            return completion(Result.failure("invalid url"))
        }

        var request = URLRequest(url: url)
        request.setValue(self.getUserAgent(), forHTTPHeaderField: "User-Agent")
        request.httpMethod = type.uppercased()

        if payload != nil {
            request.httpBody = payload?.data(using: .utf8)
        }

        let task = self.session.dataTask(with: request) { payload, response, error in
            if let e = error {
                return completion(Result.failure(e))
            }

            guard let r = response as? HTTPURLResponse else {
                return completion(Result.failure("no response"))
            }

            guard r.statusCode == 200 else {
                let res = String(data: payload ?? Data(), encoding: .utf8)
                BlockaLogger.e("http", "\(res)")
                return completion(Result.failure("code:\(r.statusCode)"))
            }

            guard let payload = payload else {
                return completion(Result.success(""))
            }

            return completion(Result.success(String(decoding: payload, as: UTF8.self)))
        }
        task.resume()
    }

    func doRequestWithHeaders(url: String, payload: String?, type: String,
                              headers: [String? : String?],
                              completion: @escaping (Result<String, any Error>) -> Void) {
        if netxState.value == .activated || netxState.value == .reconfiguring {
            BlockaLogger.v("HttpBinding", "Making protected request")
            netx.makeProtectedRequest(url: url, method: type.uppercased(), body: payload ?? "")
            .sink(
                onValue: { it in completion(.success(it)) },
                onFailure: { err in completion(.failure(err))}
            )
            .store(in: &cancellables)
            return
        }

        guard let url = URL(string: url) else {
            return completion(Result.failure("invalid url"))
        }

        var request = URLRequest(url: url)
        for header in headers {
            request.setValue(header.value, forHTTPHeaderField: header.key!)
        }
        request.httpMethod = type.uppercased()

        if payload != nil {
            request.httpBody = payload?.data(using: .utf8)
        }

        let task = self.session.dataTask(with: request) { payload, response, error in
            if let e = error {
                return completion(Result.failure(e))
            }

            guard let r = response as? HTTPURLResponse else {
                return completion(Result.failure("no response"))
            }

            guard r.statusCode == 200 else {
                let res = String(data: payload ?? Data(), encoding: .utf8)
                BlockaLogger.e("http", "\(res)")
                return completion(Result.failure("code:\(r.statusCode)"))
            }

            guard let payload = payload else {
                return completion(Result.success(""))
            }

            return completion(Result.success(String(decoding: payload, as: UTF8.self)))
        }
        task.resume()
    }

    private func onVpnStatus() {
        netx.getStatePublisher()
        .sink(onValue: { it in self.netxState.send(it) })
        .store(in: &cancellables)
    }

    // Rate

    func doShowRateDialog(completion: @escaping (Result<Void, Error>) -> Void) {
        requestReview()
        completion(.success(()))
    }

    private func requestReview() {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
    
    // Link

    func doLinksChanged(links: [OpsLink], completion: @escaping (Result<Void, Error>) -> Void) {
        self.links.send(transformLinks(links))
        completion(.success(()))
    }

    func transformLinks(_ links: [OpsLink]) -> [String: String] {
        var transformedLinks = [String: String]()
        for link in links {
            transformedLinks[link.id] = link.url
        }
        return transformedLinks
    }

    // Env

    func isProduction() -> Bool {
        return production
    }
    
    func isRunningTests() -> Bool {
        return runningTests
    }
    
    func getUserAgent() -> String {
        return "blokada/\(appVersion) (ios-\(osVersion) \(getBuildFlavor()) \(buildType) \(cpu) apple \(deviceModel) touch api compatible)"
    }

    func getAppVersion() -> String {
        return appVersion
    }
    
    func getAliasForLease() -> String {
        return aliasForLease
    }

    func getDeviceTag() -> String {
        return deviceTag
    }

    func setDeviceTag(tag: String) {
        deviceTag = tag
    }
    
    func getBuildFlavor() -> String {
        return flutter.isFlavorFamily ? "family" : "six"
    }

    func doGetEnvInfo(completion: @escaping (Result<OpsEnvInfo, Error>) -> Void) {
        completion(Result.success(OpsEnvInfo(
            appVersion: appVersion,
            osVersion: osVersion,
            buildFlavor: getBuildFlavor(),
            buildType: buildType,
            cpu: cpu,
            deviceBrand: "apple",
            deviceModel: deviceModel,
            deviceName: deviceName
        )))
    }

    fileprivate var cpu: String {
        #if PREVIEW
            return "sim"
        #else
            return "apple"
        #endif
    }

    fileprivate var buildType: String {
        #if DEBUG
            return "debug"
        #else
            return "release"
        #endif
    }

    fileprivate let deviceModel = UIDevice.current.modelName

    fileprivate let deviceName = UIDevice.current.name

    fileprivate var deviceTag = ""

    fileprivate let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "6.0.0-debug"

    fileprivate let osVersion = UIDevice.current.systemVersion

    private let aliasForLease = UIDevice.current.name

    private let runningTests = UserDefaults.standard.bool(forKey: "isRunningTests")

    private var production: Bool {
        return buildType == "release" && !runningTests
    }

    // Notification
    
    private lazy var writeNotification = PassthroughSubject<String, Never>()

    private lazy var center = UNUserNotificationCenter.current()

    private var delegate: NotificationCenterDelegateHandler? = nil

    @Injected(\.commands) private var commands

    func attach(_ app: UIApplication) {
        app.registerForRemoteNotifications()

        let delegate = NotificationCenterDelegateHandler(
            writeNotification: self.writeNotification
        )
        self.center.delegate = delegate
        // Keep a strong reference to prevent it from being deallocated
        self.delegate = delegate
    }

    func onAppleTokenReceived(_ appleToken: Data) {
        // Convert binary data to hex representation
        let token = appleToken.base64EncodedString()
        commands.execute(.appleNotificationToken, token)
    }

    func onAppleTokenFailed(_ err: Error) {
        commands.execute(.warning, "Failed registering for remote notifications: \(err)")
    }

    func doShow(notificationId: String, atWhen: String, body: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        //let whenDate = Date().addingTimeInterval(40)
        let whenDate = atWhen.toDate

        scheduleNotification(id: notificationId, when: whenDate, body: body)
        .sink(onFailure: { err in
            completion(.failure(err))
        }, onSuccess: {
            // Success is emitted only once the notification is triggerred
        })
        completion(.success(()))
    }
    
    func doDismissAll(completion: @escaping (Result<Void, Error>) -> Void) {
        clearAllNotifications()
        completion(.success(()))
    }

    func getPermissions() -> AnyPublisher<Granted, Error> {
        return Future<Granted, Error> { promise in
            self.center.getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized else {
                    return promise(.success(false))
                }

                return promise(.success(true))
            }
        }
        .eraseToAnyPublisher()
    }

    func askForPermissions(which: UNAuthorizationOptions = [.badge, .alert, .sound]) -> AnyPublisher<Ignored, Error> {
        return Future<Ignored, Error> { promise in
            self.center.requestAuthorization(options: which) { granted, error in
                if let error = error {
                    return promise(.failure(error))
                }

                self.center.getNotificationSettings { settings -> Void in
                    if settings.alertSetting == .enabled {
                        return promise(.success(true))
                    } else {
                        return promise(.failure("notifications not enabled"))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func scheduleNotification(id: String, when: Date, body: String? = nil) -> AnyPublisher<Ignored, Error> {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let date = calendar.dateComponents(
            [.year,.month,.day,.hour,.minute,.second,],
            from: when
        )

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: false)
        //let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 40, repeats: false)
        let request = UNNotificationRequest(
            identifier: id, content: mapNotificationToUser(id, body), trigger: trigger
        )

        print("Scheduling notification \(id) for: \(when.description(with: .current)), \(request)")
        print("Now is: \(Date().description(with: .current))")
        return Future<Ignored, Error> { promise in
            self.center.getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized else {
                    print("Unauthorized for notifications")
                    return promise(.failure("unauthorized for notifications"))
                }

                self.center.add(request) { error in
                    if let error = error {
                        print("Scheduling notification failed with error: \(error)")
                        return promise(.failure(error))
                    } else {
                        return promise(.success(true))
                    }
                }
            }
        }
        .flatMap { _ in
            self.writeNotification.first { it in it == id }
            .map { _ in true }
        }

        .eraseToAnyPublisher()
    }

    func clearAllNotifications() {
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    // -- Config
    func doConfigChanged(skipBypassList: Bool, completion: @escaping (Result<Void, any Error>) -> Void) {
        // Not relevant to iOS as of yet
        completion(.success(()))
    }

    // -- Share
    func doShareText(text: String, completion: @escaping (Result<Void, Error>) -> Void) {
        shareText.send(text)
        return completion(.success(()))
    }
}

extension UIDevice {
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}

extension Container {
    var common: Factory<CommonBinding> {
        self { CommonBinding() }.singleton
    }
}
