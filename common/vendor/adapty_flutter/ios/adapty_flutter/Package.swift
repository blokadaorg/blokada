// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "adapty_flutter",
    platforms: [
        .iOS("15.0"),
    ],
    products: [
        .library(name: "adapty-flutter", targets: ["adapty_flutter"]),
    ],
    dependencies: [
        // BLOKADA VENDOR PATCH: fork of AdaptySDK-iOS at the 4.0.3 tag + restored
        // includeBackground gate (branch blokada/4.0.3-footer-include-background-gate).
        // The upstream regression darkens translucent paywall footers; the fork adds
        // one commit restoring the gate on static decorator backgrounds. Pinned by
        // revision for reproducibility. Upstream pin was `exact: "4.0.3"`; return to
        // it when Adapty ships the fix.
        .package(
            url: "https://github.com/blokadaorg/AdaptySDK-iOS.git",
            revision: "ce0a55a84555019cf6a71e859697c59d827a0ac1"
        ),
    ],
    targets: [
        .target(
            name: "adapty_flutter",
            dependencies: [
                .product(name: "Adapty", package: "AdaptySDK-iOS"),
                .product(name: "AdaptyUI", package: "AdaptySDK-iOS"),
                .product(name: "AdaptyPlugin", package: "AdaptySDK-iOS"),
            ],
            // Bridge sources are not Swift 6 strict-concurrency clean.
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
