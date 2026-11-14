#include "surface_voxel_generator.h"

#include "storage/voxel_buffer.h"

#include "core/math/math_funcs.h"
#include "core/object/class_db.h"

#include <cmath>

using zylann::voxel::VoxelBuffer;

// --- Setup ------------------------------------------------------------------------------

namespace {

int int_of(const Dictionary &d, const char *key) {
	return int(d.get(key, 0));
}

bool layer_of(const Variant &v, int &top, int &under, int &depth) {
	const Array a = v;
	if (a.size() < 3) {
		return false;
	}
	top = a[0];
	under = a[1];
	depth = a[2];
	return true;
}

} // namespace

// config (IslandGenerator.native_config): map layers, block tables, the
// names the column rules use, overlays and the shaped feature columns.
bool SurfaceVoxelGenerator::configure(const Dictionary &p_config) {
	ERR_FAIL_COND_V_MSG(_configured, false, "SurfaceVoxelGenerator is configured once.");
	_height = p_config.get("height", PackedByteArray());
	_water = p_config.get("water", PackedByteArray());
	_ground = p_config.get("ground", PackedByteArray());
	_biome = p_config.get("biome", PackedByteArray());
	_flora = p_config.get("flora", PackedByteArray());
	_flags = p_config.get("flags", PackedByteArray());
	_shape = p_config.get("shape", PackedByteArray());
	_tiles = p_config.get("tiles", PackedByteArray());
	ERR_FAIL_COND_V(_height.size() != N * N * 2 || _water.size() != N * N * 2, false);
	ERR_FAIL_COND_V(_ground.size() != N * N || _biome.size() != N * N || _flora.size() != N * N, false);
	ERR_FAIL_COND_V(_flags.size() != N * N || _shape.size() != N * N, false);
	ERR_FAIL_COND_V(_tiles.size() != (N / TILE) * (N / TILE) * 4, false);

	const Dictionary names = p_config.get("names", Dictionary());
	_max_height_voxels = int_of(names, "max_height_voxels");
	_outside_ground = int_of(names, "outside_ground");
	_outside_biome = int_of(names, "outside_biome");
	_mat_default = int_of(names, "mat_default");
	_mat_blue_moss = int_of(names, "mat_blue_moss");
	_mat_ash = int_of(names, "mat_ash");
	_mat_lava = int_of(names, "mat_lava");
	_mat_farm = int_of(names, "mat_farm");
	_flag_road = int_of(names, "flag_road");
	_flag_trail = int_of(names, "flag_trail");
	_flag_town = int_of(names, "flag_town");
	_flag_river = int_of(names, "flag_river");
	_flag_bridge = int_of(names, "flag_bridge");
	_busy = int_of(names, "busy");
	_shape_cliff = int_of(names, "shape_cliff");
	_shape_vines = int_of(names, "shape_vines");
	_shape_rocky = int_of(names, "shape_rocky");
	_b_grass = int_of(names, "grass");
	_b_grass_lush = int_of(names, "grass_lush");
	_b_meadow = int_of(names, "meadow");
	_b_yard = int_of(names, "yard");
	_b_dirt_road = int_of(names, "dirt_road");
	_b_gravel_fine = int_of(names, "gravel_fine");
	_b_riverbed = int_of(names, "riverbed");
	_b_blue_glow = int_of(names, "blue_glow");
	_b_ember = int_of(names, "ember");
	_b_dirt_path = int_of(names, "dirt_path");
	_b_soil = int_of(names, "soil");
	_b_river_stone = int_of(names, "river_stone");
	_b_vine = int_of(names, "vine");
	_b_vine_flower = int_of(names, "vine_flower");
	_b_strata_grey = int_of(names, "strata_grey");

	// Ground material -> layer ([top, under, depth]); a missing one uses the default.
	const Dictionary layers = p_config.get("layers", Dictionary());
	layer_of(p_config.get("layer_default", Array()), _layer_default.top, _layer_default.under, _layer_default.depth);
	_layers.resize(256);
	for (int i = 0; i < 256; ++i) {
		_layers[i] = _layer_default;
		if (layers.has(i)) {
			layer_of(layers[i], _layers[i].top, _layers[i].under, _layers[i].depth);
		}
	}
	const PackedInt32Array biome_top = p_config.get("biome_top", PackedInt32Array());
	const PackedInt32Array biome_under = p_config.get("biome_under", PackedInt32Array());
	_biome_top.resize(biome_top.size());
	_biome_under.resize(biome_under.size());
	for (int i = 0; i < biome_top.size(); ++i) {
		_biome_top[i] = biome_top[i];
	}
	for (int i = 0; i < biome_under.size(); ++i) {
		_biome_under[i] = biome_under[i];
	}
	const Dictionary deep = p_config.get("deep", Dictionary());
	_deep.resize(256);
	for (int i = 0; i < 256; ++i) {
		_deep[i] = deep.has(i) ? int(deep[i]) : -1;
	}

	// Overlays: keys PackedInt32Array [fx, fz, ...], values Array of PackedInt32Array.
	const PackedInt32Array overlay_keys = p_config.get("overlay_keys", PackedInt32Array());
	const Array overlay_values = p_config.get("overlay_values", Array());
	ERR_FAIL_COND_V(overlay_keys.size() != overlay_values.size() * 2, false);
	_overlays.reserve(overlay_values.size());
	for (int i = 0; i < overlay_values.size(); ++i) {
		const PackedInt32Array segments = overlay_values[i];
		LocalVector<int32_t> list;
		list.resize(segments.size());
		for (int k = 0; k < segments.size(); ++k) {
			list[k] = segments[k];
		}
		_overlays.insert(Vector2i(overlay_keys[i * 2], overlay_keys[i * 2 + 1]), list);
	}

	// Feature columns: cells [cx, cz, ...]; per cell 256 offsets (-1 = not shaped) into values.
	const PackedInt32Array feature_cells = p_config.get("feature_cells", PackedInt32Array());
	const PackedInt32Array feature_index = p_config.get("feature_index", PackedInt32Array());
	const PackedInt32Array feature_values = p_config.get("feature_values", PackedInt32Array());
	ERR_FAIL_COND_V(feature_index.size() != (feature_cells.size() / 2) * 256, false);
	_features.reserve(feature_cells.size() / 2);
	for (int c = 0; c < feature_cells.size() / 2; ++c) {
		FeatureCell cell;
		for (int k = 0; k < 256; ++k) {
			cell.index[k] = feature_index[c * 256 + k];
		}
		_features.insert(Vector2i(feature_cells[c * 2], feature_cells[c * 2 + 1]), cell);
	}
	_feature_values.resize(feature_values.size());
	for (int i = 0; i < feature_values.size(); ++i) {
		_feature_values[i] = feature_values[i];
	}

	_configured = true;
	return true;
}

