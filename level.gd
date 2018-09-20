extends Node2D

export(String) var nxt_level = "res://level_01.tscn"
export(String) var music = "res://level_01.ogg"
signal finished_level
signal restart_level
signal game_over

var finished = false

func _ready():
	# place player at initial position
	$player.global_position = $start_position.global_position
	print( "player: ", game.player )
	game.player.connect( "player_dead", self, "_on_player_dead" )
	# set camera limits
	
	game.camera.limit_right = $finish_area.global_position.x
	game.main.play_music( music )

func is_level( n ):
	game.gamestate[ "level" ] = n

func get_player():
	return $player

func _physics_process(delta):
	if Input.is_key_pressed( KEY_ESCAPE ):
		var m = preload( "res://pause_menu.tscn" ).instance()
		add_child( m )

func _on_finish_area_body_entered(body):
	if finished or body != game.player: return
	finished = true
	# finished the level, emit signal
	print( "entered finish area" )
	emit_signal( "finished_level", nxt_level )

func _on_player_dead():
	# check lives
	if game.gamestate["lives"] > 1:
		game.gamestate["lives"] -= 1
		emit_signal( "restart_level" )
	else:
		emit_signal( "game_over" )
