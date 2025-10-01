# LLS One-Click (after setup) Ping – GitHub Pages

This package lets you host a GitHub Pages site with buttons like `llsdiag://run?ip=216.20.237.2&dur=900`.
After a **one-time registration** of the custom URL protocol, clicking a location button will launch PowerShell,
download `Runner.ps1` from your site, and run a 15-minute ping from the user's PC (their network).

## Files
- `index.html` — buttons for locations (first IP per site)
- `Runner.ps1` — performs the ping, saves raw and summary, zips results
- `Register-LLSDiag.ps1` — one-time script to register the `llsdiag://` protocol on the PC

## One-time setup on a test PC
1. Open your GitHub Pages site (or download this file locally).
2. Run `Register-LLSDiag.ps1` **as Administrator**.
   - It asks for your Pages base URL (e.g., `https://<you>.github.io/net-ping-test`)
   - It registers `llsdiag://` so browser clicks can launch PowerShell safely.
3. Click a location button on the page to start the test.

## Security
- Protocol is registered under **HKCU** (current user) only.
- PowerShell runs with `-ExecutionPolicy Bypass` to allow the script; adjust per enterprise policy.
- Source script is fetched over HTTPS from your GitHub Pages site.

## Notes
- Browsers can't natively ping or open a local terminal. This is the safest way to approach "one click".
- For enterprise rollout, consider packaging the protocol registration via Intune/Group Policy.
