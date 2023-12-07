@tool
extends Node3D

const __FLAGS := Mesh.ARRAY_FORMAT_VERTEX | Mesh.ARRAY_FORMAT_NORMAL | Mesh.ARRAY_FORMAT_TANGENT | Mesh.ARRAY_FORMAT_TEX_UV

@export var material: Material:
	set(v):
		material = v
		queue_rerender = true
@export var material_layer2: Material:
	set(v):
		material_layer2 = v
		queue_rerender = true
@export_range(0, 1, 0.01, "or_greater") var layer2_offset: float = 0.1:
	set(v):
		layer2_offset = v
		queue_rerender = true

var queue_rerender := true

var __inst: WasmInstance
@onready var __mesh: ArrayMesh = $Mesh.mesh
@onready var __skel: Skeleton3D = $Skeleton
var __ptr: int
var __vert_count := PackedInt32Array()

func __basis_to_arr(b: Basis) -> PackedVector3Array:
	return PackedVector3Array([b.x, b.y, b.z])

func queue_render() -> void:
	queue_rerender = true

func __render():
	if Engine.is_editor_hint():
		__mesh = $Mesh.mesh
		__skel = $Skeleton
		__inst = WasmHelper.load_wasm_file("", "res://model_wasm/model.wasm").instantiate(
			{
				write = {
					params = [
						WasmHelper.TYPE_I32,
						WasmHelper.TYPE_I32,
					],
					results = [],
					object = self,
					method = "__write",
				},
			},
			{
				"engine.use_epoch": true,
				"engine.epoch_timeout": 1,
			},
		)
		__ptr = __inst.call_wasm(&"init", [])[0]
	elif __inst == null:
		return

	var layer2 := material_layer2 != null
	__inst.put_8(__ptr + 0x58, 1 if layer2 else 0)
	__inst.put_float(__ptr + 0x5C, layer2_offset)
	var ba := PackedVector3Array()
	ba.append_array(__basis_to_arr(__skel.get_bone_pose(1).basis))
	ba.append_array(__basis_to_arr(__skel.get_bone_pose(3).basis))
	ba.append_array(__basis_to_arr(__skel.get_bone_pose(4).basis))
	ba.append_array(__basis_to_arr(__skel.get_bone_pose(6).basis))
	ba.append_array(__basis_to_arr(__skel.get_bone_pose(7).basis))
	ba.append_array(__basis_to_arr(__skel.get_bone_pose(9).basis))
	ba.append_array(__basis_to_arr(__skel.get_bone_pose(10).basis))
	ba.append_array(__basis_to_arr(__skel.get_bone_pose(12).basis))
	ba.append_array(__basis_to_arr(__skel.get_bone_pose(13).basis))
	__inst.put_array(__ptr + 0x60, ba)

	__inst.call_wasm("build", [])

	var c0 := __inst.get_32(__ptr)
	var c1 := __inst.get_32(__ptr + 44)
	var cnt := PackedInt32Array([c0, c1]) if layer2 else PackedInt32Array([c0])
	if __mesh.get_surface_count() != (2 if layer2 else 1) or cnt != __vert_count:
		__vert_count = cnt
		__mesh.clear_surfaces()

		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = __inst.get_array(
			__inst.get_32(__ptr + 4),
			c0,
			TYPE_PACKED_VECTOR3_ARRAY,
		)
		arr[Mesh.ARRAY_NORMAL] = __inst.get_array(
			__inst.get_32(__ptr + 8),
			c0,
			TYPE_PACKED_VECTOR3_ARRAY,
		)
		arr[Mesh.ARRAY_TANGENT] = __inst.get_array(
			__inst.get_32(__ptr + 12),
			c0 * 4,
			TYPE_PACKED_FLOAT32_ARRAY,
		)
		arr[Mesh.ARRAY_TEX_UV] = __inst.get_array(
			__inst.get_32(__ptr + 16),
			c0,
			TYPE_PACKED_VECTOR2_ARRAY,
		)
		arr[Mesh.ARRAY_INDEX] = __inst.get_array(
			__inst.get_32(__ptr + 24),
			__inst.get_32(__ptr + 20),
			TYPE_PACKED_INT32_ARRAY,
		)

		__mesh.add_surface_from_arrays(
			Mesh.PRIMITIVE_TRIANGLES,
			arr,
			[],
			{},
			__FLAGS,
		)
		__mesh.surface_set_material(0, material)

		if layer2:
			arr[Mesh.ARRAY_VERTEX] = __inst.get_array(
				__inst.get_32(__ptr + 48),
				c1,
				TYPE_PACKED_VECTOR3_ARRAY,
			)
			arr[Mesh.ARRAY_NORMAL] = __inst.get_array(
				__inst.get_32(__ptr + 52),
				c1,
				TYPE_PACKED_VECTOR3_ARRAY,
			)
			arr[Mesh.ARRAY_TANGENT] = __inst.get_array(
				__inst.get_32(__ptr + 56),
				c1 * 4,
				TYPE_PACKED_FLOAT32_ARRAY,
			)
			arr[Mesh.ARRAY_TEX_UV] = __inst.get_array(
				__inst.get_32(__ptr + 60),
				c1,
				TYPE_PACKED_VECTOR2_ARRAY,
			)
			arr[Mesh.ARRAY_INDEX] = __inst.get_array(
				__inst.get_32(__ptr + 68),
				__inst.get_32(__ptr + 64),
				TYPE_PACKED_INT32_ARRAY,
			)

			__mesh.add_surface_from_arrays(
				Mesh.PRIMITIVE_TRIANGLES,
				arr,
				[],
				{},
				__FLAGS,
			)
			__mesh.surface_set_material(1, material)

	else:
		__mesh.surface_update_vertex_region(
			0, 0,
			__inst.memory_read(
				__inst.get_32(__ptr + 32),
				__inst.get_32(__ptr + 28),
			),
		)
		__mesh.surface_update_attribute_region(
			0, 0,
			__inst.memory_read(
				__inst.get_32(__ptr + 40),
				__inst.get_32(__ptr + 36),
			),
		)
		if layer2:
			__mesh.surface_update_vertex_region(
				1, 0,
				__inst.memory_read(
					__inst.get_32(__ptr + 76),
					__inst.get_32(__ptr + 72),
				),
			)
			__mesh.surface_update_attribute_region(
				0, 0,
				__inst.memory_read(
					__inst.get_32(__ptr + 84),
					__inst.get_32(__ptr + 80),
				),
			)

	if Engine.is_editor_hint():
		__inst = null

func _ready():
	if Engine.is_editor_hint():
		return

	__inst = ModelGlobalInst.__inst
	__ptr = ModelGlobalInst.__ptr
	if __inst == null:
		return

func _process(_delta):
	if queue_rerender:
		__render()
		queue_rerender = false

func __write(ptr: int, sz: int) -> void:
	var buf: PackedByteArray = __inst.memory_read(ptr, sz)
	print(buf.get_string_from_utf8())