int SurfaceVoxelGenerator::get_used_channels_mask() const {
	return 1 << VoxelBuffer::CHANNEL_TYPE;
}

void SurfaceVoxelGenerator::_bind_methods() {
	ClassDB::bind_method(D_METHOD("configure", "config"), &SurfaceVoxelGenerator::configure);
	ClassDB::bind_method(D_METHOD("is_configured"), &SurfaceVoxelGenerator::is_configured);
}

// --- The map (SurfaceMap) -----------------------------------------------------------------

// SurfaceMap.hash01: GDScript ints are 64-bit and wrap; >> is arithmetic.
double SurfaceVoxelGenerator::hash01(int64_t x, int64_t z, int64_t salt) {
	int64_t n = int64_t(uint64_t(x) * 374761393ULL + uint64_t(z) * 668265263ULL + uint64_t(salt) * 982451653ULL);
	n = int64_t(uint64_t(n ^ (n >> 13)) * 1274126177ULL);
	n = n ^ (n >> 16);
	return double(n & 0xFFFFFF) / double(0xFFFFFF);
}

int64_t SurfaceVoxelGenerator::index(int64_t mx, int64_t mz) const {
	return CLAMP(mz + HALF, int64_t(0), int64_t(N - 1)) * N + CLAMP(mx + HALF, int64_t(0), int64_t(N - 1));
}

int64_t SurfaceVoxelGenerator::cell_height(int64_t mx, int64_t mz) const {
	if (!inside(mx, mz)) {
		return 12;
	}
	const uint8_t *p = _height.ptr() + index(mx, mz) * 2;
	return int64_t(p[0]) | (int64_t(p[1]) << 8);
}

int64_t SurfaceVoxelGenerator::cell_water(int64_t mx, int64_t mz) const {
	if (!inside(mx, mz)) {
		return 0;
	}
	const uint8_t *p = _water.ptr() + index(mx, mz) * 2;
	return int64_t(p[0]) | (int64_t(p[1]) << 8);
}

