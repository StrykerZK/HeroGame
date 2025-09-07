extends Node

var hero_score = 0
var villain_score = 0
const WIN_SCORE = 1000

const TestBlockScene = preload("res://temp_scenes/testblock.tscn")

signal score_updated(new_hero_score, new_villain_score)
signal objective_updated(new_text)

func add_hero_score(amount):
	hero_score += amount
	score_updated.emit(hero_score, villain_score)
	print("Hero Score: ", hero_score) # For testing
	check_win_condition()

func add_villain_score(amount):
	villain_score += amount
	score_updated.emit(hero_score, villain_score)
	print("Villain Score: ", villain_score) # For testing
	check_win_condition()

func check_win_condition():
	if hero_score >= WIN_SCORE:
		print("HEROES WIN!")
		# Later, this will trigger the end-game screen
	elif villain_score >= WIN_SCORE:
		print("VILLAINS WIN!")

func start_villain_quest():
	objective_updated.emit("Objective: Smash the block!")
	print("Starting villain quest: Smash the block!")
	var test_block = TestBlockScene.instantiate()
	var world = get_tree().current_scene
	world.add_child(test_block)
	test_block.global_position = Vector3(50,0.5,50)
	
	test_block.smashed.connect(on_test_block_smashed)

func on_test_block_smashed():
	print("GameManager detected test block was smashed.")
	add_villain_score(50)
