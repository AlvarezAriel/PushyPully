extends Node2D


func _ready():
	game.main.play_music( "res://intro.ogg" )
	# set continue option
	#if game.gamestate["level"].empty():
	#	$menu_layer/menu.unselectable_items.append( 1 )

func _physics_process(delta):
	if Input.is_key_pressed( KEY_ESCAPE ):
		get_tree().quit()


func _on_menu_layer_selected_item( pos ):
	print( "selected item: ", pos )
	if pos == 0:
		game.main._start_game()
	elif pos == 1:
		game.main._finished_level( game.gamestate["level"] )
		# game.main._load_scene( game.gamestate["level"] )
	elif pos == 2:
		# quit game
		get_tree().quit()
	pass # replace with function body

func _on_new_game_pressed():
	print("Start new game")
	game.main._start_game()
