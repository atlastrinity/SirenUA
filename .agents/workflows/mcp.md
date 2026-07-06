---
description: MCP IOS
---

# iOS & Xcode MCP Guidelines

When developing, building, or debugging iOS/macOS applications, use the `xcode-bridge` and `swiftlens` MCP servers to interact directly with Xcode and Swift, avoiding raw terminal commands for building and error-checking.

## Available MCP Servers

1. **`xcode-bridge`**
   - **Capabilities:**
     - Building and testing projects directly in an open Xcode window (`BuildProject`, `RunAllTests`, `RunSomeTests`).
     - Real-time diagnostics and issue navigation (`XcodeListNavigatorIssues`, `XcodeRefreshCodeIssuesInFile`).
     - Exploring the project structure (`XcodeLS`, `XcodeRead`, `XcodeGrep`, `XcodeGlob`).
     - Modifying code securely via IDE commands (`XcodeWrite`, `XcodeRM`, `XcodeMV`, `ExecuteSnippet`, `XcodeMakeDir`).
   - **Usage Rules:**
     - First, ensure the project is open in Xcode using the terminal (`open MyProject.xcodeproj`).
     - Use `XcodeListWindows` to identify the correct `tabIdentifier` for your workspace.
     - Provide the `tabIdentifier` when calling tools like `BuildProject` or `XcodeListNavigatorIssues`.
     - After building, check `buildResult` and `errors`. If errors occur, use `XcodeListNavigatorIssues` to see detailed line-by-line compiler feedback.

2. **`swiftlens`**
   - **Capabilities:**
     - Deep static analysis of Swift code using SourceKit-LSP.
     - Identifying symbol definitions, references, and diagnostics.
   - **Usage Rules:**
     - Use this server for detailed symbol lookup and structural analysis of Swift files without relying on Xcode's build system.

3. **`ios-simulator`**
   - **Capabilities:**
     - Tools for interacting with the iOS simulator (booting, installing apps, launching apps, interacting with UI).
   - **Usage Rules:**
     - Use this server to inspect simulator states, tap/type on the UI, and verify the app's visual behavior.

## General Best Practices
- ALWAYS rely on `xcode-bridge` to read and write files when making complex changes, as it ensures Xcode remains perfectly synchronized with the file system.
- Before suggesting raw terminal commands like `xcodebuild`, try using `BuildProject` from `xcode-bridge` first.

