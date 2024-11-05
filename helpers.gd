class_name Helper
extends Node


## Helper function to convert snake_case to Title Case
static func snake_to_readable(text: String) -> String:
	# Replace underscores with spaces and capitalize each word
	var words = text.split("_")
	for i in range(words.size()):
		words[i] = words[i].capitalize() if i == 0 else words[i]
	return " ".join(words)
