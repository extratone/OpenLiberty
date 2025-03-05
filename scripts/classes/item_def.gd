class_name ItemDef
extends RefCounted

var model_name: String
var txd_name: String
var render_distance: float
var flags: int
var childs: Array[TDFX]
var colfile: ColFile

# LoD system additions
var lod_distances: Array[float] = []
var num_lods: int = 0
var is_big_building: bool = false
var related_model: ItemDef = null
