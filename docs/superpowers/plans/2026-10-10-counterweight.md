# Counterweight Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans for bounded tasks. Ownership below separates concurrent edits.

**Goal:** Ship a second short cooperation course without breaking controls, saves or LAN play.

**Architecture:** A new world script extends the existing course's geometry/prop helpers. A tiny course metadata file provides IDs/names; main owns world selection and authoritative transitions. Saves retain their existing schema and exact-once run semantics.

**Tech Stack:** Godot 4.7.2, GDScript, built-in Jolt, ENet, Compatibility rendering.

**Spec:** `docs/superpowers/specs/2026-10-10-counterweight-design.md`.

## Global constraints and review focus

- Existing controls, five powers, host save and three-player LAN remain intact; no new dependencies or gameplay systems.
- Geometry must support solo replacement of the helper; three-player mass and moved props must not strand the crew.
- Only completed host runs can advance; clients, incomplete runs and failed saves cannot bypass this.
- Old held joints, old snapshots and late joins must not corrupt a course transition.
- Menus remain readable at 960×540; measure native performance with other test engines stopped.

## 1. Course physics (second_course agent)

- [x] Implement `party_counterweight_world.gd` extending `party_world.gd`, preserving `spawn_point`, `checkpoint_contains`, `goal_contains`, `wind_at`, `switch_position`, seven prop IDs and capture/reset APIs. Add `intro_text()->String` for the one concise course hint.
- [x] Prove weight/hand effects using real contacts, then prove approachable solo and crew traversal/recovery with focused probes. Inspect an actual rendered view; simplify any unreliable puzzle before adding mechanics.

## 2. Course selection and transition (parent)

- [x] Add `party_courses.gd`: IDs `crossing`/`counterweight`, `valid`, `course_name`, `next_id` helpers. Preserve the existing world factory default.
- [x] Write failing lifecycle tests for second-course hosting, completion-only/host-only advancement, save failure, replay, stale snapshots and client reconstruction. Implement state `course_id`, `course_name`, `next_course_name` and host `next_course` action.
- [x] Extend the real three-process probe to advance and complete both courses, preserve saved power choices, replay, reconnect and reject stale poses. Record explicit positioning fixtures.

## 3. UI (course_ui agent)

- [x] Preserve `host_requested(name)`; expose `selected_course_id()->String`. Initial host menu selects course; live state supplies the displayed course title.
- [x] Add `next_course_requested()`, completion-only Next course, existing Play again/Retry save and host-only pause Restart course. Test actual button signals and small-viewport fit.

## 4. Review and release (parent + independent reviewer)

- [x] Review course usefulness/softlocks and lifecycle code, with repros for material findings.
- [x] Run focused regressions and both-course network checks; inspect rendered UI and measure final Counterweight three-puppet frame times.
- [x] Export 0.2.0 with the added runtime scripts explicitly checked by the builder; run exact-pack network checks and actual-EXE smoke tests.
- [x] Update current README/handover/status with measured evidence and remaining limits; preserve previous build and commit the complete local change. No public upload.