int SurfaceVoxelGenerator::cell_ground(int64_t mx, int64_t mz) const {
	return inside(mx, mz) ? _ground[index(mx, mz)] : _outside_ground;
}

int SurfaceVoxelGenerator::cell_biome(int64_t mx, int64_t mz) const {
	return inside(mx, mz) ? _biome[index(mx, mz)] : _outside_biome;
}

int SurfaceVoxelGenerator::cell_flags(int64_t mx, int64_t mz) const {
	return inside(mx, mz) ? _flags[index(mx, mz)] : 0;
}

int SurfaceVoxelGenerator::cell_shape(int64_t mx, int64_t mz) const {
	return inside(mx, mz) ? _shape[index(mx, mz)] : 0;
}

double SurfaceVoxelGenerator::cell_flora(int64_t mx, int64_t mz) const {
	return inside(mx, mz) ? _flora[index(mx, mz)] / 255.0 : 0.0;
}

Vector2i SurfaceVoxelGenerator::tile_range(int64_t fx, int64_t fz) const {
	const int64_t tx = (fx >> 4) + N / TILE / 2;
	const int64_t tz = (fz >> 4) + N / TILE / 2;
	if (tx < 0 || tz < 0 || tx >= N / TILE || tz >= N / TILE) {
		return Vector2i(0, 40);
	}
	const uint8_t *p = _tiles.ptr() + (tz * (N / TILE) + tx) * 4;
	return Vector2i(int(p[0]) | (int(p[1]) << 8), int(p[2]) | (int(p[3]) << 8));
}

// SurfaceMap.fine_height: blended between meter samples, ragged across walls.
int64_t SurfaceVoxelGenerator::fine_height(int64_t fx, int64_t fz) const {
	const int64_t mx = fx >> 2;
	const int64_t mz = fz >> 2;
	const double ux = (double(fx & 3) + 0.5) * 0.25 - 0.5;
	const double uz = (double(fz & 3) + 0.5) * 0.25 - 0.5;
	const int64_t ax = ux < 0.0 ? mx - 1 : mx;
	const int64_t az = uz < 0.0 ? mz - 1 : mz;
	const double tx = ux < 0.0 ? ux + 1.0 : ux;
	const double tz = uz < 0.0 ? uz + 1.0 : uz;
	const int64_t h00 = cell_height(ax, az);
	const int64_t h10 = cell_height(ax + 1, az);
	const int64_t h01 = cell_height(ax, az + 1);
	const int64_t h11 = cell_height(ax + 1, az + 1);
	const int64_t lo = MIN(MIN(h00, h10), MIN(h01, h11));
	const int64_t hi = MAX(MAX(h00, h10), MAX(h01, h11));
	if (hi - lo > 5) {
		const double jx = tx + (hash01(fx, fz, 3) - 0.5) * 0.45;
		const double jz = tz + (hash01(fx, fz, 4) - 0.5) * 0.45;
		return jx >= 0.5 ? (jz >= 0.5 ? h11 : h10) : (jz >= 0.5 ? h01 : h00);
	}
	// lerpf: from + (to - from) * weight, in doubles; roundi rounds half away from zero.
	const double a = double(h00) + (double(h10) - double(h00)) * tx;
	const double b = double(h01) + (double(h11) - double(h01)) * tx;
	return int64_t(std::round(a + (b - a) * tz));
}

SurfaceVoxelGenerator::Layer SurfaceVoxelGenerator::layer(int mat, int biome_id) const {
	if (mat == _mat_default) {
		Layer l;
		l.top = biome_id < int(_biome_top.size()) ? _biome_top[biome_id] : 0;
		l.under = biome_id < int(_biome_under.size()) ? _biome_under[biome_id] : 0;
		l.depth = 2;
		return l;
	}
	return _layers[mat & 255];
}

const int32_t *SurfaceVoxelGenerator::feature_detail(int64_t mx, int64_t mz) const {
	const FeatureCell *cell = _features.getptr(Vector2i(int(mx >> FEATURE_CELL_SHIFT), int(mz >> FEATURE_CELL_SHIFT)));
	if (cell == nullptr) {
		return nullptr;
	}
	const int i = cell->index[((mz & 15) << 4) | (mx & 15)];
	return i < 0 ? nullptr : _feature_values.ptr() + i;
}

