extends Node

var money: int = 50000
var knowledge: int = 0
var uy_tin: int = 0
var ky_luat: int = 100

const NIGHT_BAN_THRESHOLD := 50
var inventory: Dictionary = {}

func night_banned() -> bool:
	return int(ky_luat) < NIGHT_BAN_THRESHOLD
