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

4. **`appstore-connect`**
   - **Capabilities:**
     - Managing app details, review status, TestFlight reviews, and builds.
   - **Usage Rules:**
     - Use this server to track metadata updates, review pipelines, and release statuses.

---

## App Store Connect & TestFlight CI Workflows

For automating TestFlight builds and App Store Connect operations, use the custom scripts located in the artifacts directory (`<appDataDir>/brain/<conversation-id>/scratch/` or project `build/` folder).

### Key Workflows & Automation Rules

1. **Xcode Cloud Auto-Cancellation:**
   - Xcode Cloud automatically cancels in-progress builds on the target branch if a new commit is pushed to that branch.
   - *Best Practice:* Before pushing multiple quick fixes, coordinate commits to avoid wasting build hours or canceling builds that are close to completion.

2. **Export Compliance Resolution (Missing Export Compliance):**
   - iOS builds uploaded to TestFlight remain locked in the `MISSING_EXPORT_COMPLIANCE` state and cannot be distributed to testers until resolved.
   - *Automatic Bypass:* Always add the following key-value pair to the project's `Info.plist` to bypass this manually:
     ```xml
     <key>ITSAppUsesNonExemptEncryption</key>
     <false/>
     ```
   - *Manual Override:* For existing builds, the owner must manually select "No" to the encryption question inside the App Store Connect web page (under TestFlight -> iOS -> Build -> Click "Missing Export Compliance").

3. **TestFlight Distribution Groups:**
   - A build uploaded to TestFlight must be explicitly linked to a distribution group (e.g., `Internal Testers Group`) to become visible on testers' devices.
   - This can be done automatically via the Xcode Cloud workflow's "Post-Actions" (select TestFlight internal/external testing).

### Diagnostic & Automation Scripts

The following helper python scripts are available in the workspace:

- **Check Xcode Cloud runs:**
  `python3 scratch/check_ci_runs.py`
  - Fetches the status (SUCCEEDED, CANCELED, or IN_PROGRESS) of the latest Xcode Cloud build runs.
- **Inspect latest run actions:**
  `python3 scratch/inspect_latest_run_actions.py`
  - Fetches the actions, execution progress, and associated build state (VALID, PROCESSING) of the current run.
- **Check build beta groups:**
  `python3 scratch/check_build_beta_groups.py`
  - Lists recent TestFlight builds and shows which beta groups they are currently distributed to.
- **Force link build to internal group:**
  `python3 scratch/link_build_to_internal.py`
  - Bypasses workflow issues by manually linking the latest VALID build to the internal testers group via API.
