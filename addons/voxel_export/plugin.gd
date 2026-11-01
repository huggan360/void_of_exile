@tool
extends EditorPlugin
## Imported VOX scenes do not contain the original bytes used by VoxModel.
class NativeVoxelExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "NativeVoxelSources"

	func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
		for folder in ["res://creatures", "res://characters", "res://props", "res://obstacles"]:
			_add_sources(folder)

	func _add_sources(folder: String) -> void:
		for file in DirAccess.get_files_at(folder):
			if file.ends_with(".vox"):
				var path := folder.path_join(file)
				add_file(path, FileAccess.get_file_as_bytes(path), false)
		for directory in DirAccess.get_directories_at(folder):
			if directory not in ["staging", "source_32"]:
				_add_sources(folder.path_join(directory))

var _exporter: NativeVoxelExport

func _enter_tree() -> void:
	_exporter = NativeVoxelExport.new()
	add_export_plugin(_exporter)

func _exit_tree() -> void:
	remove_export_plugin(_exporter)
