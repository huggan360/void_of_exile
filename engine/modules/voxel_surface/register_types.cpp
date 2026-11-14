#include "register_types.h"

#include "surface_voxel_generator.h"

#include "core/object/class_db.h"

void initialize_voxel_surface_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	// After the voxel module (modules register in name order: voxel, voxel_surface).
	GDREGISTER_CLASS(SurfaceVoxelGenerator);
}

void uninitialize_voxel_surface_module(ModuleInitializationLevel p_level) {}
