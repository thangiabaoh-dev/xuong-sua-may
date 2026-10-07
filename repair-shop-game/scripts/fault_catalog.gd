class_name FaultCatalog
extends RefCounted

const CATALOG_DIR := "res://data/faults"

static var _cache: Array[FaultDef] = []
static var _cache_valid := false

static func load_all() -> Array[FaultDef]:
	if _cache_valid:
		return _cache
	_cache = scan_dir(CATALOG_DIR)
	_cache_valid = true
	return _cache

static func scan_dir(dir_path: String) -> Array[FaultDef]:
	var result: Array[FaultDef] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("FaultCatalog: cannot open dir '%s'" % dir_path)
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
		if res is FaultDef:
			result.append(res)
		else:
			push_error("FaultCatalog: failed to load '%s', skipped" % dir_path.path_join(file_name_sorted))
	return result

static func get_fault(key: String) -> FaultDef:
	for f in load_all():
		if f.key == key:
			return f
	return null
