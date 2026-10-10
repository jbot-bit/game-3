# KayKit crew source

Publisher: Kay Lousberg / KayKit Game Assets.

Official repository: https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0

Pinned publisher commit: `672074b73ba276876a19e8816ecdc5241817ab47`.

Downloaded 2026-10-10 from the official repository, not an asset aggregator.
The adjacent `LICENSE.txt` is the publisher's original CC0 licence. It explicitly
permits personal, educational and commercial use and does not require credit.

| Local file | Publisher path | SHA-256 |
| --- | --- | --- |
| Rogue.glb | addons/kaykit_character_pack_adventures/Characters/gltf/Rogue.glb | E825437CD4D2EE9C1960B517A74A69101E33EB409AE7FA8CEDC7134A998FBB7D |
| LICENSE.txt | LICENSE.txt | AE322141814056DDA0DEEA7540D74C41D87AEE1DA319977CD1BD84EE5A923629 |
| Rogue_rogue_texture.png | Embedded GLB texture; identical to Characters/gltf/rogue_texture.png | A4032E877C3B91939F5CDBB630349C1998FDBC3211BBD587C111125500FE4CC5 |

`Rogue.glb` is retained byte-for-byte, including its embedded palette texture.
Godot's normal importer extracted the adjacent PNG without changing its pixels.
`AnimatedCrew` removes the five weapon meshes and cape at instantiation, leaving
six skinned body meshes. It selects eleven gameplay animation variants from the
publisher's authored clips. Carry variants retain authored leg motion and hold
the arms in a mirrored sampled support pose. The original files are not rewritten.

`crew_palette.gdshader` is original project code. It recolours only the source's
two green cloth ramps, preserving skin, eyes, hair, belt and boots. This keeps
crew identity colours and the existing earned outfit IDs without adding assets,
inventory items or rules.
