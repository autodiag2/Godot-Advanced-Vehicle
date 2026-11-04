# Mountain Race World for Godot 4.6

## Installation
1. Copy `mountain_race_world.gd` and `mountain_race_world.tscn` into your Godot project's `res://assets/world/mountain_race/` directory.
2. In `WorldSim`, select `mountain_race_world.tscn` as the world scene.
3. The scene creates the terrain, road, collisions, guardrails, scenery, lighting, atmosphere, and `VehicleSpawn` at runtime.

## Included
- Closed mountain road with elevation changes and smooth Catmull-Rom corners
- Mesh terrain with static trimesh collision
- Road surface with static trimesh collision
- Gravel shoulders, edge lines, dashed center line
- Guardrails on exposed edges with collision bodies
- VehicleSpawn marker and start/finish arch
- Trees, rocks, cones, roadside markers, sector boards
- Directional lighting, procedural sky, fog, ambient lighting

## Performance optimizations
Terrain vertex heights are evaluated once per grid point and reused for adjacent triangles. A 16 m spatial hash accelerates the local track-distance queries used by terrain blending and scenery placement; it searches neighboring cells only where the existing thresholds are at most 13 m.

Repeated tree, rock and guardrail meshes are rendered with `MultiMeshInstance3D` batches grouped into 48 m spatial cells. Explicit per-cell visibility bounds retain local frustum culling. Original mesh shapes, dimensions, transforms, materials, procedural placement and counts are retained. Guardrail collision remains attached to each original segment, so the collision layout is not simplified or merged. The road, shoulders, markings, terrain, lighting, water and scenery design are unchanged.

These changes target world-generation CPU work and rendering submission overhead. FPS and startup-time improvements still need measurement in the Godot runtime on target hardware.

## Notes
The scene is generated procedurally at runtime. It is intended as a detailed starting point and should be profiled on target hardware. It uses a mesh-based terrain and road collision, not a hand-authored heightmap. Test vehicle clearance and collision layers with your existing `BaseCar` setup. Adjust `TRACK_POINTS`, `TRACK_WIDTH`, and `TERRAIN_SIZE` near the top of the script to change the course.
