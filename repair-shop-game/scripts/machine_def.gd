class_name MachineDef
extends Resource

enum Era { HIEN_DAI, CO }

@export var era: Era = Era.HIEN_DAI
@export var brand: String = ""
@export var model: String = ""
@export var year: int = 0
@export var parts: PackedStringArray = PackedStringArray()
@export var faults: PackedStringArray = PackedStringArray()
@export var difficulty: int = 1
@export var base_price: int = 0
@export var customer_types: PackedStringArray = PackedStringArray()
@export var min_knowledge: int = 0
