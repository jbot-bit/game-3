# PiCode active puppet foundation

- Source: https://github.com/PiCode9560/Godot-4-Active-ragdoll
- Revision: `e762f613ddb4e5a93cfeeace6430b7c3d21309b6`
- Author: PiCode9560; MIT license retained in `LICENSE`.
- `Character.glb` is copied from `Godot 4 Active Ragdoll/Assets/Character.glb`.
  SHA-256: `81f7ef328b1ba047764151fc67abcceb26b21e055e1ecfc3c8697d885864ff2f`.
- `../../puppet.tscn` adapts the source `Scenes/character.tscn`: resource paths
  rebased, stale source UIDs removed, upstream camera/input connections removed.
- `../../puppet.gd` adapts the source movement, spring and grabbing approach.
  It accepts per-player controls, simulates only on the host, tests current hand
  contacts, uses explicit limp state, supports five bounded power modifiers,
  and reconstructs remote skeleton poses from physical-body offsets.
- No upstream demo map, checker textures, camera script, or save data is shipped
  as part of this puppet asset.

Local compatibility evidence: original source demo ran on bundled Godot
4.7.2 with both GodotPhysics3D and built-in Jolt. This is a prototype foundation,
not a claim of production multiplayer or Human Fall Flat-equivalent quality.
