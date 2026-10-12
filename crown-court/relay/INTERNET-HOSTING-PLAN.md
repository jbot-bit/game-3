# Crown Court Internet hosting preparation

Prepared 12 October 2026. **Prepared only: user explicitly declined deployment on 12 October 2026. Nothing has been created, built, uploaded or deployed.** The existing relay and Fly template are sufficient; this preparation changes no game or server behavior.

## Proposed service and cost

Use one always-running Fly Machine in Sydney (`syd`), shared CPU, one vCPU, 256MB RAM. No second Machine, remote builder, database, volume, dedicated IPv4 or custom domain is proposed. Candidate app name: `crown-court-jbot-rooms`, **unreserved**. The account/organization is not yet selected. Sydney is listed in [Fly regions](https://docs.fly.io/reference/regions/); proximity does not establish household latency.

The live Sydney calculator selected shared CPU / 256MB and displayed **US$2.79/month**. The current rate calculation is `8.465e-7 × 2,592,000 × 1.269230769 ≈ US$2.7849` for 30 days. A 31-day month is about US$2.88 compute. Sources: [Fly calculator](https://fly.io/calculator/), [Fly pricing](https://docs.fly.io/about/pricing).

Oceania Internet egress costs **US$0.04/GB**; inbound traffic is free. Shared IPv4 and IPv6 are free; the first ten single-hostname TLS certificates are free. There is no platform fee. These assumptions use the standard current pricing, with no credit or legacy allowance deducted. See [Fly pricing](https://docs.fly.io/about/pricing).

Budget **0.3GB of egress per active hour for one three-person room**. This is a conservative planning assumption, not measured household traffic or a capacity test. It covers all relay outbound traffic, including forwarded inputs, snapshots and overhead. Concurrent rooms multiply traffic.

| One room, per 30 days | Assumed egress | Compute + egress |
| --- | ---: | ---: |
| No play | 0GB | US$2.79 |
| 40 hours | 12GB | US$3.27 |
| 100 hours | 30GB | US$3.99 |

The table budgets compute at the calculator's US$2.79 displayed estimate rather than subtracting the sub-cent difference in the rate calculation.

**Recommend a US$5/month planning budget. This is not an enforced cap.** Taxes, AUD conversion, card FX fees, actual traffic and 31-day billing can change the total. Reconfirm pricing and account-specific billing before approval. Paid replicas, bigger RAM, private cross-region traffic and optional services are outside this estimate.

## Local deliverable and evidence

Run `./prepare-hosting.ps1` from this folder to create a fresh staging directory and ZIP under `C:/game-3/build`. The script performs only local filesystem operations and verifies ZIP names and file SHA256s against a manifest.

The ZIP contains exactly `.dockerignore`, `Dockerfile`, `package.json`, `package-lock.json`, `server.mjs`, `THIRD_PARTY_NOTICES.txt`, this plan, generated `fly.toml`, and `manifest.json`. It excludes the game, other repository source, tests, `node_modules`, credentials and Git metadata. The existing Docker context allowlist admits only its Dockerfile, locked dependency manifests and relay server; the image copies the locked manifests and server. Container upload need not publish repository source to public Git.

Retained local relay verification: six unit tests passed, including room isolation, opaque routing, bounded queues and refusal of public plaintext; lifecycle checks passed for full-room errors and host departure reaching both clients. Receipts are `build/crown-court-evidence/v11-hosting-relay-unit.log` and `v11-hosting-relay-lifecycle.log`. These prove local relay behavior, not public WSS or separate-home play.

The Docker CLI exists but its daemon is unavailable here; Fly CLI is absent. The container has not been built. After approval, use a working local Docker engine and install the official Fly CLI locally; do not substitute a billable remote builder. The selected organization, app-name availability and deployed capacity remain unknown.

## Exact reviewed deployment sequence — only after approval

Approval must cover Fly, the selected organization, the app name, and the estimated recurring spend above. Do not run this section during preparation.

Extract the verified ZIP into a new folder and enter that folder. Confirm its files against `manifest.json`. Start the local Docker engine and obtain the official Fly CLI if needed. Then run:

```powershell
docker version
fly version
fly auth login
fly orgs list
```

Choose the explicitly approved organization slug. The placeholder below must be replaced before proceeding; the candidate app name must be available or reapproved.

```powershell
$FlyApp = 'crown-court-jbot-rooms'
$FlyOrg = 'REPLACE_WITH_APPROVED_ORGANIZATION_SLUG'
if ($FlyOrg -eq 'REPLACE_WITH_APPROVED_ORGANIZATION_SLUG') { throw 'Select the approved Fly organization first.' }
fly apps create $FlyApp --org $FlyOrg
fly ips allocate-v4 --shared --app $FlyApp
fly ips allocate-v6 --app $FlyApp
fly deploy --config fly.toml --app $FlyApp --local-only --ha=false --no-public-ips
fly machine list --app $FlyApp
fly status --app $FlyApp
Invoke-RestMethod "https://${FlyApp}.fly.dev/healthz"
```

`--local-only` uses the local Docker daemon; `--ha=false` disables spare Machines; `--no-public-ips` prevents deployment from adding an unreviewed IP after the explicitly allocated free addresses. References: [Fly deploy](https://docs.fly.io/flyctl/cmd/fly_deploy), [app creation](https://docs.fly.io/flyctl/cmd/fly_apps_create), [shared IPv4 allocation](https://docs.fly.io/flyctl/cmd/fly_ips_allocate-v4).

Verify exactly **one** Machine in `syd`, shared CPU / one vCPU / 256MB, and no volumes or added services. Record the deployed image digest, source manifest and release revision. The existing `node:24-alpine` base tag is mutable; record the actual resolved base digest during the approved local build. The existing template keeps the relay backend on internal port 8080 behind Fly HTTPS, with trusted TLS termination and `/healthz` checks. Do not expose backend port 8080 directly.

The proposed game endpoint is `wss://crown-court-jbot-rooms.fly.dev/rooms`, **pending deployment and verification**. Verify certificate/hostname, actual WSS room creation, three-client joins, wrong-version/full-room errors and host departure on that endpoint. Only then coordinate embedding the verified endpoint in the next game executable. No endpoint is embedded by this preparation.

Complete an actual match from separate homes using the same released executable before claiming Internet play works. Inspect movement, catch/pass/throw/dunk, result, disconnect/rejoin and TCP stalls. One Machine has no failover; restarts invalidate rooms. Maintain it when rooms are empty and review real memory/egress/billing before adding capacity.

Approval prompt: **“Approve Fly hosting in the selected organization, one Sydney shared-CPU 256MB Machine named crown-court-jbot-rooms, with a US$5/month planning budget plus tax/FX; deploy the reviewed relay bundle and verify WSS before embedding the endpoint.”**
