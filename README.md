# Godot Advanced Vehicle
A more advanced car controller for the Godot game engine.

## Description
Custom rigidbody car controller with raycast suspension for the Godot game engine. This one is more realistic than the built-in vehiclebody with wheelcolliders.
This project will be a small demo of the vehicle physics i have been able to craft so far.

Features:
- RWD, FWD and AWD drivetypes available
- Pacejka and brush tire model available.
- Tire wear and temperature monitoring for each wheel, with individual and all-wheel replacement controls
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

Touchscreen:
- Touch and hold within the fixed 3× joystick area around its original position for 0.10 seconds to relocate it; the joystick remains inside this original movement area, and its new position persists as its resting position. Dragging from the area before the hold completes also relocates the joystick and immediately steers from that point.
- With an automatic gearbox, holding the joystick down brakes forward motion and selects reverse once the car is nearly stopped; the joystick then operates in reverse (down accelerates, up brakes). Holding it up while reversing brakes to a near-stop and selects first gear again. Manual gearboxes keep the same direction-dependent joystick mapping for a manually selected reverse gear, but never change ratios automatically.

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

Every `CarParameters` resource can reference an exported `EngineParameters` resource through its `engine` property. The included petrol and diesel presets default to four cylinders. Set `cylinder_count` in the referenced `EngineParameters` resource to use any positive cylinder count; this is configured in the car/engine resources, not through the in-game GUI. Set `firing_order` to a permutation of the cylinder numbers, or leave an invalid/mismatched order for evenly spaced firing offsets. Geometry, firing order, compression ratio, intake/exhaust valve timing and sizing, fuel properties, combustion duration, injection timing, thermal boundary conditions, inertia, idle speed and rev limit are configurable.

The Godot-native thermodynamic solver now resolves the complete 720-degree four-stroke cycle for every cylinder at crank-angle substeps. It integrates cylinder mass and internal energy, derives pressure and temperature from the ideal-gas state, models compressible intake/exhaust valve flow, slider-crank volume and indicated piston work, and includes wall heat transfer using a Woschni-style correlation. Petrol combustion uses a Wiebe heat-release function; diesel uses timed fuel injection with separate premixed and diffusion burn fractions. The resulting indicated torque pulses drive the existing clutch, gearbox, differential and wheels. The existing BSFC maps continue to control fuel use. The engine speed is clamped to its configured idle RPM while fuel is available, so collision loads can pull RPM down to idle but do not stall or stop the engine. Front-body contact impulses are reflected through the selected gear ratio and clutch coupling to reduce crankshaft speed.

The round **Engine** and **Simulation speed** touch icons sit beside the menu icon and open their respective popup windows. A generated cockpit dashboard at the bottom of the game view replaces the old text-only vehicle telemetry panel and displays live RPM, fuel percentage, speed and selected gear. The **Engine** icon opens a separate `engine_bubble.tscn` scene. Its 3D cutaway exists only inside a dedicated `SubViewport` owned by the popup: the car's world scene is not modified. The cutaway animates pistons, connecting rods, valves and crankshaft. Each cylinder has its own procedural combustion-flow volume and shader material: a red-orange turbulent flame expands through the changing chamber volume, followed by smoke filling the cylinder during the exhaust stroke as the rising piston pushes the gases out. Per-cylinder flame state and red combustion lighting are independent, so simultaneous firing visuals do not share a single effect. Cylinders and the crankshaft can be hovered and selected; the information panel reports cylinder pressure/temperature or crank torque/speed. Dragging rotates the cutaway without clearing the current selection. Each selected cylinder exposes a **Misfire fault** toggle for both petrol and diesel. It suppresses that cylinder's heat release while fuel admission/injection continues, so unburned fuel is carried through the exhaust and indicated work and delivered torque decrease. The separate **Play speed** button opens a small window containing only the global 1.00x to 0.01x time-scale control. Engine audio is generated procedurally from the crank angle, firing order, per-cylinder misfire state, diesel injection events, engine speed and load; mechanical harmonics and intake/exhaust noise provide the continuous engine timbre. Audio follows the simulation time scale rather than playing a fixed prerecorded loop. Both windows use compact responsive layouts and touch-sized controls on narrow/mobile displays. The engine cutaway has no floating cylinder labels or particle bubble effects.

The round **Wheels** touch icon opens a wheel-management window styled to match the Engine laboratory. A clickable 2D top view selects each wheel and shows its condition, tread wear and temperature using the same readings as the tire-info overlay, alongside wheel dimensions, speed, load and slip. Wheel indicators transition from green to red as tread condition decreases. **Replace selected** resets one tire; **Replace all wheels** resets all four. Replacement clears tread wear and returns tire temperature to the 20 °C ambient baseline.

This is a real-time, single-zone zero-dimensional thermodynamic model, not a multi-dimensional CFD solver. The gas state is spatially uniform within each cylinder, and combustion chemistry, turbulence, spray breakup, knock and exhaust after-treatment are represented by tunable submodels rather than resolved in detail. The implementation was informed by the MIT-licensed [AngeTheGreat Engine Simulator](https://github.com/ange-yaghi/engine-sim) and classical 0-D first-law engine-cycle methods; the C++/SDL application is not embedded as a Godot runtime dependency.
