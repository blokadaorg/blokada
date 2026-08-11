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
        // BLOKADA VENDOR PATCH: blokadaorg fork of AdaptySDK-iOS at the 4.0.2 tag
        // plus one commit restoring the includeBackground gate on static decorator
        // backgrounds (upstream regression darkens translucent paywall footers —
        // see branch blokada/4.0.2-footer-include-background-gate). Pinned by
        // revision for reproducibility. Upstream pin was `exact: "4.0.2"`; return
        // to it when Adapty ships the fix.
        .package(
            url: "https://github.com/blokadaorg/AdaptySDK-iOS.git",
            revision: "caf82a13d050855fe725a151e29a1e214f9f65cd"
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