int64_t SurfaceVoxelGenerator::wall_beside(int64_t fx, int64_t fz, int64_t mx, int64_t mz) const {
	int64_t best = 0;
	if ((fx & 3) == 3) {
		best = MAX(best, cell_height(mx + 1, mz));
	}
	if ((fx & 3) == 0) {
		best = MAX(best, cell_height(mx - 1, mz));
	}
	if ((fz & 3) == 3) {
		best = MAX(best, cell_height(mx, mz + 1));
	}
	if ((fz & 3) == 0) {
		best = MAX(best, cell_height(mx, mz - 1));
	}
	return best;
}

// --- Voxels (IslandGenerator._generate_block and its helpers) ------------------------------

// Fills voxel range [y0, y1) of one column, clipped to the buffer.
void SurfaceVoxelGenerator::fill(
		VoxelBuffer &buf, Vector3i origin, int lx, int lz, int64_t y0, int64_t y1, int value) const {
	const int64_t sy = buf.get_size().y;
	const int64_t a = CLAMP(y0 - origin.y, int64_t(0), sy);
	const int64_t b = CLAMP(y1 - origin.y, int64_t(0), sy);
	if (a < b) {
		buf.fill_area(value, Vector3i(lx, int(a), lz), Vector3i(lx + 1, int(b), lz + 1), VoxelBuffer::CHANNEL_TYPE);
	}
}

void SurfaceVoxelGenerator::fill_overlays(
		VoxelBuffer &buf, Vector3i origin, int lx, int lz, int64_t fx, int64_t fz) const {
	const LocalVector<int32_t> *list = _overlays.getptr(Vector2i(int(fx), int(fz)));
	if (list == nullptr) {
		return;
	}
	for (uint32_t i = 0; i + 2 < list->size(); i += 3) {
		fill(buf, origin, lx, lz, (*list)[i], (*list)[i + 1], (*list)[i + 2]);
	}
}

// A legacy feature column: 1 m blocks drawn 4 voxels to a side.
// d: [h, top, under, segment count, y0, y1, block, ...].
void SurfaceVoxelGenerator::fill_feature(
		VoxelBuffer &buf, Vector3i origin, int lx, int lz, const int32_t *d, int deep) const {
	const int64_t h = d[0];
	fill(buf, origin, lx, lz, -100000, (h - 2) * FINE, deep);
	fill(buf, origin, lx, lz, (h - 2) * FINE, h * FINE, d[2]);
	fill(buf, origin, lx, lz, h * FINE, (h + 1) * FINE, d[1]);
	const int segments = d[3];
	for (int i = 0; i < segments; ++i) {
		const int32_t *s = d + 4 + i * 3;
		fill(buf, origin, lx, lz, int64_t(s[0]) * FINE, int64_t(s[1]) * FINE, s[2]);
	}
}

