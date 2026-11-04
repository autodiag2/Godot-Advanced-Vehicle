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

Each car can reference an EngineParameters resource from CarParameters.engine. The included petrol and diesel inline-four presets are stored in assets/vehicle/engines/. Configure cylinder geometry, firing order, compression ratio, fuel properties, combustion timing, inertia, idle speed, rev limit, friction and torque calibration per vehicle.

The runtime model advances a 720-degree four-stroke cycle at crank-angle substeps. It estimates intake, compression, combustion, expansion and exhaust cylinder pressure, then uses slider-crank geometry and per-cylinder firing phases to produce crankshaft torque pulses. Petrol engines use throttle-dependent manifold pressure and spark advance; diesel engines retain an unthrottled air charge and meter fuel with pedal input and injection timing.

Use the Engine button in the HUD to open the live cutaway view. Its speed slider changes Engine.time_scale for the whole simulation, from 1.00x down to 0.01x, so individual firing events can be inspected.

The implementation is a Godot-native, real-time zero-dimensional cylinder-pressure model whose mean torque is calibrated by the existing vehicle torque curve. It is not a full one-dimensional gas-dynamics solver or CFD model. AngeTheGreat/engine-sim is the MIT-licensed open-source reference for real-time engine-response and crank-angle simulation concepts. Its C++/SDL application is not linked as a runtime dependency; the Godot integration is implemented in GDScript. See https://github.com/ange-yaghi/engine-sim.
