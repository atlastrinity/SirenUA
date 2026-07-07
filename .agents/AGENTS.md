# Project Rules & Architecture for SirenUA

## 🚨 Critical Repository Mapping (SirenUA & SirenUA-ThreatServer)

This workspace consists of two separate repositories that interact with each other:

1. **iOS Application Repository**:
   - Repository: `https://github.com/atlastrinity/SirenUA`
   - Local directory: `/Users/dev/Documents/GitHub/claw-code/serena/SirenUA`
   - Contains: Swift codebase for iOS client, local StoreKit configurations, and reference/local files.

2. **Render Threat Server Repository**:
   - Repository: `https://github.com/atlastrinity/SirenUA-ThreatServer`
   - Cloned directory: `/Users/dev/Documents/GitHub/claw-code/serena/SirenUA-ThreatServer`
   - Contains: Python FastAPI backend for real-time OSM shelters, Telegram monitoring bot, and Firebase integration.
   - **Crucial Rule**: The live deployment on Render is connected ONLY to `SirenUA-ThreatServer`.
   
### ⚠️ Server Deployment Process:
Whenever changes are made to the threat server code (e.g. `mock_mode.py`, `telegram_monitor.py`, `server.py`, `shelter_manager.py`):
1. The changes **MUST** be copied/synchronized to the cloned `SirenUA-ThreatServer` repository.
2. The changes **MUST** be committed and pushed to `SirenUA-ThreatServer.git` (branch `main`).
3. Only pushing to `SirenUA-ThreatServer.git` triggers Render's automated build and redeployment. Pushing changes to the `/threat_server` subfolder in the `SirenUA` repository will **NOT** update the live server.

## 🤖 AI Automation & CI/CD Capabilities

The AI agent has full access to automate the entire development and deployment lifecycle for this project. The agent MUST proactively use the following tools instead of asking the user to perform manual UI actions:

1. **Builds & Deployments (Fastlane)**
   - **Rule:** NEVER use Xcode Cloud for builds. ALWAYS use **Fastlane** via the terminal (`run_command` tool).
   - **Command:** Use `fastlane beta` to automatically increment the build number, compile the `.ipa`, and upload it to TestFlight.
   - The App Store Connect API keys are pre-configured in `.env` and `fastlane/Fastfile`.

2. **Local iOS Development (MCP Servers)**
   - `xcode-bridge`: Use this to build the project locally, run tests, format code, and manage Xcode project files programmatically.
   - `swiftlens`: Use this for deep semantic search, finding references, and understanding Swift architecture via SourceKit-LSP.
   - `ios-simulator`: Use this to launch the app in the iOS Simulator, tap on UI elements, and take screenshots for validation.

3. **App Store Management (MCP Server)**
   - `appstore-connect`: Use this to manage app metadata, read/triage user reviews, and generate Release Notes automatically via the App Store Connect API.

When the user requests a full cycle (e.g., "build and release a new version"), the agent should autonomously orchestrate these tools (e.g., compile locally -> run tests -> fastlane beta -> update release notes via MCP).
