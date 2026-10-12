# Crown Court 0.13.0 verification

12 October 2026. Godot 4.7.2, Windows Compatibility renderer. The recovered 0.12 source and character authoring files were saved in commit 935da3c0cca8d791893f79e0e646e4ba827bff1f. This release preserves Dad, Evie, Tyler, equipment and unlocks while improving momentum, recovery, feedback and camera clearance.

## Exact playable artifacts

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| CrownCourt.exe | 113517848 | CBB41A0C046284751D7BEAC636B6AC56ADEE335997C85B9904314049D19750C1 |
| CrownCourt32.exe | 125847600 | 447D3988AC1078F37A34C5364F854679C264FFAF0F5C17811958398D14642109 |

Both identify as 0.13.0 and start independently with isolated test saves. The runtime source manifest matches the final export. Full machine-readable results: [VERIFICATION-0.13.json](VERIFICATION-0.13.json).

## Movement and presentation

A controlled replay against the 0.12 pack and new source measured post-impact ground travel increasing from 2.521 to 3.858 units and stopping time from 0.967 to 1.183 seconds. Straight and diagonal travel now agree within 0.00003 units. Dives retain momentum into a bounded recovery, with gradual steering/traction; running release has a brief coast. Simulation, local prediction and receiver forecasting share the recovery motor. See [KNOCKBACK-0.13.md](KNOCKBACK-0.13.md).

Recovery poses, hand/ball anchors and family identities pass regression checks. The camera now avoids stadium walls and extends smoothly after clearance; the existing deck-descent regression measured a maximum 0.312-metre frame step, down from the initial candidate's failing 3.638 metres. Scorer, tie, lead and winning-basket feedback plus restrained clock/Hype cues pass native integration checks. [Inspected images](release-evidence/0.13/README.md) and [REA/Game Development Studio evidence limits](POLISH-0.13.md).

## Final executable checks

62 embedded x64 regression suites and 17 x86 suites pass. Native x64 arena, input, audio, controller-event, ordinary-input route and standalone startup checks pass. The obsolete native celebration assertion was updated from the former bare +1 to the intended scorer and winning-basket text, then the package was rebuilt and all packaged checks repeated.

Three independent local processes (32-bit host, 32-bit client, 64-bit client) pass the physical action checkpoints. The final family network check passes 42 registration, appearance, late-join/rejoin, team and round-transition checks.

A complete recorded three-client family match against three bots finishes with score {"0":5,"1":2}. All clients agree on score, winner, match identity, family equipment and rewards. The rendered view uses ordinary InputEvents; the other drivers submit ordinary gameplay inputs. No fixture mutation is allowed. 1852 frames span 327.09 seconds. Recording: build/crown-court-evidence/v13-confirmed-match/joined-client.mp4, SHA-256 A6F3E80FE64CE5D7BC01454D0BDEB06129B121B7E161AFA228831C74C7CFB8D9. The recording includes 1 automatic focus recovery; it is not described as uninterrupted human play. This recording has no audio; native audio playback is checked separately.

## Scope and limits

Tests use isolated profiles and preserve household saves. Local clients are not physical three-PC, physical controller or WAN evidence. Human enjoyment remains unverified. These are authored mechanics informed by references and feedback; original Fall Guys/Crown Jam constants were not extracted. The REA Windows process probe reported capability unavailable; this is recorded rather than presented as a successful probe. Game Development Studio verified retained controlled camera captures, not a performance benchmark.

Internet hosting remains undeployed, with no public relay enabled. The prior [0.11 verification](VERIFICATION-0.11.md) is retained as historical evidence. Publication is verified separately by matching remote commit and fresh public-download hashes.