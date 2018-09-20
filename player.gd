extends KinematicBody2D


var bullet_scn = preload( "res://bullet.tscn" )
var bullet_blast_scn = preload( "res://bullet_blast.tscn" )
var bomb_scn = preload( "res://bomb.tscn" )
var bomb_blast_scn = null


signal player_dead
signal text_finished

enum STATES { IDLE, RUN, JUMP_UP, JUMP_DOWN, CROUCH, CLIMB, BOMB, HIT, DEAD }
var state_cur = -1
var state_nxt = STATES.IDLE

const INVULNERABLE_TIME = 0.5

const GRAVITY = 800
const TERMINAL_VEL = 200
const MAX_VEL_GROUND = 120
const ACCEL_GROUND = 15
const DECEL_GROUND = 70
const MAX_VEL_AIR = 100
const ACCEL_AIR = 5
const DECEL_AIR = 5

const JUMP_SPEED = 160#200
const JUMP_GRAVITY = 500
const JUMP_MARGIN = 0.1

const LOOK_DOWN_TIMER = 2
const FIRE_INTERVAL = 0.1
const FIRE_THROWBACK = 100

var cur_gravity = GRAVITY
var vel = Vector2()
var analog_velocity = Vector2()
var anim_cur = ""
var anim_nxt = "idle"
var update_anim = false
var dir_cur = 1
var dir_nxt = 1

var is_invulnerable = false
var is_firing = false
var is_cutscene = false
var can_fire = true
var bomb_pressed = false
var shoot_pressed = false

var banana_tex = preload( "res://banana.png" )

func _ready():
	if game.camera != null:
		game.camera.target_nxt = "player"
		game.player = self
	if game.gamestate[ "mode" ] == "banana":
		$rotate/player.texture = banana_tex

func _physics_process( delta ):
	if is_cutscene:
		if cut_scene_anim:
			# motion
			vel.x = lerp( vel.x, 0, DECEL_GROUND * delta )
			vel.y = min( vel.y + cur_gravity * delta, TERMINAL_VEL )
			vel = move_and_slide( vel, Vector2( 0, -1 ) )
			# animation
			if is_on_floor():
				anim_nxt = "idle"
			else:
				anim_nxt = "jump down"
			if anim_cur != anim_nxt:
				anim_cur = anim_nxt
				$anim.play( anim_cur )
	else:
		# motion
		vel.y = min( vel.y + cur_gravity * delta, TERMINAL_VEL )
		vel = move_and_slide( vel, Vector2( 0, -1 ) )
	
		
		# direction
		if dir_nxt != dir_cur:
			dir_cur = dir_nxt
			$rotate.scale.x = dir_cur
		
		# animation
		if anim_cur != anim_nxt:
			anim_cur = anim_nxt
			$anim.play( anim_cur )
		
		# states
		if state_nxt != state_cur:
			print( "state: ", state_nxt )
		state_cur = state_nxt
		if not is_dead:
			if state_cur == STATES.IDLE:
				_state_idle( delta )
			elif state_cur == STATES.RUN:
				_state_run( delta )
			elif state_cur == STATES.JUMP_UP:
				_state_jump( delta )
			elif state_cur == STATES.JUMP_DOWN:
				_state_jumpdown( delta )
			elif state_cur == STATES.CROUCH:
				_state_crouch( delta )
			elif state_cur == STATES.BOMB:
				_state_bomb( delta )
			elif state_cur == STATES.CLIMB:
				_state_climb( delta )
			elif state_cur == STATES.DEAD:
				_state_dead( delta )
		else:
			_state_dead( delta )
		
		# fire fsm
		if is_firing:
			is_firing = _fire_fsm( delta )
			
	shoot_pressed = false
	bomb_pressed = false		






onready var check_positions = [ $check_stairs_below, $check_stairs_center, $check_stairs_above ]
func is_on_stairs( positions ):
	if game.stairs == null: return
	for idx in range( positions.size() ):
		if game.stairs.is_stairs( check_positions[positions[idx]].global_position ):
			return true
	return false



