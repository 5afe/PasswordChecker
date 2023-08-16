// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "PasswordChecker",
    platforms: [.iOS(.v13), .macOS(.v11)],
    products: [
        .library(name: "PasswordChecker", targets: ["PasswordChecker"]),
    ],
    targets: [
        .target(name: "PasswordChecker",
                resources: [
                    .process("zxcvbn")
                ]),
    ]
)
