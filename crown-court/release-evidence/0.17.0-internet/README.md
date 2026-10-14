# Current internet release - 14 October 2026

The permanent Sydney relay is live at **wss://direct-metro.bnr.la/rooms**. Download the root Windows EXE or Mac DMG. Host online game; Find online game; click the host name. No user-entered address/code.

## Verified current packages

- Exact hashes: [current-packages.json](current-packages.json).
- Windows exported build: 76 packaged suites plus native controller/render/startup gates. See permanent-windows-packaged-tests.json and permanent-source-manifest.json.
- Permanent public relay: 42 family checks, including equipment, late join, rematch, reconnect and rewards (permanent-family.json). The fixture's inherited local-scope label does not describe routing for this run; the supplied endpoint was the permanent public WSS server.
- Full match: three native Windows processes using the exact Windows export and Mac game data completed 5-2 in about 334 seconds; all agreed on result/rewards, without live fixture mutations (permanent-full-match.json). This is not native Mac execution.
- Actual cross-platform internet: one Windows host in Australia and two native Apple-silicon Mac clients on a remote GitHub runner used the real menu, discovered the host by name, joined all three players and received live match snapshots. Both clients and the Windows host passed. This was a short connection/match-start test, not a full cross-platform match. [Run](https://github.com/jbot-bit/game-3/actions/runs/38528734125).
- Apple-silicon exported application signature, headless startup, graphical startup, public RPC and discovery passed. DMG was created on macOS and hdiutil verification passed.
- Intel macOS signature, headless startup, public RPC and discovery passed. **Default graphical launch timed out.** The sampled app thread was in Apple's software OpenGL vertex interpreter; explicit ANGLE failed to create EGL and fell back to that renderer. This is evidence of a hosted-VM rendering limitation, not proof that an unknown physical iMac works. [Failed run retained](https://github.com/jbot-bit/game-3/actions/runs/38528440171).

## Deployment

BinaryLane direct-metro.bnr.la, Sydney, Ubuntu 26.04, 1 vCPU/1 GB. Approved price A$5.39/month including GST. Caddy provides public TLS; the non-root relay container is restricted to loopback behind it, with read-only storage, memory/CPU limits and automatic restart. Public 443/80 allowed; SSH restricted to the administration address. Container/Caddy restart was checked and HTTPS health recovered. Saves remain local; the relay is stateless.

The subscription is ongoing until cancelled. Provider cancellation is immediate (within minutes), so it was not selected during play preparation. No persistent root SSH key was installed: automatic approval review rejected that separate action. Deployment used the existing authorized login.

## Limits and older evidence

The actual child's iMac model/macOS and household connection remain untested. Mac app is ad-hoc signed, not notarized, so Gatekeeper may require Open Anyway. No benchmark establishes smooth rendering on unknown hardware. Test profiles are isolated from household saves.

Earlier public-* and publication.json files describe the superseded temporary tunnel and ZIP distribution. They are retained as historical evidence, not current service status. The permanent-* / native-* / windows-mac-* receipts above apply to this deployment.

Public EXE/DMG downloads were anonymously fetched, hash-matched, and the downloaded Windows EXE launched natively. All 44 pre-existing save/settings files match the earlier baseline; four engine logs rotated or changed and are excluded from that claim. See permanent-publication.json. Public DMG mount/signature/native Apple-silicon startup is in public-installer-arm.json.

A follow-up is scheduled for 12 November 2026 to review the server before month two. This is a reminder, not provider cancellation.

The final public DMG also mounted and passed signature/headless execution on Intel. Its reduced-window graphical diagnostic still timed out; public-installer-intel.json preserves the failure. The normal-resolution graphical failure remains unresolved. The installer audit is https://github.com/jbot-bit/game-3/actions/runs/38529518574 . direct-windows-public-rpc.json is an earlier intermediate candidate, not the final shipped hash.
