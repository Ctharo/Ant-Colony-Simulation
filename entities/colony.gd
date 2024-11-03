class_name Colony
extends Node2D

var _radius: float = 10.0
var foods: Foods

func area() -> float:
	return PI * _radius * _radius

func radius() -> float:
	return _radius
