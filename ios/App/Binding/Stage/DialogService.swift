//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2021 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import Combine
import UIKit

class DialogService {

    private var controller: UIViewController? = nil

    init() {
        
    }

    func showAlert(
        message: String,
        header: String = L10n.alertErrorHeader,
        okText: String = L10n.universalActionClose,
        okAction: @escaping () -> Void = {}
    ) -> AnyPublisher<Ignored, Error> {
        return Just(true)
        .receive(on: RunLoop.main)
        .flatMap { _ in
            return Future<Ignored, Error> { promise in
                let alert = UIAlertController(title: header, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(
                    title: NSLocalizedString(okText, comment: "Default action"),
                    style: .default,
                    handler: { _ in
                    alert.dismiss(animated: true)
                    okAction()
                    promise(.success(true))
                }))
                self.present(alert)
            }
        }
        .eraseToAnyPublisher()
    }

    func shareFile(_ file: URL) {
//        let activityVC = UIActivityViewController(
//            activityItems: [LoggerSaver.logFile],
//            applicationActivities: nil
//        )
    }

    func setController(_ controller: UIViewController) {
        self.controller = controller
    }

    private func present(_ alert: UIAlertController) {
        controller?.present(alert, animated: true)
    }

    private func present(_ viewController: UIActivityViewController) {
        controller?.present(viewController, animated: true, completion: nil)
    }

}