#============================
# player pressed fire
#============================
func _check_fire_btn( delta ):
	if not can_fire: return
	if shoot_pressed():
		if game.gamestate["bullets"] > 0:
			game.gamestate["bullets"] -= 1
			_start_fire( delta )

func _check_bomb_btn( delta ):
	if game.gamestate["bombs"] > 0 and bomb_pressed or shoot_pressed():
		game.gamestate["bombs"] -= 1
		_start_state_bomb( delta )
#============================
# fire fsm
#============================
var _fire_state = 0
var _fire_timer = 0
var _fire_anim_timer = 0
var is_firing_anim = false
func _start_fire( delta ):
	if is_dead: return
	if not can_fire: return
	if is_firing: return
	is_firing = true
	
	# instance bullet
	var b = bullet_scn.instance()
	b.dir = Vector2( dir_cur, 0 ).normalized()
	var rpos = Vector2()
	b.position = position + Vector2( dir_cur * 10, -7 ) + rpos
	if state_cur == STATES.CROUCH:
		b.position.y += 2
	get_parent().add_child( b )
	# play sound
	$sfx.mplay( shoot_fx )
	
	# bullet blast
	var d = bullet_blast_scn.instance()
	d.position = Vector2( 14, -8 ) + rpos
	if state_cur == STATES.CROUCH:
		d.position.y += 2
	$rotate.add_child( d )
	
	# throwback
	vel.x -= dir_cur * FIRE_THROWBACK * 60 * delta
	
	# screen shake
	if game.camera: game.camera.shake( 0.25, 30, 2 )
	
	# set firing animation
	$rotate/player.frame += 8
	var animpos = $anim.current_animation_position
	var newanim = $anim.current_animation + " shoot"
	if $anim.has_animation( newanim ):
		$anim.play( $anim.current_animation + " shoot" )
		$anim.seek( animpos )
	
	# prepare timer
	_fire_timer = FIRE_INTERVAL * 2 / 3
	# set firing state
	_fire_state = 0
	
func _fire_fsm( delta ):
	if _fire_state == 0:
		# wait until timer expires
		_fire_timer -= delta
		if _fire_timer <= 0:
			_fire_timer = FIRE_INTERVAL / 3
			# terminate animation
			if $rotate/player.frame >= 8:
				$rotate/player.frame -= 8
			var animpos = $anim.current_animation_position
			$anim.play( anim_cur )
			$anim.seek( animpos )
			# next state
			_fire_state = 1
	elif _fire_state == 1:
		_fire_timer -= delta
		if _fire_timer <= 0:
			# terminate fire state
			return false
	return true


#============================
# state idle
#============================
func _start_state_idle( delta ):
	$rotate/damagebox.position = Vector2( 0, -8 )
	anim_nxt = "idle"
	cur_gravity = GRAVITY
	state_nxt = STATES.IDLE
func _state_idle( delta ):
	vel.x = lerp( vel.x, 0, DECEL_GROUND * delta )
	# player input
	if right_pressed() or left_pressed():
		state_nxt = STATES.RUN
	if jump_pressed() and is_on_stairs( [ 2 ] ):
		_start_state_climb( delta )
	elif down_pressed() and is_on_stairs( [ 0 ] ):
		_start_state_climb( delta )
	elif down_pressed() and not is_on_stairs( [ 0 ] ):
		_start_state_crouch( delta )
	elif ( jump_pressed() ) and is_on_floor():
		_start_state_jump_up( delta )
	if not is_on_floor():
		_start_state_jumpdown( delta )
	_check_fire_btn( delta )
	#_check_bomb_btn( delta )


#============================
# state run
#============================
func _state_run( delta ):
	anim_nxt = "run"
	cur_gravity = GRAVITY
	# player input
	if left_pressed():
		vel.x = lerp( vel.x, -MAX_VEL_GROUND, ACCEL_GROUND * delta )
		dir_nxt = -1
	elif right_pressed():
		vel.x = lerp( vel.x, MAX_VEL_GROUND, ACCEL_GROUND * delta )
		dir_nxt = 1
	else:
		_start_state_idle( delta )
	
	# stuff to do on the floor
	if is_on_floor():
		var bup = jump_pressed()
		var bdown = down_pressed()
		var bjump = jump_pressed()
		# jump (bup has priority)
		if bjump or bup:
			_start_state_jump_up( delta )
		# stairs
		elif ( bup and is_on_stairs( [ 0, 2 ] ) ):
			_start_state_climb( delta )
	else:
		# falling
		_start_state_jumpdown( delta )
	_check_fire_btn( delta )

