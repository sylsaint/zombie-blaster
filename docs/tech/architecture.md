# Technical plan

Starting point for a portrait lane shooter (向僵尸开炮 style) on low-end Android. Godot 4.7.2, GDScript, Compatibility renderer. Design docs are not written yet; nothing below is a gameplay system, and numbers are budgets to profile against, not tuned values.

The greybox only has a lane, a fixed rear-top camera, and a placeholder that maps horizontal drag into clamped X (`scripts/lane_motion.gd`). Squads, gates, and hordes come later and should reuse that X mapping.

## Renderer

Compatibility (`gl_compatibility` on desktop and mobile) is deliberate. The Mobile/Vulkan renderer has real decals and a cleaner clustered lighting path, and it is a bad default for the weak GLES devices this genre still ships to: driver crashes and device coverage cost more than the missing features.

Consequences to design around:

- No compute shaders. Skinning and culling stay on the CPU or in the vertex shader.
- No `Decal` node. Blob shadows are quads (one MultiMesh), not decals. The greybox already does this for the player.
- No SDFGI, SSIL, SSAO, or volumetric fog. Leave them off.
- Shader baker does not run on this renderer. The Android preset keeps it disabled.
- MSAA stays off. The 3D render resolution is the quality knob (see stretch below), not extra fullscreen passes.

## Resolution and camera

Base viewport is 1080×1920, stretch mode `viewport`, aspect `keep_width`.

`canvas_items` would leave the 3D buffer at the phone's native size, so a 1440×3200 device renders far past the triangle budget. `viewport` renders into the design resolution and scales up. `keep_width` holds the lane at 1080 design pixels. Taller phones (most of them, past 9:16) gain vertical view instead of shrinking the steering width. `expand` is close, but it can also grow width on shorter, wider windows; the lane width should stay the authored constant.

The camera sits behind and above the lane, looking down -Z, and stays on X = 0. The squad moves across the frame so a half-width gate is readable. "Chase" here means the rig follows the squad along Z once the level advances, not that it recenters X. A soft X follow that still keeps both rails on screen is optional later; a hard follow hides the gates.

Portrait is a project setting (`display/window/handheld/orientation`), which the Android exporter reads. It is not duplicated in the export preset.

Desktop play uses a 540×960 window and emulated touch-from-mouse, so drag testing does not need a device.

## Squad and lane

One anchor transform. Horizontal input only changes anchor X, via `LaneMotion.apply_drag`: a drag across the full viewport width crosses the full lane, then X is clamped to the rail inset. The body radius has to fit inside that inset (greybox: half-width 3.0, rails at ±3.75).

Soldiers are visual offsets around the anchor, not separate bodies. Adding a soldier rebuilds the offset list and the MultiMesh instance count. They fire from the anchor; weapon level changes the pattern and damage record, not the number of physics objects.

Z advance is a level speed on the anchor (or a world scroll). The greybox does not advance. When it does, the camera's Z follows the anchor with a fixed offset.

## Gates

Author gates in a level resource, sorted by Z: position, X range (full lane or one side), and an effect id (`add_soldiers` or `set_weapon`). Each frame, test the squad anchor against the next untriggered gate only. Trigger when Z crosses the gate plane and X overlaps the gate's span. Mark it used.

That is an AABB test against one record. No `Area3D`. Gate meshes are few, so ordinary `MeshInstance3D` nodes are fine; pool them only if a level streams more than a handful.

## Horde spawning

Levels are a Z-sorted event list: at distance D, spawn N of an archetype, or a boss. The spawner wakes when the anchor approaches D, pulls instances from a pool, and sets their Z ahead of the squad. Enemies walk toward the squad (decreasing Z). Anything that passes behind the camera returns to the pool. Do not `instantiate` or `queue_free` inside the combat loop. Prewarm pools at level load and free them at unload.

Cap concurrent grunts so the triangle budget holds (see below). Elites and the boss are explicit events, not part of the grunt cap.

## Hundreds of enemies

Triangle count and draw calls are separate problems. MultiMesh fixes draws, not triangles.

**Grunts: one `MultiMeshInstance3D` per mesh variant** (walker, crawler, …), shared material, shared palette texture. Per-instance color, hit flash, and animation frame live in `INSTANCE_CUSTOM`. Do not give each grunt a `Skeleton3D`. A few hundred skeletons will miss frame time on low-end Android even when the GPU is fine. Vertex-animation textures (VAT) in the vertex shader sample a position/normal texture by vertex id and by the frame stored on the instance. Compatibility can do that sample; it cannot do compute skinning. CPU writes instance transforms each frame. For a few hundred rows, `MultiMesh.buffer` bulk upload is the path if per-call `set_instance_transform` shows up in a profile.