void SurfaceVoxelGenerator::fill_column(VoxelBuffer &buf, Vector3i origin, int lx, int lz, int64_t fx, int64_t fz,
		int64_t mx, int64_t mz, int deep) const {
	int64_t top = fine_height(fx, fz);
	const int mat = cell_ground(mx, mz);
	const int biome_id = cell_biome(mx, mz);
	const int bits = cell_shape(mx, mz);
	const Layer l = layer(mat, biome_id);
	int top_block = l.top;
	const int under = l.under;
	int depth = l.depth;
	const int flags = cell_flags(mx, mz);
	const double r = hash01(fx, fz, 11);
	// Variety: lusher grass under the trees, meadows sprinkled with clover.
	if (top_block == _b_grass) {
		const double forest = cell_flora(mx, mz);
		if (forest > 0.55) {
			top_block = _b_grass_lush;
		} else if (r < 0.04) {
			top_block = _b_meadow;
		} else if ((flags & _flag_town) != 0 && r < 0.25) {
			top_block = _b_yard;
		}
	} else if (top_block == _b_dirt_road && r < 0.12) {
		top_block = _b_gravel_fine;
	} else if (top_block == _b_riverbed && r < 0.3) {
		top_block = _b_gravel_fine;
	} else if (mat == _mat_blue_moss && r < 0.012) {
		top_block = _b_blue_glow;
	} else if (mat == _mat_ash && r < 0.006) {
		top_block = _b_ember;
	} else if (mat == _mat_lava) {
		top -= 1;
	} else if (mat == _mat_farm && ((fz >> 1) & 1) == 1) {
		top -= 1; // furrows
	}
	// Stone walls show rock right under the grass lip.
	if ((bits & _shape_cliff) != 0 && (flags & (_flag_road | _flag_trail | _flag_bridge)) == 0) {
		depth = 0;
		if (top_block == _b_dirt_path || top_block == _b_soil) {
			top_block = deep;
		}
	}
	// Rough rock: a voxel up here and there.
	if ((bits & _shape_rocky) != 0 && r > 0.72 && (flags & _busy) == 0) {
		top += 1;
		if (r > 0.9) {
			top_block = depth == 0 ? deep : top_block;
		}
	}
	// Stones in the rivers, some breaking the surface.
	const int64_t w = cell_water(mx, mz);
	if (w > 0 && (flags & _flag_river) != 0 && (flags & _flag_bridge) == 0) {
		const double clump = hash01(fx >> 1, fz >> 1, 12);
		if (clump < 0.07) {
			static const int offsets[3] = { -2, -1, 1 };
			top = MAX(top, w + offsets[int64_t(clump * 40.0) % 3]);
			top_block = _b_river_stone;
			depth = 0;
		} else if (clump < 0.16) {
			top += 1;
			if (top == w) {
				top -= 2;
			}
			top_block = _b_river_stone;
		}
	}
	fill(buf, origin, lx, lz, -100000, top - 1 - depth, deep);
	if (depth > 0) {
		fill(buf, origin, lx, lz, top - 1 - depth, top - 1, under);
	}
	fill(buf, origin, lx, lz, top - 1, top, top_block);
	// Ivy on the walls: strands climbing from the foot of a wall.
	if ((bits & _shape_vines) != 0) {
		const int64_t wall = wall_beside(fx, fz, mx, mz);
		if (wall > top + 4 && hash01(fx, fz, 13) < 0.65) {
			const int64_t reach = int64_t(double(wall - top) * (0.35 + 0.65 * hash01(fx, fz, 14)));
			const int vine = hash01(fx, fz, 15) < 0.15 ? _b_vine_flower : _b_vine;
			fill(buf, origin, lx, lz, top, top + reach, vine);
		}
	}
	fill_overlays(buf, origin, lx, lz, fx, fz);
}

SurfaceVoxelGenerator::Result SurfaceVoxelGenerator::generate_block(VoxelQueryData input) {
	Result result;
	if (!_configured || input.lod != 0) {
		return result;
	}
	VoxelBuffer &out = input.voxel_buffer;
	const Vector3i origin = input.origin_in_voxels;
	const Vector3i size = out.get_size();
	const int64_t mx0 = int64_t(origin.x) >> 2;
	const int64_t mz0 = int64_t(origin.z) >> 2;
	const int64_t mx1 = (int64_t(origin.x) + size.x - 1) >> 2;
	const int64_t mz1 = (int64_t(origin.z) + size.z - 1) >> 2;
	bool featured = false;
	for (int64_t cz = mz0 >> FEATURE_CELL_SHIFT; cz <= (mz1 >> FEATURE_CELL_SHIFT) && !featured; ++cz) {
		for (int64_t cx = mx0 >> FEATURE_CELL_SHIFT; cx <= (mx1 >> FEATURE_CELL_SHIFT); ++cx) {
			if (_features.has(Vector2i(int(cx), int(cz)))) {
				featured = true;
				break;
			}
		}
	}
	Vector2i span = tile_range(origin.x, origin.z);
	if (size.x != 16 || size.z != 16) {
		span = Vector2i(0, _max_height_voxels);
	}
	if (origin.y >= span.y + (featured ? 100 : 0)) {
		return result; // all air
	}
	const int deep_entry = _deep[cell_biome(mx0 + 2, mz0 + 2) & 255];
	const int deep = deep_entry < 0 ? _b_strata_grey : deep_entry;
	if (!featured && origin.y + size.y <= span.x) {
		out.fill(deep, VoxelBuffer::CHANNEL_TYPE);
		return result;
	}
	for (int lz = 0; lz < size.z; ++lz) {
		for (int lx = 0; lx < size.x; ++lx) {
			const int64_t fx = int64_t(origin.x) + lx;
			const int64_t fz = int64_t(origin.z) + lz;
			const int64_t mx = fx >> 2;
			const int64_t mz = fz >> 2;
			if (featured) {
				const int32_t *d = feature_detail(mx, mz);
				if (d != nullptr) {
					fill_feature(out, origin, lx, lz, d, deep);
					fill_overlays(out, origin, lx, lz, fx, fz);
					continue;
				}
			}
			fill_column(out, origin, lx, lz, fx, fz, mx, mz, deep);
		}
	}
	return result;
}
