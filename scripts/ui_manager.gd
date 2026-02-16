extends Node
class_name UIManager

@export var notice_board_scene: PackedScene

var notice_board_instance: CanvasLayer

func open_notice_board():
    if notice_board_instance == null:
        notice_board_instance = notice_board_scene.instantiate()
        get_tree().root.add_child(notice_board_instance)
    
    notice_board_instance.visible = true
    get_tree().paused = true


func close_notice_board():
    if notice_board_instance:
        notice_board_instance.visible = false
        get_tree().paused = false