func shoot_pressed():
	return shoot_pressed or Input.is_action_pressed( "btn_fire" )

func right_pressed():
	return analog_velocity.x == 1 or Input.is_action_pressed( "btn_right" )

func left_pressed():
	return analog_velocity.x == -1 or Input.is_action_pressed( "btn_left" )
	
func jump_pressed():
	return analog_velocity.y == -1 or Input.is_action_pressed( "btn_jump" ) or Input.is_action_pressed( "btn_up" )

func down_pressed():
	return analog_velocity.y == 1 or Input.is_action_pressed( "btn_down" )

#============================
# state jump up
#============================
var _jump_state = 0
var _jump_timer = 0
var _jump_state_nxt = 0
var _jump_climb_timer = 0
func _start_state_jump_up( delta ):
	_jump_state = 0
	_jump_state_nxt = 1
	_jump_timer = 0
	_jump_climb_timer = 0.1
	state_nxt = STATES.JUMP_UP
	anim_nxt = "jump start"
	# play jump
	$sfx.mplay( jump_fx )
	
func _jump_switch():
	_jump_state = _jump_state_nxt
func _state_jump( delta ):
	if _jump_state == 0:
		# waiting for animation
		pass
	elif _jump_state == 1:
		# start the jump
		jump_dust()
		vel.y = -JUMP_SPEED * 60 * delta
		vel = move_and_slide( vel )
		if is_on_floor():
			_start_state_idle( delta )
		cur_gravity = JUMP_GRAVITY
		anim_nxt = "jump up"
		_jump_state = 2
	elif _jump_state == 2:
		# still going up?
		_jump_timer += delta
		if _jump_timer > 0.5:
			cur_gravity = GRAVITY
		if vel.y >= 0:
			cur_gravity = GRAVITY
			_start_state_jumpdown( delta, true )
		else:
			# is still jumping?
			if not ( jump_pressed() ):# and not Input.is_action_pressed( "btn_up" ):
				cur_gravity = GRAVITY
		if is_on_floor():
			_start_state_idle( delta )
	if left_pressed():
		vel.x = lerp( vel.x, -MAX_VEL_AIR, ACCEL_AIR * delta )
		dir_nxt = -1
	elif right_pressed():
		vel.x = lerp( vel.x, MAX_VEL_AIR, ACCEL_AIR * delta )
		dir_nxt = 1
	else:
		vel.x = lerp( vel.x, 0, DECEL_AIR * delta )
		if shoot_pressed():
			vel.x = lerp( vel.x, 0, 10 * DECEL_AIR * delta )
	_jump_climb_timer -= delta
	if is_on_stairs([1]) and _jump_climb_timer <= 0:
		if jump_pressed():
			_start_state_climb( delta )
	_check_fire_btn( delta )



#============================
# state jump down
#============================
var _jumpdown_timer = 0
var _grab_stairs_timer = 0
var _fall_timer = 0
func _start_state_jumpdown( delta, is_jump = false, from_stairs = false ):
	anim_nxt = "jump down"
	state_nxt = STATES.JUMP_DOWN
	_fall_timer = 0
	_jumpdown_timer = 0
	_grab_stairs_timer = 1
	cur_gravity = GRAVITY
	if from_stairs:
		_grab_stairs_timer = 0
	if not is_jump:
		_jumpdown_timer = JUMP_MARGIN