**Elites:** same pipeline, separate MultiMesh, higher triangle mesh. Do not special-case them into physics bodies.

**Boss:** one character. A single `Skeleton3D` is cheap and easier to animate if the boss needs authored clips. Prefer VAT only to keep the pipeline uniform. This is the one place a skeleton is acceptable; the failure mode is N skeletons, not one.

**Shadows:** one pooled MultiMesh of blob quads on the ground plane, same count as visible bodies, unshaded alpha-scissor or a cheap blended disc. Not a `Decal`, and not `DirectionalLight3D` shadows.

**Movement and hits:** store `{x, z, radius, hp}` in a packed array. A spatial hash (cell size around one body diameter) answers "what is near this bullet". Bullets are another small pool, same idea. Godot's physics broadphase plus a `CharacterBody3D` or `Area3D` per zombie will not survive a wave; signal traffic and the physics tick dominate before the GPU does. Navigation agents are the same trap. The lane is a narrow corridor, so a hash plus a Z sort is enough. Separation is a few neighbor pushes inside the hash, not avoidance agents.

**Draw-call budget:** aim for well under 100 world draws on a low-end GPU. Grunts, elites, blobs, and bullets should be a handful of MultiMeshes. Individual nodes are for the squad anchor, gates, and the boss.

## Hit feedback

All of this is data on shared objects. None of it clones materials.

- **Hit-stop:** freeze a gameplay clock for about 2–4 frames (roughly 30–70 ms). Do not set `Engine.time_scale`. That also freezes UI and makes the hit feel like a stall. Tweens and the camera shake read the real delta; movement, VAT frame advance, and bullets read the gameplay clock.
- **Screen shake:** offset on a camera rig, trauma that decays. The look target stays on the lane center. One shaker, not one per enemy.
- **Flash and dissolve:** write flash and dissolve into instance custom channels. The shared shader mixes albedo toward a flash color and discards pixels with `ALPHA_SCISSOR` / `discard` once dissolve passes a threshold. Alpha clip stays in the opaque pipeline, so the batch does not split and transparent sort never runs. Per-enemy `material_override`, `set_shader_parameter` on a unique material, or blend transparency will break batching and should not be used for crowds.
- **Squad hit:** the squad is one small mesh group. A single parent shader parameter is fine there because it is not instanced by the hundred.

## Glow and lights

One unshadowed directional light plus ambient color. No real-time shadow maps.

"Light glow only" means no ambient occlusion and no full-screen glow as a default. Compatibility glow is a fullscreen blur and burns bandwidth on low-end GPUs. If a pickup or muzzle needs a glow read, use a small additive unshaded quad in the VFX MultiMesh. Turn the engine glow buffer on only after a device profile says the additive quads are not enough.

## Triangle budgets

| What | Starting budget |
| --- | --- |
| Grunt | 300–500 tris |
| Elite | ≤ 1500 |
| Boss | ≤ 5000 |
| On screen | ≤ 150k |

These count the mesh, not the draw. At 500 tris, 150k is 300 grunts before elites, the boss, the squad, and gates. A wave that wants 400+ bodies should target the low end (~300) or the spawner cap should stay near 250 grunts plus a few elites. Profile on a low-end arm64 device before raising either number. Overdraw from overlapping transparent blobs counts too; keep blob quads small and prefer alpha clip if the soft edge is not worth the fill rate.

## Android export

The committed preset `Android` is an arm64 APK, package `com.zombieblaster.game`, Gradle off, shader baker off, immersive mode on. No keystore path and no passwords are in `export_presets.cfg`. Signing secrets go in `.godot/export_credentials.cfg` (gitignored) or `GODOT_ANDROID_KEYSTORE_*`.

arm64-only matches Godot 4.7's default: Play requires 64-bit, and the weak phones this renderer targets are still overwhelmingly arm64 in 2026. Enable `armeabi-v7a` only when a real 32-bit device is on the QA list. An AAB for Play needs `gradle_build/use_gradle_build` later; that generates `/android`, which is gitignored.

## What is intentionally absent

Level resources, pools, MultiMesh crowds, gates, weapons, rewards, and meta progression. `docs/design/` is empty on purpose. Build those against a written design, using the budgets above as the constraint.
