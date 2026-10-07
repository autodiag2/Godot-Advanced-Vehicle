class_name Controller extends RefCounted

var controller_debug_print_enabled := false

func debug_print(...args) -> void:
	if not controller_debug_print_enabled:
		return
	if OS.is_debug_build():
		var s := ""
		for arg in args:
			s += " " + str(arg)
		print(s)
