extends Node2D
class_name PlayerWeapon

## Handles player's shooting logic, bullet powerups, and weapon state.

#region Exports
@export var default_bullet_scene: PackedScene
@export var default_max_ammo: int = 8
#endregion

#region Signals
signal bullet_type_changed(new_bullet_scene: PackedScene)
signal ammo_capacity_changed(new_max_ammo: int)
signal powerup_started(bullet_name: String, duration: float)
signal powerup_expired()
#endregion

#region State
var current_bullet_scene: PackedScene
var current_max_ammo: int = 8
var current_damage: float = 10.0
var powerup_timer: float = 0.0
var is_powerup_active: bool = false
#endregion

#region Bullet Type Data
var bullet_metadata: Dictionary = {}
#endregion

func _ready() -> void:
	_initialize_default_bullet()
	_cache_bullet_metadata(default_bullet_scene)
	current_bullet_scene = default_bullet_scene

func _process(delta: float) -> void:
	_update_powerup_timer(delta)


func _initialize_default_bullet() -> void:
	if not default_bullet_scene:
		default_bullet_scene = preload("res://BulletBase/bullet_base.tscn")
		push_warning("PlayerWeapon: No default bullet assigned, using base bullet")
	
	current_bullet_scene = default_bullet_scene
	_update_stats_from_bullet(default_bullet_scene)


func shoot(from_position: Vector2, direction: float) -> void:
	if not current_bullet_scene:
		push_error("PlayerWeapon: No bullet scene to shoot.")
		return
	
	var bullet = current_bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = from_position
	bullet.setup(direction, current_damage)
	
	# Track shot fired in GameManager
	if Engine.has_singleton("GameManager"):
		GameManager.register_shot()


func apply_bullet_powerup(bullet_scene: PackedScene, duration: float = 0.0) -> void:
	if not bullet_scene:
		push_error("PlayerWeapon: Cannot apply null bullet powerup")
		return
	
	if not bullet_metadata.has(bullet_scene.resource_path):
		_cache_bullet_metadata(bullet_scene)
	
	current_bullet_scene = bullet_scene
	is_powerup_active = true
	_update_stats_from_bullet(bullet_scene)
	
	powerup_timer = max(0.0, duration)
	print("Powerup activated: ", get_current_bullet_name(), " for ", duration, "s" if duration > 0 else "(permanent)")
	
	var bullet_name = get_current_bullet_name()
	emit_signal("powerup_started", bullet_name, duration)
	emit_signal("bullet_type_changed", bullet_scene)
	emit_signal("ammo_capacity_changed", current_max_ammo)

func clear_powerup() -> void:
	if is_powerup_active:
		_expire_powerup()

func _update_powerup_timer(delta: float) -> void:
	if powerup_timer > 0:
		powerup_timer -= delta
		if powerup_timer <= 0:
			_expire_powerup()

func _expire_powerup() -> void:
	current_bullet_scene = default_bullet_scene
	is_powerup_active = false
	powerup_timer = 0
	_update_stats_from_bullet(default_bullet_scene)
	
	print("Powerup expired - back to base bullets")
	emit_signal("powerup_expired")
	emit_signal("bullet_type_changed", default_bullet_scene)
	emit_signal("ammo_capacity_changed", current_max_ammo)

	if owner and owner.has_signal("ammo_changed"):
		owner.emit_signal("ammo_changed", current_max_ammo, current_max_ammo)


func _cache_bullet_metadata(bullet_scene: PackedScene) -> void:
	if not bullet_scene:
		return
	
	var path = bullet_scene.resource_path
	if bullet_metadata.has(path):
		return
	
	var temp_bullet = bullet_scene.instantiate()
	var metadata = {
		"max_ammo": _get_property_safe(temp_bullet, "max_ammo", default_max_ammo),
		"damage": _get_property_safe(temp_bullet, "damage", 10.0),
		"name": _get_bullet_display_name(temp_bullet)
	}
	bullet_metadata[path] = metadata
	temp_bullet.queue_free()
	
	print("Cached metadata for: ", metadata["name"])

func _get_property_safe(object: Object, property: String, default_value):
	if property in object:
		return object.get(property)
	return default_value

func _get_bullet_display_name(bullet: Node) -> String:
	if "display_name" in bullet:
		return bullet.display_name
	
	var script = bullet.get_script()
	if script:
		var bullet_class_name = script.get_global_name()
		if bullet_class_name:
			return bullet_class_name.replace("Bullet", "")
	
	return bullet.name if bullet.name != "" else "Unknown"


func _update_stats_from_bullet(bullet_scene: PackedScene) -> void:
	if not bullet_scene:
		current_max_ammo = default_max_ammo
		current_damage = 10.0
		return
	
	var path = bullet_scene.resource_path
	if bullet_metadata.has(path):
		var metadata = bullet_metadata[path]
		current_max_ammo = metadata["max_ammo"]
		current_damage = metadata["damage"]
	else:
		_cache_bullet_metadata(bullet_scene)
		_update_stats_from_bullet(bullet_scene)


func get_current_bullet_scene() -> PackedScene:
	return current_bullet_scene

func get_current_max_ammo() -> int:
	return current_max_ammo

func get_current_damage() -> float:
	return current_damage

func get_powerup_time_remaining() -> float:
	return max(0.0, powerup_timer)

func get_current_bullet_name() -> String:
	if not current_bullet_scene:
		return "Normal"
	
	var path = current_bullet_scene.resource_path
	if bullet_metadata.has(path):
		return bullet_metadata[path]["name"]
	
	return "Normal"

func has_active_powerup() -> bool:
	return is_powerup_active


func get_debug_info() -> Dictionary:
	return {
		"current_bullet": get_current_bullet_name(),
		"max_ammo": current_max_ammo,
		"damage": current_damage,
		"powerup_active": is_powerup_active,
		"time_remaining": get_powerup_time_remaining(),
		"cached_bullets": bullet_metadata.keys().size()
	}