func _state_jumpdown( delta ):
	_jumpdown_timer -= delta
	if _jumpdown_timer > 0:
		if jump_pressed():
			_start_state_jump_up( delta )
			return
	_fall_timer += delta
	if is_on_floor():
		#print( "Fall timer: ", _fall_timer )
		if _fall_timer >= 0.4:
			if game.camera: game.camera.shake( 0.25, 30, 2 )
		landing_dust()
		_start_state_idle( delta )
	if left_pressed():
		vel.x = lerp( vel.x, -MAX_VEL_AIR, ACCEL_AIR * delta )
		dir_nxt = -1
	elif right_pressed():
		vel.x = lerp( vel.x, MAX_VEL_AIR, ACCEL_AIR * delta )
		dir_nxt = 1
	else:
		vel.x = lerp( vel.x, 0, DECEL_AIR * delta )
		#throwback
		if shoot_pressed():
			vel.x = lerp( vel.x, 0, 10 * DECEL_AIR * delta )
	_grab_stairs_timer += delta
	if is_on_stairs([2]) and _grab_stairs_timer > 0.2:
		if jump_pressed() or down_pressed():
			_start_state_climb( delta )
	_check_fire_btn( delta )



#============================
# state crouch
#============================
var _state_crouch_timer = 0
func _start_state_crouch( delta ):
	_state_crouch_timer = LOOK_DOWN_TIMER
	anim_nxt = "crouch"
	state_nxt = STATES.CROUCH
	#$rotate/damagebox.position.y += 4
	$rotate/damagebox.position = Vector2( 0, -4 )
func _state_crouch( delta ):
	vel.x = lerp( vel.x, 0, DECEL_GROUND * delta )
	_state_crouch_timer -= delta
	if _state_crouch_timer <= 0:
		# todo: look down
		pass
	if not down_pressed():
		#$rotate/damagebox.position.y -= 4
		$rotate/damagebox.position = Vector2( 0, -4 )
		_start_state_idle( delta )
	#_check_fire_btn( delta )
	_check_bomb_btn( delta )
	pass
	


#============================
# state bomb
#============================
var _bomb_state = 0
var _bomb_timer = 0
func _start_state_bomb( delta ):
	state_nxt = STATES.BOMB
	#anim_nxt = "crouch"
	_bomb_state = 0
	_bomb_timer = 0.25
	$sfx.mplay( bomb_fx )
func _state_bomb( delta ):
	if _bomb_state == 0:
		# waiting timer
		_bomb_timer -= delta
		if _bomb_timer <= 0:
			_bomb_state = 1
	elif _bomb_state == 1:
		# release bomb
		var b = bomb_scn.instance()
		b.position = position
		get_parent().add_child( b )
		# return to idle
		_start_state_idle( delta )


#============================
# state climb
#============================
const CLIMB_VEL = 60
func _start_state_climb( delta ):
	state_nxt = STATES.CLIMB
	cur_gravity = 0
	self.set_collision_mask_bit( 1, false )
	vel *= 0
func _state_climb( delta ):
	# player input
	var climb_dir = -1
	if jump_pressed():
		vel.y = -CLIMB_VEL
		anim_nxt = "climb"
		$anim.playback_speed = 2
		climb_dir = -1
	elif down_pressed():
		vel.y = CLIMB_VEL
		anim_nxt = "climb"
		$anim.playback_speed = -2
		climb_dir = 1
	else:
		vel.y = 0
		$anim.playback_speed = 0
		anim_nxt = "climb"
	if left_pressed():
		vel.x = -CLIMB_VEL / 2 #lerp( vel.x, -CLIMB_VEL, 1 * delta )
	elif right_pressed():
		vel.x = CLIMB_VEL / 2#lerp( vel.x, CLIMB_VEL, 1 * delta )
	else:
		vel.x = 0
	var _ons = false
	if climb_dir == -1:
		_ons = is_on_stairs( [ 1 ] )
	else:
		_ons = is_on_stairs( [ 0 ] )
	if not _ons:
		$anim.playback_speed = 1
		cur_gravity = GRAVITY
		self.set_collision_mask_bit( 1, true )
		_start_state_jumpdown( delta, false, true )



##============================
## state hit
##============================
#func _state_hit( delta ):
#	anim_nxt = "jump down"
#	vel *= 0.95 * 60 * delta
#	pass


#============================
# state dead
#============================
var is_dead = false
var _report_dead = false
var _dead_timer = 2
func _start_state_dead( delta ):
	if is_dead: return
	is_dead = true
	# disable collisions
	collision_mask = 0
	collision_layer = 0
	# stop player
	vel = Vector2( -100, -200 ) * 60 * delta
	# stop camera
	game.camera.target_nxt = ""
	state_nxt = STATES.DEAD
	cur_gravity = GRAVITY
	# animation
	anim_nxt = "dead"
	# dead timer
	_dead_timer = 2
	# sound
	$sfx.mplay(dead_fx)
