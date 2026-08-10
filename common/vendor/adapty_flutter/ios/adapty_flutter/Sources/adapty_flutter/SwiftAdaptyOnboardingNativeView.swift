//
//  SwiftAdaptyOnboardingNativeView.swift
//  adapty_flutter
//
//  Created by Alexey Goncharov on 5/28/25.
//

import Adapty
import AdaptyPlugin
import AdaptyUI
import Flutter
import UIKit

class AdaptyOnboardingNativeViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    private let eventHandler: EventHandler

    init(
        messenger: FlutterBinaryMessenger,
        eventHandler: EventHandler
    ) {
        self.messenger = messenger
        self.eventHandler = eventHandler

        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return AdaptyOnboardingNativeView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger,
            eventHandler: eventHandler
        )
    }

    /// Implementing this method is only necessary when the `arguments` in `createWithFrame` is not `nil`.
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class AdaptyOnboardingNativeView: NSObject, FlutterPlatformView {
    private var _view: UIView

    private let viewId: Int64
    private let onboardingJsonString: String?
    private let eventHandler: EventHandler

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?,
        eventHandler: EventHandler
    ) {
        _view = UIView()
        self.viewId = viewId
        self.eventHandler = eventHandler

        onboardingJsonString = args as? String

        super.init()

        if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *) {
            createNativeView(view: _view)
        }
    }

    func view() -> UIView {
        return _view
    }

    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *)
    private func createNativeView(view _view: UIView) {
        Task { @MainActor in
            do {
                guard let onboardingJsonString else {
                    throw AdaptyPluginError.platformViewError("Onboarding Configuration Data Not Found")
                }

                let configuration = try await AdaptyPlugin.getOnboardingViewConfiguration(
                    withJson: onboardingJsonString
                )

                let uiView = AdaptyOnboardingPlatformViewWrapper(
                    viewId: "flutter_native_\(viewId)",
                    eventHandler: eventHandler,
                    configuration: configuration
                )

                _view.addSubview(uiView)

                uiView.translatesAutoresizingMaskIntoConstraints = false
                _view.addConstraints([
                    uiView.leadingAnchor.constraint(equalTo: _view.leadingAnchor),
                    uiView.trailingAnchor.constraint(equalTo: _view.trailingAnchor),
                    uiView.topAnchor.constraint(equalTo: _view.topAnchor),
                    uiView.bottomAnchor.constraint(equalTo: _view.bottomAnchor),
                ])
            } catch {
                Log.wrapper.error(error.localizedDescription)
            }
        }
    }
}
