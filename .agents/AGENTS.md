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
