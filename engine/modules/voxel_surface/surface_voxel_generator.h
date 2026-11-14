#pragma once

// The Surface's voxels (scripts/world/island_generator.gd, _generate_block):
// the baked map turned into 0.25 m blocks, in C++. IslandGenerator hands it
// the map layers, the block tables and every feature column it shaped
// (configure); after that it only reads, from any number of threads.
// It must produce exactly what the GDScript generator produces
// (tools/check_surface_generator.tscn compares them voxel by voxel).

#include "generators/voxel_generator.h"

#include "core/templates/hash_map.h"
#include "core/templates/local_vector.h"
#include "core/variant/dictionary.h"

class SurfaceVoxelGenerator : public zylann::voxel::VoxelGenerator {
	GDCLASS(SurfaceVoxelGenerator, zylann::voxel::VoxelGenerator)

public:
	bool configure(const Dictionary &p_config);
	bool is_configured() const { return _configured; }

	Result generate_block(VoxelQueryData input) override;
	int get_used_channels_mask() const override;

protected:
	static void _bind_methods();

private:
	static constexpr int N = 2048;
	static constexpr int HALF = 1024;
	static constexpr int FINE = 4;
	static constexpr int TILE = 4;
	static constexpr int FEATURE_CELL_SHIFT = 4;

	struct Layer {
		int top = 0;
		int under = 0;
		int depth = 0;
	};

	// A shaped feature column (meters): offset into _feature_values, or -1.
	struct FeatureCell {
		int index[256];
	};

	static double hash01(int64_t x, int64_t z, int64_t salt);

	bool inside(int64_t mx, int64_t mz) const {
		return mx >= -HALF && mz >= -HALF && mx < HALF && mz < HALF;
	}
	int64_t index(int64_t mx, int64_t mz) const;
	int64_t cell_height(int64_t mx, int64_t mz) const;
	int64_t cell_water(int64_t mx, int64_t mz) const;
	int cell_ground(int64_t mx, int64_t mz) const;
	int cell_biome(int64_t mx, int64_t mz) const;
	int cell_flags(int64_t mx, int64_t mz) const;
	int cell_shape(int64_t mx, int64_t mz) const;
	double cell_flora(int64_t mx, int64_t mz) const;
	Vector2i tile_range(int64_t fx, int64_t fz) const;
	int64_t fine_height(int64_t fx, int64_t fz) const;
	Layer layer(int mat, int biome_id) const;
	const int32_t *feature_detail(int64_t mx, int64_t mz) const;
	int64_t wall_beside(int64_t fx, int64_t fz, int64_t mx, int64_t mz) const;

	void fill(zylann::voxel::VoxelBuffer &buf, Vector3i origin, int lx, int lz, int64_t y0, int64_t y1, int value) const;
	void fill_overlays(zylann::voxel::VoxelBuffer &buf, Vector3i origin, int lx, int lz, int64_t fx, int64_t fz) const;
	void fill_feature(zylann::voxel::VoxelBuffer &buf, Vector3i origin, int lx, int lz, const int32_t *d, int deep) const;
	void fill_column(zylann::voxel::VoxelBuffer &buf, Vector3i origin, int lx, int lz, int64_t fx, int64_t fz, int64_t mx,
			int64_t mz, int deep) const;

	bool _configured = false;

	PackedByteArray _height;
	PackedByteArray _water;
	PackedByteArray _ground;
	PackedByteArray _biome;
	PackedByteArray _flora;
	PackedByteArray _flags;
	PackedByteArray _shape;
	PackedByteArray _tiles;

	// Fine column -> [y0, y1, block, ...] (voxels).
	HashMap<Vector2i, LocalVector<int32_t>> _overlays;
	// 16 x 16 m feature cell -> its 256 meter columns; values are
	// [h, top block, under block, segment count, y0, y1, block, ...].
	HashMap<Vector2i, FeatureCell> _features;
	LocalVector<int32_t> _feature_values;

	LocalVector<Layer> _layers; // by ground material
	Layer _layer_default;
	LocalVector<int> _biome_top; // by biome, for the DEFAULT material
	LocalVector<int> _biome_under;
	LocalVector<int> _deep; // by biome; -1 = STRATA_GREY

	int _max_height_voxels = 0;
	int _outside_ground = 0;
	int _outside_biome = 0;

	// Materials, flags, shape bits and blocks the column rules name.
	int _mat_default = 0, _mat_blue_moss = 0, _mat_ash = 0, _mat_lava = 0, _mat_farm = 0;
	int _flag_road = 0, _flag_trail = 0, _flag_town = 0, _flag_river = 0, _flag_bridge = 0, _busy = 0;
	int _shape_cliff = 0, _shape_vines = 0, _shape_rocky = 0;
	int _b_grass = 0, _b_grass_lush = 0, _b_meadow = 0, _b_yard = 0, _b_dirt_road = 0, _b_gravel_fine = 0;
	int _b_riverbed = 0, _b_blue_glow = 0, _b_ember = 0, _b_dirt_path = 0, _b_soil = 0, _b_river_stone = 0;
	int _b_vine = 0, _b_vine_flower = 0, _b_strata_grey = 0;
};