func _state_dead( delta ):
	anim_nxt = "dead"
	if not _report_dead:
		_dead_timer -= delta
		if ( global_position.y - game.camera.global_position.y > 200 ) or _dead_timer <= 0:
			emit_signal( "player_dead" )
			_report_dead = true








#============================
# dust
#============================
var walking_dust_scn = preload( "res://walking_dust.tscn" )
func walking_dust():
	var d = walking_dust_scn.instance()
	d.position = position + Vector2( dir_cur * 1, -16 )
	d.scale.x = dir_cur
	get_parent().add_child( d )
var jump_dust_scn = preload( "res://jump_dust.tscn" )
func jump_dust():
	var d = jump_dust_scn.instance()
	d.position = position + Vector2( dir_cur * -2, -16 )
	get_parent().add_child( d )
var landing_dust_scn = preload( "res://landing_dust.tscn" )
func landing_dust():
	var d = landing_dust_scn.instance()
	d.position = position + Vector2( dir_cur * -2, -16 )
	get_parent().add_child( d )

#============================
# hit
#============================
func destroy( pos = null ):
	print( "destroying player" )
	_start_state_dead( get_physics_process_delta_time() )




func _on_invulnerable_timer_timeout():
	is_invulnerable = false
	_start_state_idle( get_physics_process_delta_time() )


func _on_check_fire_body_entered(body):
	#print( "Cannot Fire" )
	can_fire = false
	pass # replace with function body


func _on_check_fire_body_exited(body):
	#print( "Can Fire" )
	can_fire = true
	pass # replace with function body



#============================
# cutscene functions
#============================
func text( msg, duration = 2 ):
	if game.main == null: return
	game.main.connect( "text_finished", self, "_on_text_finished" )
	game.main.set_character_text( self, msg, duration )
func _on_text_finished():
	game.main.disconnect( "text_finished", self, "_on_text_finished" )
	emit_signal( "text_finished" )

var cut_scene_anim = false
func set_cutscene( allow_idle = false ):
	is_cutscene = true
	if not allow_idle:
		$anim.stop()
		$rotate/player.frame = 0
		vel *= 0
		cut_scene_anim = false
	else:
		cut_scene_anim = true
func clear_cutscene():
	print( "clearing cutscene" )
	anim_cur = ""
	_start_state_idle( get_physics_process_delta_time() )
	can_fire = false
	$can_fire_timer.wait_time = 0.5
	$can_fire_timer.start()
	is_cutscene = false
func _on_can_fire_timer_timeout():
	can_fire = true
func look_at_player():
	$rotate/player.frame = 6


func analog_force_change(inForce, inStick):
	
	analog_velocity = Vector2(inForce.x,-inForce.y)
	
	analog_velocity = analog_velocity.normalized()

	analog_velocity.x = stepify(analog_velocity.x, 1)
	analog_velocity.y = stepify(analog_velocity.y, 1)
	
	print("Analog: (%d,%d)" % [analog_velocity.x, analog_velocity.y])	

func _on_shoot_pressed():
	shoot_pressed = true


func _on_bomb_pressed():
	bomb_pressed = true

#========================
# audio functions
#========================
var step_fx = preload( "res://player_step.wav" )
var jump_fx = preload( "res://player_jump.wav" )
var shoot_fx = preload( "res://player_shoot.wav" )
var dead_fx = preload( "res://player_die.wav" )
var bomb_fx = preload( "res://bomb_drop.wav" )
func pstep():
	#print( "Bus index: ", AudioServer.get_bus_index( "step" ) )
	#var effect = AudioServer.get_bus_effect( AudioServer.get_bus_index( "step" ), 0)
	#effect.pitch_scale = 1#rand_range( 0.8, 1.2 )
	#print( effect.pitch_scale )
	$sfx.mplay( step_fx )

func pclimb():
	$sfx.mplay( step_fx )





