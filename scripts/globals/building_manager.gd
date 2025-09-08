extends Node

var housing_number: int = 0
var apartment_number: int = 0

func add_number(type: String):
	match type:
		"Housing": housing_number += 1
		"Apartment": apartment_number += 1
		_: pass
