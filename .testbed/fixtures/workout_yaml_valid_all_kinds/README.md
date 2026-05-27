# workout_yaml_valid_all_kinds

Committed workout-package fixture for the environment-loader testbed.

Why it stays lightweight:
- the committed YAML points at shared `/.testbed/assets/` fixtures through relative `../../assets/...` paths
- that keeps one set each for image, video, GLB, and gaussian splat without copying larger payloads into the fixture package
- repo-local tests still copy the package to `/tmp`, materialize local media files under `media/environments/`, and load the package via an absolute `workout.yaml` path to prove external-path semantics
