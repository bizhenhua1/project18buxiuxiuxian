# 3D playtest: hands and natural locomotion pace

The old route pace drove real root displacement, but its animation rate exceeded twice natural walking speed on the current scaled hero. Real displacement alone was therefore not a sufficient gait contract.

The 3D stage now derives walk/run travel speeds from each model's measured support-foot stride and scale, at a 1.05 cadence target, bounded by the existing travel speed limits. Event distances use these same speeds. Walk/run selection is scale-aware and has hysteresis. This is not a global animation-rate clamp: enemy animation and forced displacement remain separate paths.

Living allied actors apply a rest-relative finger pose after retargeting: relaxed for empty hands, curled for equipped hands. Finger positions, wrist transforms, and arm transforms are unchanged. Death animation is excluded. The pose is computed on equipment refresh rather than rebuilt every frame. This is a procedural grip baseline; it does not constitute per-weapon contact IK or full visual certification of every model.

Validation: relaxed and sword-equipped fingers remain stable over 240 locomotion frames; a rendered relaxed-hand preview was inspected. Route test measured walk/run playback rates at 1.05, first arrival at 3.025 seconds, linear arrival at 3.6 seconds, and post-fork arrival at 5.9 seconds. Both two-way and three-way fork playtests passed. No broad map/performance sweep was performed.

## 2026-09-15: remove the empty-hand override

The previous fixed relaxed pose incorrectly replaced the source animation on empty hands. Removed it. Only hands occupied by equipment receive the grip override; the free hand of a one-handed loadout retains source motion, and removing equipment clears the override. Torch/lantern IK remains confined to light_carry_preview.gd and was not running in this actor path.

The updated GPU test covers empty hands, a one-handed sword, a two-handed sword, and unequipping, through walk and run. All non-overridden bones are compared with the retargeted source pose at the same loop time; occupied fingers are checked against the grip. Test passed and the unarmed render was inspected. Earlier notes describing the relaxed empty-hand pose are superseded by this correction.

## 2026-09-15: weighted arm twist helpers

Follow-up reports showed that removing grip overrides was insufficient. GLB weights confirm that mary-kuromi uses wrist/arm twist helpers (手捩, 手捩1–3, 腕捩1–3), while the motion mapping left these helpers at rest. Added a 3D-only retarget subclass which extracts the joint's axial rotation and distributes it across these helpers, compensating the end joint to preserve its authored global orientation. Helpers also participate in locomotion blending. No fixed empty-hand pose is applied. Mapping is prepared once; runtime uses cached quaternions, without forced full-skeleton updates.

Validation: 242 walk/run samples preserve wrist, elbow and finger global rotations while the weighted helpers receive rotation. Empty/single/two-handed/unequip regression passed. A rendered sample was inspected. This addresses a confirmed skinning omission; full in-motion user evaluation remains necessary before claiming every reported deformation is resolved.

## 2026-09-15: actual playtest model and palm skin weights

The saved hero is gardener-kitty-dada.glb, not the previously tested mary-kuromi. On its battle idle, CPU skinning identified a palm edge of 1.5 mm stretched roughly 23 times: a palm vertex had 45% influence from a little-finger joint approximately 10 cm away. At rest the inverse binds are consistent; disabling surface merging did not remove the deformation. Thus rotation-only tests were insufficient.

Added a model-scoped, cached mesh-weight repair before surface merging. Finger influence on vertices behind the associated joint is moved proximally through the finger chain toward the wrist. Positions, UVs, materials, LODs and the source GLB remain unchanged. Original finger animation is retained. A trial finger-axis calibration was discarded because the weight defect provided the stronger explanation.

Rendered idle and attack closeups show the stretched palm substantially corrected. The current hero passes 726 pose samples across idle, walk, run and its three attacks. This is a scoped repair, not a claim that every hand topology or costume has been certified. Residual finger-web stretching exists in the geometric metric, so no claim of zero deformation is made. Mesh construction is cached; the repair adds no per-frame vertex processing.
