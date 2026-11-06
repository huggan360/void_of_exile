extends RefCounted
## Shared two-bone arms. Targets and wrist bases are in the inner rig's space.

const VOXEL_SIZE := 1.8 / 16.0
const UPPER_LENGTH := 2.5 * VOXEL_SIZE
const FOREARM_LENGTH := 3.0 * VOXEL_SIZE
const GRIP := Vector3(0, 0, -1) * VOXEL_SIZE


static func pose(arm: Node3D, shoulder: float, elbow: float, wrist_pitch := 0.0, spread := 0.0) -> void:
	var forearm := arm.get_node("ForearmL" if arm.name == "ArmL" else "ForearmR") as Node3D
	var hand := forearm.get_node("LeftHand" if arm.name == "ArmL" else "RightHand") as Node3D
	arm.rotation = Vector3(shoulder, 0, spread)
	forearm.rotation = Vector3(elbow, 0, 0)
	hand.basis = (arm.basis * forearm.basis).inverse() * Basis(Vector3.RIGHT, wrist_pitch)


static func reach(arm: Node3D, target: Vector3, bend: Vector3) -> void:
	var forearm := arm.get_node("ForearmL" if arm.name == "ArmL" else "ForearmR") as Node3D
	var hand := forearm.get_node("LeftHand" if arm.name == "ArmL" else "RightHand") as Node3D
	var offset := target - arm.position
	var distance := clampf(offset.length(), 0.001, UPPER_LENGTH + FOREARM_LENGTH - 0.0001)
	var direction := offset.normalized()
	var along := (UPPER_LENGTH * UPPER_LENGTH - FOREARM_LENGTH * FOREARM_LENGTH + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, UPPER_LENGTH * UPPER_LENGTH - along * along))
	var sideways := (bend - direction * bend.dot(direction)).normalized()
	var elbow := direction * along + sideways * height
	arm.basis = Basis(Quaternion(Vector3.DOWN, elbow.normalized()))
	var lower_basis := Basis(Quaternion(Vector3.DOWN, (direction * distance - elbow).normalized()))
	forearm.basis = arm.basis.inverse() * lower_basis
	hand.basis = lower_basis.inverse()
