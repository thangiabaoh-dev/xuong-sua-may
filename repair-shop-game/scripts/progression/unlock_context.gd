class_name UnlockContext
extends RefCounted

var completed_projects: Array = []

func has_project(id: StringName) -> bool:
	return completed_projects.has(id)
