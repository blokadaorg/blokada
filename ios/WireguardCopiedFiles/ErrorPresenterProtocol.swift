// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

protocol ErrorPresenterProtocol {
    static func showErrorAlert(title: String, message: String, from sourceVC: AnyObject?, onPresented: (() -> Void)?, onDismissal: (() -> Void)?)
}

extension ErrorPresenterProtocol {
    static func showErrorAlert(title: String, message: String, from sourceVC: AnyObject?, onPresented: (() -> Void)?) {
        showErrorAlert(title: title, message: message, from: sourceVC, onPresented: onPresented, onDismissal: nil)
    }

    static func showErrorAlert(title: String, message: String, from sourceVC: AnyObject?, onDismissal: (() -> Void)?) {
        showErrorAlert(title: title, message: message, from: sourceVC, onPresented: nil, onDismissal: onDismissal)
    }

    static func showErrorAlert(title: String, message: String, from sourceVC: AnyObject?) {
        showErrorAlert(title: title, message: message, from: sourceVC, onPresented: nil, onDismissal: nil)
    }

    static func showErrorAlert(error: WireGuardAppError, from sourceVC: AnyObject?, onPresented: (() -> Void)? = nil, onDismissal: (() -> Void)? = nil) {
        let (title, message) = error.alertText
        showErrorAlert(title: title, message: message, from: sourceVC, onPresented: onPresented, onDismissal: onDismissal)
    }
}
