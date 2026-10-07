class_name Controller extends RefCounted

func debug_print(...args) -> void:
	if OS.is_debug_build():
		var s := ""
		for arg in args:
			s += " " + str(arg)
		print_debug(s)
