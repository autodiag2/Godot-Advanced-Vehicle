class_name Controller extends RefCounted

var controller_debug_print_enabled := false
var TAG_NAME := "CONTROLLER"

func debug_print(...args) -> void:
	if not controller_debug_print_enabled:
		return
	if OS.is_debug_build():
		var s := TAG_NAME + ":"
		for arg in args:
			s += " " + str(arg)
		print(s)
