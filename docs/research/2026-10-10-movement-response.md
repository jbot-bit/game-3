# Hands Full movement response

10 October 2026. Complaint: pressing a direction takes too long to produce movement.

## Diagnosis and change

The old motor added horizontal velocity to just the torso, then damped that same body every tick. Nine joint-connected bodies had to catch up. The host also sampled its own controls at the 30 Hz network-send cadence despite simulating at 60 Hz. The motor delay was substantially larger than that extra input wait.

The new motor uses mass-weighted whole-body horizontal velocity. It applies one bounded velocity change to all ten bodies, retaining their relative motion and vertical velocity. Ground targets are 5.5 m/s, or 6.875 m/s for Swift; acceleration is 45 m/s² and braking/reversal is 65 m/s². Air steering is limited to 10 m/s² along the requested direction, without no-input braking or cancelling a faster grapple launch. The host samples each physics tick. Client send rate, authoritative physics, collision shapes, joint settings and shared presentation timeline remain unchanged.

The existing PhysicalBone velocity-update architecture is retained. This is a measured local motor correction, not a claim that writing velocity outside `_integrate_forces` is Godot's preferred general rigid-body architecture.

## Measured response

The same isolated flat Jolt fixture injects physical-key events through `Input.parse_input_event`, then uses the ordinary `main.gd` input poll and session path. Tests were written and failed against the old motor before implementation. These are simulation response times, not physical keyboard-to-photon measurements.

| Measurement | Old motor | New motor |
|---|---|---|
| First 0.1 m displacement, Grip / Heavy / Swift | 183 / 233 / 167 ms | 67 / 67 / 67 ms |
| Grip torso speed after 200 ms | 0.58 m/s | 5.26 m/s |
| Direction reversal, Grip / Heavy / Swift | Did not reverse within 600 ms | 100 / 100 / 117 ms |
| Release to torso speed below 0.3 m/s | 717 / 333 / 433 ms | 250 / 183 / 183 ms |
| Host command delivery | 17–33 ms | 17 ms |

Evidence: `logs/movement-response-before.json`, `movement-response-after.json`, and `movement-response-native.json`. The native run repeats the numerical results with Windows/OpenGL rendering and passes 24 checks. Frame timing in this input probe includes startup. The separately warmed movement-only sample is in `logs/movement-native-performance.log`: three physical puppets, seven props, 1280×720 on the RTX 4070 Laptop GPU, 10 seconds, p95 3.525 ms, maximum 4.817 ms, zero frames above 16.7 ms. The later visual overhaul has its own current performance record in `HANDS_FULL_STATUS.md`. These results do not characterize slower PCs or real Wi-Fi.

## Research used

- [Godot: mouse look and physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/advanced_physics_interpolation.html#mouse-look): sample keyboard movement with physics and mouse look per rendered frame. The unnecessary host 30 Hz input gate was an application-level delay.
- [Godot: PhysicalBone3D](https://docs.godotengine.org/en/stable/classes/class_physicalbone3d.html#class-physicalbone3d-private-method-integrate-forces): use `_integrate_forces` for precise continuous control; frequent external velocity writes deserve caution. The shared bounded motor is a project-specific hypothesis verified in actual Jolt tests, not a prescribed Godot recipe.
- [Godot: jitter, stutter and input lag](https://docs.godotengine.org/en/stable/tutorials/rendering/jitter_stutter.html#input-lag): distinguish frame pacing, physics presentation and input latency. Native rendering was measured rather than assuming the slow start was GPU lag.
- [Gabriel Gambetta: client-side prediction and reconciliation](https://www.gabrielgambetta.com/client-side-prediction-server-reconciliation.html) and [entity interpolation](https://www.gabrielgambetta.com/entity-interpolation.html): authoritative remote controls retain round-trip and presentation-buffer delay. Prediction/reconciliation for ten colliding bones is a separate networking change; this patch improves the motor for host and clients without mixing predicted and authoritative joint state.

Desktop-control tooling failed to start because of its sandbox kernel error. Verification therefore uses native rendered, scripted input playthroughs and image inspection. No hands-on human playtest or three-physical-PC result is claimed.
