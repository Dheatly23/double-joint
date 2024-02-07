extends Node

@onready var __file: WasmFile = load("res://model_wasm/model.wasm")
@onready var __inst: WasmInstance = __file.instantiate({}, {
	"epoch.enable": true,
	"epoch.timeout": 1,
})
var __ptr: int

func _ready():
	if __inst == null:
		return

	__ptr = __inst.call_wasm(&"init", [])[0]
