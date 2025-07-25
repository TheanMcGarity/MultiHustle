extends Node

class_name MHLogger

static func mh_log(message: String, file_path: String):
	var file = File.new()
	var result = file.open(file_path, File.READ_WRITE)
	while result != OK:
		result = file.open(file_path, File.WRITE)
	
	var text = file.get_as_text()
	file.store_string(text + message + "\n")
	file.close()
