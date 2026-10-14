# Native Mac readiness - 14 October 2026

User selected native Mac delivery after comparing a browser port and VPN installation. Keep the existing Windows build and add one universal Mac ZIP; Intel and Apple silicon do not need separate downloads. The Mac model and macOS version are unavailable, so native compatibility remains unconfirmed until first launch.

## Internet candidate

The universal Mac ZIP was re-exported with the temporary public endpoint embedded. Current ZIP SHA256: `0CE9E6C454B7134426F662977584209E6117870C9B535A098E053E879AD82CE9`, 64,379,981 bytes. Final PCK SHA256: `56E90BC5F5AA9C17ACEB66B2A6EA023385128EC36E776DC18B981C546235163E`. The existing Windows build and this PCK passed native room RPC checks through the public TLS endpoint; the final Mac PCK also passed all 42 family checks through that service. Native Mac execution is still unverified. This free fallback requires Dad's Windows PC and tunnel to stay running. See the root family instructions.

## Initial export evidence

Godot 4.7.2 official export-template archive was verified against its published SHA512. The macOS export succeeded using built-in ad-hoc signing, universal architecture and the required ETC2/ASTC imports. The ZIP preserves Unix executable permissions; exporting a bare .app from Windows would not.

Local candidate: `build/crown-court-0.17.0-mac/CrownCourt-macOS.zip`, 64,379,931 bytes; SHA256 `7b9bba26cbfe818dee9b729d88483a668271e3e3644e96e5ea48acddc6161967`.

Static archive inspection found both x86_64 and ARM64 Mach-O slices, code-signature records in both, version 0.17.0 and executable mode 100755. This inspects signature structure; it is not Apple's codesign verification or notarization. Receipt: `build/crown-court-0.17.0-mac/package-verification.json`.

The actual exported PCK passed profile (23), series (23), and presentation-authority (40) checks under the Windows engine. Three clients loaded the Mac PCK and passed room RPC checks. A further mixed test used the public Windows EXE as host and Mac PCK as both clients; all five RPC channels, identities, shared result and departures passed. Receipt: `build/crown-court-evidence/mixed-windows-mac-pack-20261014/rpc-result.json`. All profiles were isolated. These tests do not run the Mac executable or establish public internet play.

That initial candidate had a blank internet endpoint; the current candidate above embeds the verified temporary endpoint. A later move to permanent hosting will require another endpoint update. Keep the endpoint inside the signed Mac bundle. The existing Windows build can use adjacent internet.cfg without changing its saves.

## First launch

Unzip, move Crown Court.app to Applications, then open it. Because this family release is ad-hoc signed and not Apple-notarized, macOS may require an adult to use System Settings > Privacy & Security > Open Anyway after the first attempt. Managed/parent-controlled Macs may restrict that option. Do not disable Gatekeeper globally. Check the exact warning if the app reports damage or malware.

The preset requests macOS 10.13 for Intel and 11.0 for Apple silicon; actual GPU/OS support and acceptable performance require a test on the iMac. An up-to-date supported browser remains a fallback if native installation is restricted, but no browser release is being pursued now. A VPN alone does not make the Windows EXE run on a Mac.

## Sources

- Godot universal export, ZIP permissions and signing: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html
- Apple first-launch approval: https://support.apple.com/en-au/102445
- Godot platform requirements: https://docs.godotengine.org/en/stable/about/system_requirements.html
- Browser WebGL, networking, input and persistence constraints considered: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html
