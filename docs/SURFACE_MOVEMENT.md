# Surface stepping and smoothing

The Surface uses 0.25 m voxel collision meshes and a rounded player capsule.
Capsule contacts at voxel corners can report a wall normal and briefly lose the
floor flag even when the voxel top is walkable. `move_and_slide()` also projects
velocity against that wall, potentially zeroing the forward velocity before a
step retry. Combining those conditions could permanently stop a direct approach
to a small ledge, while sideways input happened to clear the corner.

`Player._move_ground()` retains the intended movement, anticipates blocked steps,
and holds grounding briefly across a confirmed step. It retries the remaining
forward displacement from the intended velocity when a collision arises during
the actual slide. Failed preflight attempts are not repeated in the same frame.

`_try_step_up()` keeps the 1.05 m height limit. It measures the actual rise rather
than rounding to 15 cm increments, limits lifts to available headroom, and confirms
support on a walkable surface. A short ray distinguishes flat voxel tops from
steep capsule-edge normals. Tall walls and ceilings remain blocking. There are no
loops over candidate lift heights. This helper also supports the existing local-up
argument used by Space traversal.

Visual smoothing compensates every vertical displacement, including small falls.
The spring has no height threshold or hard offset clamp that can introduce a
velocity jump on landing or on repeated tall steps. Large teleports reset it. Actual
supporting contacts identify terrain instead of relying only on a ray below the
capsule centre, which may still be over the lower column. Confirmed terrain steps
keep the smoothing active. The broad sampled height fades out near cliffs rather
than abruptly changing the spring target. Falling and upward knockback retain
their existing movement rules; arrival clears the step grace.

## Regression checks

Use the project's custom voxel editor executable in place of `godot`:

```
godot --headless --fixed-fps 60 --path . res://tools/probe/surface_movement.tscn -- --assert
```

This creates real voxel-meshed collision geometry at Surface scale and drives the
real player physics. It checks 0.25/0.5/0.75/1 m ledges, fine and gentle staircases,
diagonal corners, repeated large steps, descending terrain, a short drop, a climb
with limited headroom, an obstructed ceiling and 1.25/2 m walls. It asserts forward progress and visual height
continuity, and rejects stalls on the climbable routes. It never joins an account
or saves a character. `--detail` adds contact diagnostics; omitting `--assert` is
useful when measuring a previous implementation.

The existing full-world probe samples three hills in both directions. Run it with
a scratch XDG_DATA_HOME so it does not use an account session or singleplayer save:

```
XDG_DATA_HOME=/tmp/void-walk-review godot --headless --path . res://tools/probe/walk_probe.tscn -- --qa-quick --terrain-only
```

`--terrain-only` isolates the actual Surface collision from rocks, NPCs and other
objects that may legitimately block a sampled route. Without it the probe keeps
normal collision layers. `--runs=1` limits the review to one hill. The probe reports body, model and camera height changes,
movement distance and slow frames. No server protocol or deployment changes are
required.
