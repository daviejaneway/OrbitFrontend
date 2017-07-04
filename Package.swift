import PackageDescription

let package = Package(
    name: "OrbitFrontend",
    dependencies: [
        .Package(url: "https://github.com/daviejaneway/OrbitCompilerUtils.git", majorVersion: 0)
    ]
)
