// swift-tools-version:5.9
import PackageDescription

// QattahKit holds the app's pure business logic (money, splitting, balances,
// suggestions, share messages). It has no UIKit/SwiftUI/GRDB dependency so it
// can be unit-tested quickly with `swift test`.
let package = Package(
    name: "QattahKit",
    defaultLocalization: "ar",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "QattahKit", targets: ["QattahKit"]),
    ],
    targets: [
        .target(name: "QattahKit"),
        .testTarget(name: "QattahKitTests", dependencies: ["QattahKit"]),
    ]
)
