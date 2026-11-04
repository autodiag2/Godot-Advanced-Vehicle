# Godot Advanced Vehicle
A more advanced car controller for the Godot game engine.

## Description
Custom rigidbody car controller with raycast suspension for the Godot game engine. This one is more realistic than the built-in vehiclebody with wheelcolliders.
This project will be a small demo of the vehicle physics i have been able to craft so far.

Features:
- RWD, FWD and AWD drivetypes available
- Pacejka and brush tire model available.
- Tire wear
- Fuel consumption using BSFC
- Choose between preloaded limited slip diff, open diff and locked diff/solid axle
- Manual clutch with adjustable clutch friction force
- Manual and automatic gearbox

This project would not have been possible without Wolfes written tutorial of his own car simulator physics. Also huge thank you to Bastiaan Olij for his vehicle demo. See the links in the Acknowledments section for more info.

## Controls
Keyboard:
- Arrow keys for throttle, brake and steering
- Space for handbrake
- A for upshifting and Z for downshifting
- c for clutch

Xbox controller:
- R2 for throttle and L2 for braking
- Left analog stick for steering
- A button for upshifting and X button for downshifting
- B button for handbrake
- LB for clutch

## Help
Make sure the physics FPS is set to atleast 120 or the physics start to get weird. In this project it is set to 240.

## License
This project is licensed under the MIT License - see the LICENSE.md file for details. This project also contains models and textures owned by their authors. See links below for exact licenses.

Engine sound sample found in /sounds folder is made with enginesound, available from https://github.com/DasEtwas/enginesound. The sound sample itself is licensed under cc0.

## Acknowledgments
* [Kenney car kit](https://www.kenney.nl/assets/car-kit)
* [Bastiaan Olij - Vehicle demo](https://github.com/BastiaanOlij/vehicle-demo/)
* [Wolfe, written tutorial of his GDSim vehicle physics](https://www.gtplanet.net/forum/threads/gdsim-v0-4a-autocross-and-custom-setups.396400/)
* [Racer.nl, Alot of great documentation about physics of racing sims](http://www.racer.nl/)

## Engine simulation

Every `CarParameters` resource can reference an exported `EngineParameters` resource. The included engine presets demonstrate petrol and diesel inline-four configurations. Geometry, firing order, compression ratio, intake/exhaust valve timing and sizing, fuel properties, combustion duration, injection timing, thermal boundary conditions, inertia, idle speed and rev limit are configurable.

The Godot-native thermodynamic solver now resolves the complete 720-degree four-stroke cycle for every cylinder at crank-angle substeps. It integrates cylinder mass and internal energy, derives pressure and temperature from the ideal-gas state, models compressible intake/exhaust valve flow, slider-crank volume and indicated piston work, and includes wall heat transfer using a Woschni-style correlation. Petrol combustion uses a Wiebe heat-release function; diesel uses timed fuel injection with separate premixed and diffusion burn fractions. The resulting indicated torque pulses drive the existing clutch, gearbox, differential and wheels. The existing BSFC maps continue to control fuel use.

The HUD **Engine** button opens a separate `engine_bubble.tscn` scene. Its 3D cutaway exists only inside a dedicated `SubViewport` owned by the popup: the car's world scene is not modified. The cutaway animates pistons, connecting rods, valves and crankshaft, with per-cylinder flame, glow and smoke particles. The slider changes global simulation time from 1.00x to 0.01x.

This is a real-time, single-zone zero-dimensional thermodynamic model, not a multi-dimensional CFD solver. The gas state is spatially uniform within each cylinder, and combustion chemistry, turbulence, spray breakup, knock and exhaust after-treatment are represented by tunable submodels rather than resolved in detail. The implementation was informed by the MIT-licensed [AngeTheGreat Engine Simulator](https://github.com/ange-yaghi/engine-sim) and classical 0-D first-law engine-cycle methods; the C++/SDL application is not embedded as a Godot runtime dependency.
