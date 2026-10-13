# Client wall prediction review - 0.15

A wall stopped player position but left outward velocity intact. The new test reproduced 48 failures across four walls, three snapshot ages (1/60, 0.05 and 0.08 seconds), and running, sliding, airborne and stunned states. Matching the authority fix, local traction now resolves wall contact during each prediction substep. Other extrapolated player copies also remove blocked outward velocity before rendering. The incoming snapshot remains immutable.

Final tests/client_wall_v15.gd passes 128 checks: the original cases, substep departure parity with real authority, remote tangent preservation, inward escape and snapshot immutability. Existing client_ground_prediction, client_slide_prediction, hazard_prediction, snapshot_recovery and deck_edge_prediction also pass. Logs: v15-client-wall-before, v15-client-wall-final and v15-source-* under build/crown-court-evidence. All launches use harness.ps1 with isolated profiles.

This verifies local forecasting and delayed-snapshot presentation. Physical household networking and controller comfort remain separate from automated evidence.
