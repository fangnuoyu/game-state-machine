extends CharacterBody2D

# STATES
enum State {
	IDLE,
	WALK,
	JUMP,
	FALL,
	LAND,
	HURT,
	DASH,
}

# CONSTANTS
const SPEED: float = 200.0
const JUMP_VELOCITY: float = -450.0
const GRAVITY: float = 980.0
const HURT_DURATION: float = 0.6
const LAND_DURATION: float = 0.15
const DASH_DURATION: float = 0.2
const DASH_SPEED: float = 400.0
const RESPAWN_POS: Vector2 = Vector2(200.0, 488.0)

# STATE COLORS
const STATE_COLORS: Dictionary = {
	State.IDLE: Color.CORNFLOWER_BLUE,
	State.WALK: Color.LIME_GREEN,
	State.JUMP: Color.YELLOW,
	State.FALL: Color.ORANGE,
	State.LAND: Color.CORNSILK,
	State.HURT: Color.RED,
	State.DASH: Color.GREEN,
}

# VARIABLES
var current_state: State = State.IDLE
var hurt_timer: float = 0.0
var land_timer: float = 0.0
var dash_timer: float = 0.0
var dash_direction: float = 1.0

# NODE REFERENCES
@onready var body_visual: Polygon2D = $BodyVisual
@onready var state_label: Label = $StateLabel


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_process_state(delta)
	move_and_slide()
	_update_visuals()


func _apply_gravity(delta: float) -> void:
	# Only apply when airborne
	if not is_on_floor():
		velocity.y += GRAVITY * delta


func _process_state(delta: float) -> void:
	match current_state:
		State.IDLE: _state_idle()
		State.WALK: _state_walk()
		State.JUMP: _state_jump()
		State.FALL: _state_fall()
		State.LAND: _state_land(delta)
		State.HURT: _state_hurt(delta)
		State.DASH: _state_dash(delta)


func _state_idle() -> void:
	velocity.x = move_toward(velocity.x, 0.0, SPEED)

	# Changing the state from Idle
	var direction: float = Input.get_axis("move_left", "move_right")
	if not is_on_floor():
		_change_state(State.FALL)
	elif Input.is_action_just_pressed("dash"):
		_start_dash(direction)
	elif Input.is_action_just_pressed("jump"):
		_change_state(State.JUMP)
	elif direction != 0.0:
		_change_state(State.WALK)


func _state_walk() -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	velocity.x = direction * SPEED

	# Flip the Sprite
	if direction < 0.0:
		body_visual.scale.x = -1.0
	elif direction > 0.0:
		body_visual.scale.x = 1.0

	# Transitions
	if not is_on_floor():
		_change_state(State.FALL)
	elif Input.is_action_just_pressed("dash"):
		_start_dash(direction)
	elif Input.is_action_just_pressed("jump"):
		_change_state(State.JUMP)
	elif direction == 0.0:
		_change_state(State.IDLE)


func _state_jump() -> void:
	velocity.y = JUMP_VELOCITY

	var direction: float = Input.get_axis("move_left", "move_right")
	if Input.is_action_just_pressed("dash"):
		_start_dash(direction)
	else:
		_change_state(State.FALL)


func _state_fall() -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	velocity.x = direction * SPEED

	# Flip the Sprite
	if direction < 0.0:
		body_visual.scale.x = -1.0
	elif direction > 0.0:
		body_visual.scale.x = 1.0

	# Transitions
	if Input.is_action_just_pressed("dash"):
		_start_dash(direction)
	elif is_on_floor():
		_change_state(State.LAND)


func _state_land(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, SPEED * 3.0)
	land_timer -= delta

	# Transitions
	if land_timer <= 0.0:
		var direction: float = Input.get_axis("move_left", "move_right")
		if direction != 0.0:
			_change_state(State.WALK)
		else:
			_change_state(State.IDLE)


func _state_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, SPEED * 3.0)
	hurt_timer -= delta

	# Transitions
	if hurt_timer <= 0.0:
		global_position = RESPAWN_POS
		velocity = Vector2.ZERO
		_change_state(State.IDLE)

func _state_dash(delta: float) -> void:
	velocity.x = dash_direction * DASH_SPEED
	dash_timer -= delta

	if dash_timer <= 0.0:
		var direction: float = Input.get_axis("move_left", "move_right")
		if not is_on_floor():
			_change_state(State.FALL)
		elif direction != 0.0:
			_change_state(State.WALK)
		else:
			_change_state(State.IDLE)


# HELPERS
func _start_dash(input_direction: float) -> void:
	if input_direction != 0.0:
		dash_direction = input_direction
	else:
		dash_direction = body_visual.scale.x

	body_visual.scale.x = dash_direction
	_change_state(State.DASH)


func _change_state(new_state: State) -> void:
	# Don't re-enter the same state we're in
	if new_state == current_state:
		return

	# Entry Actions
	match new_state:
		State.LAND:
			land_timer = LAND_DURATION
		State.HURT:
			hurt_timer = HURT_DURATION
		State.DASH:
			dash_timer = DASH_DURATION
			velocity.x = dash_direction * DASH_SPEED

	current_state = new_state


func _update_visuals() -> void:
	body_visual.color = STATE_COLORS[current_state]
	state_label.text = State.keys()[current_state]


func _on_spike_body_entered(body: Node2D) -> void:
	if current_state != State.HURT:
		_change_state(State.HURT)
