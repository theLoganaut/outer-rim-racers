## A Node2D that delegates _draw() to a callable, so one script can paint several layers in order.
class_name Painter
extends Node2D

var draw_fn: Callable


func _draw() -> void:
	if draw_fn.is_valid():
		draw_fn.call(self)
