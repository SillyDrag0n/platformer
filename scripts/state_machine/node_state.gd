class_name NodeState
extends Node

signal transition

func on_process(delta : float):
	return process_update(delta)


func process_update(_delta):
	return null


func on_physics_process(delta : float):
	return physics_update(delta)


func physics_update(_delta):
	return null


func enter():
	pass


func exit():
	pass
