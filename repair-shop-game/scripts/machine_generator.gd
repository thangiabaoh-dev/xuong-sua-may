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

static func candidates(knowledge: int, catalog: Array[MachineDef]) -> Array[MachineDef]:
	var result: Array[MachineDef] = []
	for m in catalog:
		if m.min_knowledge <= knowledge:
			result.append(m)
	return result

static func generate(rng: RandomNumberGenerator, knowledge: int) -> GeneratedMachine:
	var pool := candidates(knowledge, load_catalog())
	if pool.is_empty():
		push_warning("MachineGenerator: empty machine pool for knowledge %d" % knowledge)
		return null
	var def := pool[rng.randi_range(0, pool.size() - 1)]
	var gm := GeneratedMachine.new()
	gm.def = def
	gm.fault = StringName(def.faults[rng.randi_range(0, def.faults.size() - 1)])
	gm.price = def.base_price
	return gm
