# Internet release verification - 14 October 2026

Temporary free public WSS service is active. The Windows ZIP contains the unchanged 0.17.0 executable and adjacent endpoint config. The universal Mac ZIP embeds the same endpoint.

- Public RPC: Windows game data as host, final Mac exported data as both peers; five channels, identities, shared result and departures passed.
- Public family suite: 42 checks passed, including roster, equipment, rematch and reconnect.
- Public ordinary-input match: three clients completed a 307-second match; all agreed on 1-0, winner 0, and one correctly awarded reward bag. No live-state fixture mutations. Package hashes remained unchanged.
- Archive checks: ZIP integrity, unchanged Windows executable, both Mac CPU architectures, executable permissions and signature structure passed. This is not Apple signature verification.
- Every automated game process used an isolated profile. Household saves were not used.

The public clients ran on the same Windows PC through the public TLS endpoint. Native Mac execution and actual separate-household connectivity remain unverified. The Mac app is ad-hoc signed, not notarized.

An earlier completed public match used the first Mac export; its host test process waited for a video fixture that this run does not supply and was stopped after recording the result. The external test wrapper now exits after peers have time to finish; the final exact-package run exited normally. This was a harness teardown change, not a game change.

The relay and tunnel must stay running on Dad's awake, online PC. The tunnel address changes on restart. No paid server has been purchased. See the root CROWN_COURT_INTERNET.txt for play instructions and individual JSON files here for exact evidence.
