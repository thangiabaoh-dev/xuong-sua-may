class_name MachineGenerator
extends RefCounted

const CATALOG_DIR := "res://data/machines"

static var _cache: Array[MachineDef] = []
static var _cache_valid := false

static func load_catalog() -> Array[MachineDef]:
	if _cache_valid:
		return _cache
	_cache = scan_dir(CATALOG_DIR)
	_cache_valid = true
	return _cache

static func scan_dir(dir_path: String) -> Array[MachineDef]:
	var result: Array[MachineDef] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("MachineGenerator: cannot open dir '%s'" % dir_path)
		return result
	var files: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "tres":
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	files.sort()
	for file_name_sorted in files:
		var res := load(dir_path.path_join(file_name_sorted))
		if res is MachineDef:
			result.append(res)
		else:
			push_error("MachineGenerator: failed to load '%s', skipped" % dir_path.path_join(file_name_sorted))
	return result
