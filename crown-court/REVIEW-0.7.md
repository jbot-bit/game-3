# 0.7 sound and movement review

12 October 2026. The user's feedback stopped packaging of 0.6 and redirected this revision to sound, directional traction and ball continuity. The exact 0.6 executable and complete recordings remain the before evidence. Earlier 0.5 packages are preserved.

## Reproduced problems and repairs

- Ground acceleration was applied independently to X and Z. A diagonal reversal recovered 90% speed in .267 seconds versus .383 seconds on a cardinal axis. The new shared vector traction model starts immediately, takes .383 seconds to reach 90% running speed, and takes .417 seconds to stop the old direction in a full reversal. Reverse recovery to 90% is .783 seconds, with 1.806 metres of initial slide. Cardinal and diagonal measurements now agree. Analog walk speed, airborne acceleration, launch pads and dunk rules are retained. REFERENCE-0.7.md separates gameplay observation from these authored values.
- The feet stopped cycling at zero actual speed even with strong movement intent. The rig now distinguishes intended direction from momentum, keeps a brief running-in-place cadence and leans into braking. Matched before/after native frames and a ten-second actual-Sim reversal movie show the difference. The rig cannot change player physics.
- A genuine nearby catch moved the displayed ball 1.309 metres immediately to the carry point. The ball and both hands now share a 100 ms gather. The first displayed transition moves zero metres; quick catch-to-throw, Giant carry, dunks and resets have separate coverage. Possession still changes immediately on the host.
- A late 50 ms snapshot arriving after 83 ms rewound a forward-flying ball by .2667 metres. A bounded presentation offset removes that correction jump. It clears at ownership changes, resets and large relocations, and stops decaying when prediction reaches its age cap. A second regression caught and repaired a rewind after 200 ms snapshot starvation. Normal periodic delivery adds under .000002 metres of error in the controlled ballistic probe. This is not a promise of flawless motion on every connection.
- The former sound bank generated rising tones and repeated synthesized impacts. It is replaced by 21 short sample effects, with separate ball/body/rim/air categories, rotating variants, quiet steps/skids and per-event cooldowns. Important score and countdown cues have reserved voices. PCM validation and conservative simultaneous-peak calculation preserve digital headroom; acoustic quality is still subjective.

## Audio provenance and tool boundaries

Samples derive from [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds), [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) and [artisticdude's Swishes](https://opengameart.org/content/swishes-sound-pack). Their source pages identify CC0. Archives, source and transformed hashes, onset trims, filters and PCM measurements are recorded in assets/audio/manifest.json; credits are included with the executable. The original sources remain in build/crown-court-audio-v7.

Game Development Studio 1.5 capability discovery and doctor were run. Its installed package inspection/admission operations support 3D models, not WAV files; no audio validation is attributed to that CLI. The audio package instead uses ffmpeg decoding, a closed sample roster, PCM validation and copied-byte verification. No paid provider was used. tools/build_audio_bank.py reproduces the transformations from the retained archives.

## Acceptance boundary

Source tests and diagnostic captures establish the specific repairs above. The final exact-pack, native audio, complete match, network and extraction receipts belong in VERIFICATION.md. Normal-input automation is not household feedback or a physical-controller test. The no-extra-app public room service remains undeployed; a loopback room is not public internet proof.
