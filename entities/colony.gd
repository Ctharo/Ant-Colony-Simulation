class_name Colony
extends Node2D

var radius: float = 10.0
var foods: Foods

func area() -> float:
	return PI * radius * radius
