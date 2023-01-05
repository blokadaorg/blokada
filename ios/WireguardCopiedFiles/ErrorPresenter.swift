// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

import UIKit
import os.log

class ErrorPresenter: ErrorPresenterProtocol {
    static func showErrorAlert(title: String, message: String, from sourceVC: AnyObject?, onPresented: (() -> Void)?, onDismissal: (() -> Void)?) {
        guard let sourceVC = sourceVC as? UIViewController else { return }

        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            onDismissal?()
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(okAction)

        sourceVC.present(alert, animated: true, completion: onPresented)
    }
}
