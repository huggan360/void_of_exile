class_name CityCountry
## Vesperis outside its three city cores is farmland: patchwork fields (drawn
## by the ground shader), hand-placed farmsteads and the winding dirt roads
## between them and the cities. Everything is fixed data (directions from the
## planet centre, laid out once and free to edit by hand), the same on the
## server and every client.
const ROAD_HALF := 2.6  # half width of a country road (m)
const SAMPLE := 3.0  # metres between a road's mesh points
## Where a road from the fields meets a city's outer street (angle from its centre).
const CITY_EDGE := 0.166

## Farmsteads: [direction from the planet centre, the next point of a road leaving it].
const FARMS := [
	[Vector3(-0.2707, 0.9446, 0.1857), Vector3(-0.2954, 0.9509, 0.0922)],
	[Vector3(-0.0187, 0.9019, -0.4315), Vector3(0.0008, 0.9499, -0.3124)],
	[Vector3(0.4475, 0.8582, -0.2515), Vector3(0.4082, 0.8976, -0.1665)],
	[Vector3(-0.1442, 0.7665, 0.6259), Vector3(-0.2323, 0.7380, 0.6336)],
	[Vector3(-0.6512, 0.6990, 0.2956), Vector3(-0.7340, 0.6230, 0.2704)],
	[Vector3(0.3335, 0.6623, -0.6709), Vector3(0.3911, 0.5949, -0.7022)],
	[Vector3(0.1909, 0.6326, 0.7506), Vector3(0.2502, 0.6946, 0.6745)],
	[Vector3(-0.6716, 0.6073, -0.4244), Vector3(-0.6518, 0.5587, -0.5129)],
	[Vector3(0.7996, 0.5671, -0.1974), Vector3(0.8568, 0.4970, -0.1376)],
	[Vector3(-0.4571, 0.5847, 0.6702), Vector3(-0.3864, 0.6428, 0.6614)],
	[Vector3(-0.1051, 0.5388, -0.8359), Vector3(-0.0172, 0.4997, -0.8660)],
	[Vector3(0.6696, 0.4412, 0.5974), Vector3(0.6080, 0.3981, 0.6869)],
	[Vector3(-0.9019, 0.4269, 0.0652), Vector3(-0.9319, 0.3433, 0.1169)],
	[Vector3(0.5948, 0.4163, -0.6877), Vector3(0.5483, 0.4966, -0.6728)],
	[Vector3(-0.0219, 0.4140, 0.9100), Vector3(0.0652, 0.4827, 0.8733)],
	[Vector3(-0.5829, 0.3553, -0.7307), Vector3(-0.5291, 0.2979, -0.7945)],
	[Vector3(0.9352, 0.3333, 0.1191), Vector3(0.9065, 0.4183, 0.0581)],
	[Vector3(-0.7549, 0.3558, 0.5509), Vector3(-0.6967, 0.4415, 0.5654)],
	[Vector3(0.2387, 0.2198, -0.9459), Vector3(0.3413, 0.1898, -0.9206)],
	[Vector3(0.4744, 0.2780, 0.8353), Vector3(0.5629, 0.3154, 0.7640)],
	[Vector3(-0.9438, 0.1865, -0.2730), Vector3(-0.9581, 0.2282, -0.1730)],
	[Vector3(0.8662, 0.1731, -0.4688), Vector3(0.8766, 0.0756, -0.4753)],
	[Vector3(-0.4111, 0.0842, 0.9077), Vector3(-0.4759, -0.0006, 0.8795)],
	[Vector3(-0.3716, 0.0772, -0.9252), Vector3(-0.4091, 0.1714, -0.8962)],
	[Vector3(0.8963, 0.0269, 0.4425), Vector3(0.8568, -0.0399, 0.5140)],
	[Vector3(-0.9524, 0.0921, 0.2906), Vector3(-0.9442, 0.1963, 0.2645)],
	[Vector3(0.5660, -0.0106, -0.8243), Vector3(0.6335, -0.0670, -0.7709)],
	[Vector3(0.1449, 0.0290, 0.9890), Vector3(0.0907, 0.1231, 0.9882)],
	[Vector3(-0.7881, -0.0812, -0.6101), Vector3(-0.7861, -0.1943, -0.5868)],
	[Vector3(0.9938, -0.0826, -0.0740), Vector3(0.9877, -0.1558, 0.0086)],
	[Vector3(-0.6892, -0.1655, 0.7054), Vector3(-0.6471, -0.0756, 0.7586)],
	[Vector3(-0.0115, -0.1404, -0.9900), Vector3(0.0494, -0.2153, -0.9753)],
	[Vector3(0.6680, -0.1658, 0.7255), Vector3(0.5965, -0.2155, 0.7732)],
	[Vector3(-0.9648, -0.2596, -0.0429), Vector3(-0.9465, -0.2855, -0.1506)],
	[Vector3(0.8107, -0.1901, -0.5538), Vector3(0.8264, -0.0947, -0.5551)],
	[Vector3(-0.1930, -0.2891, 0.9376), Vector3(-0.2635, -0.3570, 0.8962)],
	[Vector3(-0.4686, -0.3325, -0.8184), Vector3(-0.3712, -0.3877, -0.8437)],
	[Vector3(0.8958, -0.3769, 0.2357), Vector3(0.8375, -0.4592, 0.2963)],
	[Vector3(-0.8410, -0.3990, 0.3655), Vector3(-0.8479, -0.4513, 0.2781)],
	[Vector3(0.2611, -0.3905, -0.8828), Vector3(0.1739, -0.3535, -0.9191)],
	[Vector3(0.3963, -0.4183, 0.8173), Vector3(0.3336, -0.4927, 0.8037)],
	[Vector3(-0.8043, -0.4540, -0.3833), Vector3(-0.7412, -0.5308, -0.4110)],
	[Vector3(0.8524, -0.4770, -0.2141), Vector3(0.8303, -0.5400, -0.1380)],
	[Vector3(-0.4523, -0.5354, 0.7133), Vector3(-0.4882, -0.5894, 0.6436)],
	[Vector3(-0.2144, -0.5426, -0.8122), Vector3(-0.3179, -0.4954, -0.8084)],
	[Vector3(0.6871, -0.6033, 0.4049), Vector3(0.7662, -0.5531, 0.3270)],
	[Vector3(-0.7693, -0.6362, 0.0584), Vector3(-0.7862, -0.5990, 0.1520)],
	[Vector3(0.4845, -0.6719, -0.5601), Vector3(0.4055, -0.7138, -0.5711)],
	[Vector3(0.0851, -0.6330, 0.7695), Vector3(0.1784, -0.6019, 0.7784)],
	[Vector3(-0.5045, -0.6875, -0.5224), Vector3(-0.4900, -0.7500, -0.4443)],
	[Vector3(0.6957, -0.7152, 0.0667), Vector3(0.7197, -0.6712, 0.1776)],
	[Vector3(-0.4913, -0.7601, 0.4254), Vector3(-0.4692, -0.7216, 0.5091)],
	[Vector3(0.1489, -0.7932, -0.5904), Vector3(0.2330, -0.7577, -0.6096)],
	[Vector3(0.3654, -0.8202, 0.4401), Vector3(0.4504, -0.7704, 0.4513)],
	[Vector3(-0.4856, -0.8580, -0.1675), Vector3(-0.5148, -0.8183, -0.2558)],
	[Vector3(0.3357, -0.9080, -0.2506), Vector3(0.2746, -0.9486, -0.1571)],
	[Vector3(-0.1021, -0.9179, 0.3835), Vector3(-0.2090, -0.9003, 0.3817)],
	[Vector3(-0.0791, -0.9678, -0.2388), Vector3(-0.0338, -0.9914, -0.1262)],
	[Vector3(0.1418, -0.9893, 0.0350), Vector3(0.0819, -0.9943, -0.0680)],
]
## Country roads: waypoints (unit directions), smoothed into curves at runtime.
const ROADS := [
	[Vector3(-0.0187, 0.9019, -0.4315), Vector3(0.0008, 0.9499, -0.3124), Vector3(0.0000, 0.9824, -0.1867)],
	[Vector3(-0.4686, -0.3325, -0.8184), Vector3(-0.3712, -0.3877, -0.8437), Vector3(-0.3179, -0.4954, -0.8084), Vector3(-0.2144, -0.5426, -0.8122)],
	[Vector3(0.1909, 0.6326, 0.7506), Vector3(0.2502, 0.6946, 0.6745), Vector3(0.3120, 0.7429, 0.5923), Vector3(0.3994, 0.7578, 0.5159)],
	[Vector3(0.1909, 0.6326, 0.7506), Vector3(0.1448, 0.5498, 0.8227), Vector3(0.0652, 0.4827, 0.8733), Vector3(-0.0219, 0.4140, 0.9100)],
	[Vector3(0.6696, 0.4412, 0.5974), Vector3(0.6080, 0.3981, 0.6869), Vector3(0.5629, 0.3154, 0.7640), Vector3(0.4744, 0.2780, 0.8353)],
	[Vector3(0.8958, -0.3769, 0.2357), Vector3(0.8375, -0.4592, 0.2963), Vector3(0.7662, -0.5531, 0.3270), Vector3(0.6871, -0.6033, 0.4049)],
	[Vector3(-0.0791, -0.9678, -0.2388), Vector3(-0.0338, -0.9914, -0.1262), Vector3(0.0819, -0.9943, -0.0680), Vector3(0.1418, -0.9893, 0.0350)],
	[Vector3(0.3357, -0.9080, -0.2506), Vector3(0.2746, -0.9486, -0.1571), Vector3(0.1798, -0.9802, -0.0831), Vector3(0.1418, -0.9893, 0.0350)],
	[Vector3(0.6871, -0.6033, 0.4049), Vector3(0.7199, -0.6306, 0.2899), Vector3(0.7197, -0.6712, 0.1776), Vector3(0.6957, -0.7152, 0.0667)],
	[Vector3(0.4845, -0.6719, -0.5601), Vector3(0.4055, -0.7138, -0.5711), Vector3(0.3167, -0.7228, -0.6142), Vector3(0.2330, -0.7577, -0.6096), Vector3(0.1489, -0.7932, -0.5904)],
	[Vector3(0.3335, 0.6623, -0.6709), Vector3(0.3911, 0.5949, -0.7022), Vector3(0.4829, 0.5588, -0.6742), Vector3(0.5483, 0.4966, -0.6728), Vector3(0.5948, 0.4163, -0.6877)],
	[Vector3(-0.1442, 0.7665, 0.6259), Vector3(-0.2323, 0.7380, 0.6336), Vector3(-0.3234, 0.7095, 0.6261), Vector3(-0.3864, 0.6428, 0.6614), Vector3(-0.4571, 0.5847, 0.6702)],
	[Vector3(-0.4523, -0.5354, 0.7133), Vector3(-0.4882, -0.5894, 0.6436), Vector3(-0.4817, -0.6581, 0.5787), Vector3(-0.4692, -0.7216, 0.5091), Vector3(-0.4913, -0.7601, 0.4254)],
	[Vector3(0.8662, 0.1731, -0.4688), Vector3(0.8766, 0.0756, -0.4753), Vector3(0.8573, -0.0106, -0.5146), Vector3(0.8264, -0.0947, -0.5551), Vector3(0.8107, -0.1901, -0.5538)],
	[Vector3(0.3963, -0.4183, 0.8173), Vector3(0.3336, -0.4927, 0.8037), Vector3(0.2689, -0.5638, 0.7809), Vector3(0.1784, -0.6019, 0.7784), Vector3(0.0851, -0.6330, 0.7695)],
	[Vector3(-0.1442, 0.7665, 0.6259), Vector3(-0.0472, 0.7595, 0.6488), Vector3(0.0202, 0.7081, 0.7059), Vector3(0.0926, 0.6561, 0.7489), Vector3(0.1909, 0.6326, 0.7506)],
	[Vector3(-0.2707, 0.9446, 0.1857), Vector3(-0.2954, 0.9509, 0.0922), Vector3(-0.3552, 0.9347, 0.0131), Vector3(-0.3978, 0.9147, -0.0716), Vector3(-0.3994, 0.9007, -0.1710)],
	[Vector3(0.6680, -0.1658, 0.7255), Vector3(0.5965, -0.2155, 0.7732), Vector3(0.5552, -0.3179, 0.7686), Vector3(0.4824, -0.3767, 0.7908), Vector3(0.3963, -0.4183, 0.8173)],
	[Vector3(0.4475, 0.8582, -0.2515), Vector3(0.4082, 0.8976, -0.1665), Vector3(0.3269, 0.9369, -0.1238), Vector3(0.2346, 0.9681, -0.0884), Vector3(0.1867, 0.9824, 0.0000)],
	[Vector3(-0.0115, -0.1404, -0.9900), Vector3(0.0494, -0.2153, -0.9753), Vector3(0.0973, -0.3007, -0.9487), Vector3(0.1739, -0.3535, -0.9191), Vector3(0.2611, -0.3905, -0.8828)],
	[Vector3(0.6871, -0.6033, 0.4049), Vector3(0.6093, -0.6555, 0.4461), Vector3(0.5282, -0.7068, 0.4706), Vector3(0.4504, -0.7704, 0.4513), Vector3(0.3654, -0.8202, 0.4401)],
	[Vector3(-0.4571, 0.5847, 0.6702), Vector3(-0.5327, 0.5126, 0.6734), Vector3(-0.6195, 0.4839, 0.6182), Vector3(-0.6967, 0.4415, 0.5654), Vector3(-0.7549, 0.3558, 0.5509)],
	[Vector3(-0.5045, -0.6875, -0.5224), Vector3(-0.4900, -0.7500, -0.4443), Vector3(-0.5377, -0.7708, -0.3417), Vector3(-0.5148, -0.8183, -0.2558), Vector3(-0.4856, -0.8580, -0.1675)],
	[Vector3(-0.8410, -0.3990, 0.3655), Vector3(-0.8479, -0.4513, 0.2781), Vector3(-0.8214, -0.5278, 0.2161), Vector3(-0.7862, -0.5990, 0.1520), Vector3(-0.7693, -0.6362, 0.0584)],
	[Vector3(-0.5829, 0.3553, -0.7307), Vector3(-0.5291, 0.2979, -0.7945), Vector3(-0.4559, 0.2506, -0.8540), Vector3(-0.4091, 0.1714, -0.8962), Vector3(-0.3716, 0.0772, -0.9252)],
	[Vector3(0.8524, -0.4770, -0.2141), Vector3(0.8303, -0.5400, -0.1380), Vector3(0.7794, -0.6199, -0.0909), Vector3(0.7309, -0.6819, -0.0273), Vector3(0.6957, -0.7152, 0.0667)],
	[Vector3(0.1489, -0.7932, -0.5904), Vector3(0.1750, -0.8464, -0.5030), Vector3(0.2062, -0.8871, -0.4130), Vector3(0.2761, -0.9008, -0.3351), Vector3(0.3357, -0.9080, -0.2506)],
	[Vector3(-0.8043, -0.4540, -0.3833), Vector3(-0.7412, -0.5308, -0.4110), Vector3(-0.6673, -0.5753, -0.4730), Vector3(-0.5872, -0.6209, -0.5193), Vector3(-0.5045, -0.6875, -0.5224)],
	[Vector3(-0.6716, 0.6073, -0.4244), Vector3(-0.6518, 0.5587, -0.5129), Vector3(-0.6678, 0.4683, -0.5786), Vector3(-0.6374, 0.4066, -0.6545), Vector3(-0.5829, 0.3553, -0.7307)],
	[Vector3(0.5660, -0.0106, -0.8243), Vector3(0.6335, -0.0670, -0.7709), Vector3(0.7164, -0.0697, -0.6942), Vector3(0.7723, -0.1191, -0.6240), Vector3(0.8107, -0.1901, -0.5538)],
	[Vector3(-0.9019, 0.4269, 0.0652), Vector3(-0.9319, 0.3433, 0.1169), Vector3(-0.9393, 0.2774, 0.2017), Vector3(-0.9442, 0.1963, 0.2645), Vector3(-0.9524, 0.0921, 0.2906)],
	[Vector3(0.8963, 0.0269, 0.4425), Vector3(0.8568, -0.0399, 0.5140), Vector3(0.8095, -0.1136, 0.5760), Vector3(0.7390, -0.1245, 0.6622), Vector3(0.6680, -0.1658, 0.7255)],
	[Vector3(0.7996, 0.5671, -0.1974), Vector3(0.8568, 0.4970, -0.1376), Vector3(0.8963, 0.4394, -0.0595), Vector3(0.9065, 0.4183, 0.0581), Vector3(0.9352, 0.3333, 0.1191)],
	[Vector3(-0.9019, 0.4269, 0.0652), Vector3(-0.9178, 0.3953, -0.0383), Vector3(-0.9512, 0.2947, -0.0919), Vector3(-0.9581, 0.2282, -0.1730), Vector3(-0.9438, 0.1865, -0.2730)],
	[Vector3(0.2387, 0.2198, -0.9459), Vector3(0.3413, 0.1898, -0.9206), Vector3(0.4226, 0.1267, -0.8974), Vector3(0.4767, 0.0227, -0.8788), Vector3(0.5660, -0.0106, -0.8243)],
	[Vector3(-0.7549, 0.3558, 0.5509), Vector3(-0.8135, 0.2677, 0.5163), Vector3(-0.8682, 0.2036, 0.4524), Vector3(-0.9180, 0.1625, 0.3617), Vector3(-0.9524, 0.0921, 0.2906)],
	[Vector3(-0.4913, -0.7601, 0.4254), Vector3(-0.4063, -0.8234, 0.3961), Vector3(-0.3150, -0.8746, 0.3685), Vector3(-0.2090, -0.9003, 0.3817), Vector3(-0.1021, -0.9179, 0.3835)],
	[Vector3(-0.1930, -0.2891, 0.9376), Vector3(-0.2635, -0.3570, 0.8962), Vector3(-0.3050, -0.4456, 0.8417), Vector3(-0.3679, -0.5055, 0.7805), Vector3(-0.4523, -0.5354, 0.7133)],
	[Vector3(-0.9648, -0.2596, -0.0429), Vector3(-0.9465, -0.2855, -0.1506), Vector3(-0.9119, -0.3333, -0.2394), Vector3(-0.8603, -0.4088, -0.3045), Vector3(-0.8043, -0.4540, -0.3833)],
	[Vector3(-0.4111, 0.0842, 0.9077), Vector3(-0.4759, -0.0006, 0.8795), Vector3(-0.5703, -0.0298, 0.8209), Vector3(-0.6471, -0.0756, 0.7586), Vector3(-0.6892, -0.1655, 0.7054)],
	[Vector3(-0.7693, -0.6362, 0.0584), Vector3(-0.7226, -0.6906, -0.0285), Vector3(-0.6555, -0.7502, -0.0868), Vector3(-0.5676, -0.8154, -0.1135), Vector3(-0.4856, -0.8580, -0.1675)],
	[Vector3(0.5948, 0.4163, -0.6877), Vector3(0.6811, 0.3877, -0.6212), Vector3(0.7512, 0.3175, -0.5787), Vector3(0.8069, 0.2203, -0.5481), Vector3(0.8662, 0.1731, -0.4688)],
	[Vector3(-0.3716, 0.0772, -0.9252), Vector3(-0.2781, 0.0351, -0.9599), Vector3(-0.2184, -0.0714, -0.9733), Vector3(-0.1116, -0.0994, -0.9888), Vector3(-0.0115, -0.1404, -0.9900)],
	[Vector3(-0.0219, 0.4140, 0.9100), Vector3(-0.0087, 0.3103, 0.9506), Vector3(0.0197, 0.2092, 0.9777), Vector3(0.0907, 0.1231, 0.9882), Vector3(0.1449, 0.0290, 0.9890)],
	[Vector3(-0.4856, -0.8580, -0.1675), Vector3(-0.3894, -0.9019, -0.1872), Vector3(-0.2850, -0.9429, -0.1721), Vector3(-0.1814, -0.9648, -0.1905), Vector3(-0.0791, -0.9678, -0.2388)],
	[Vector3(0.4475, 0.8582, -0.2515), Vector3(0.4554, 0.8784, -0.1452), Vector3(0.4019, 0.9145, -0.0462), Vector3(0.3893, 0.9191, 0.0605), Vector3(0.3994, 0.9007, 0.1710)],
	[Vector3(-0.1021, -0.9179, 0.3835), Vector3(-0.0159, -0.9482, 0.3173), Vector3(0.0600, -0.9688, 0.2405), Vector3(0.0960, -0.9862, 0.1350), Vector3(0.1418, -0.9893, 0.0350)],
	[Vector3(-0.4111, 0.0842, 0.9077), Vector3(-0.3906, -0.0280, 0.9201), Vector3(-0.3075, -0.1038, 0.9459), Vector3(-0.2241, -0.1805, 0.9577), Vector3(-0.1930, -0.2891, 0.9376)],
	[Vector3(-0.3716, 0.0772, -0.9252), Vector3(-0.4285, -0.0181, -0.9033), Vector3(-0.4729, -0.1156, -0.8735), Vector3(-0.4698, -0.2268, -0.8531), Vector3(-0.4686, -0.3325, -0.8184)],
	[Vector3(-0.2144, -0.5426, -0.8122), Vector3(-0.2715, -0.6128, -0.7421), Vector3(-0.3569, -0.6423, -0.6783), Vector3(-0.4602, -0.6392, -0.6161), Vector3(-0.5045, -0.6875, -0.5224)],
	[Vector3(-0.6512, 0.6990, 0.2956), Vector3(-0.7340, 0.6230, 0.2704), Vector3(-0.7973, 0.5723, 0.1918), Vector3(-0.8468, 0.5230, 0.0968), Vector3(-0.9019, 0.4269, 0.0652)],
	[Vector3(-0.7881, -0.0812, -0.6101), Vector3(-0.7861, -0.1943, -0.5868), Vector3(-0.8181, -0.2726, -0.5064), Vector3(-0.8349, -0.3505, -0.4244), Vector3(-0.8043, -0.4540, -0.3833)],
	[Vector3(0.9938, -0.0826, -0.0740), Vector3(0.9877, -0.1558, 0.0086), Vector3(0.9726, -0.2006, 0.1173), Vector3(0.9371, -0.3123, 0.1560), Vector3(0.8958, -0.3769, 0.2357)],
	[Vector3(0.4744, 0.2780, 0.8353), Vector3(0.3779, 0.2470, 0.8923), Vector3(0.3014, 0.1794, 0.9365), Vector3(0.2442, 0.0775, 0.9666), Vector3(0.1449, 0.0290, 0.9890)],
	[Vector3(0.2387, 0.2198, -0.9459), Vector3(0.2000, 0.1160, -0.9729), Vector3(0.1570, 0.0120, -0.9875), Vector3(0.0722, -0.0638, -0.9953), Vector3(-0.0115, -0.1404, -0.9900)],
	[Vector3(0.8107, -0.1901, -0.5538), Vector3(0.8447, -0.2361, -0.4803), Vector3(0.8482, -0.3127, -0.4276), Vector3(0.8362, -0.3967, -0.3787), Vector3(0.8432, -0.4446, -0.3022), Vector3(0.8524, -0.4770, -0.2141)],
	[Vector3(0.9352, 0.3333, 0.1191), Vector3(0.9441, 0.2726, 0.1854), Vector3(0.9530, 0.1921, 0.2344), Vector3(0.9492, 0.1206, 0.2907), Vector3(0.9277, 0.0720, 0.3663), Vector3(0.8963, 0.0269, 0.4425)],
	[Vector3(0.8963, 0.0269, 0.4425), Vector3(0.9072, -0.0608, 0.4162), Vector3(0.9237, -0.1339, 0.3591), Vector3(0.9327, -0.2048, 0.2968), Vector3(0.9223, -0.2874, 0.2584), Vector3(0.8958, -0.3769, 0.2357)],
	[Vector3(-0.9438, 0.1865, -0.2730), Vector3(-0.9243, 0.1439, -0.3535), Vector3(-0.8892, 0.1185, -0.4420), Vector3(-0.8616, 0.0556, -0.5046), Vector3(-0.8350, -0.0297, -0.5494), Vector3(-0.7881, -0.0812, -0.6101)],
	[Vector3(-0.2707, 0.9446, 0.1857), Vector3(-0.3570, 0.9114, 0.2047), Vector3(-0.4470, 0.8716, 0.2012), Vector3(-0.5269, 0.8227, 0.2134), Vector3(-0.5920, 0.7645, 0.2549), Vector3(-0.6512, 0.6990, 0.2956)],
	[Vector3(-0.1051, 0.5388, -0.8359), Vector3(-0.0172, 0.4997, -0.8660), Vector3(0.0401, 0.4280, -0.9029), Vector3(0.0806, 0.3370, -0.9381), Vector3(0.1515, 0.2716, -0.9504), Vector3(0.2387, 0.2198, -0.9459)],
	[Vector3(0.4845, -0.6719, -0.5601), Vector3(0.4277, -0.7487, -0.5064), Vector3(0.4377, -0.8039, -0.4027), Vector3(0.4058, -0.8570, -0.3175), Vector3(0.3357, -0.9080, -0.2506)],
	[Vector3(-0.9648, -0.2596, -0.0429), Vector3(-0.9337, -0.3582, -0.0025), Vector3(-0.8867, -0.4623, -0.0078), Vector3(-0.8303, -0.5573, 0.0025), Vector3(-0.7693, -0.6362, 0.0584)],
	[Vector3(-0.6512, 0.6990, 0.2956), Vector3(-0.6099, 0.6859, 0.3969), Vector3(-0.5399, 0.6853, 0.4887), Vector3(-0.4910, 0.6494, 0.5807), Vector3(-0.4571, 0.5847, 0.6702)],
	[Vector3(-0.6892, -0.1655, 0.7054), Vector3(-0.6209, -0.2506, 0.7428), Vector3(-0.5737, -0.3516, 0.7398), Vector3(-0.5415, -0.4630, 0.7017), Vector3(-0.4523, -0.5354, 0.7133)],
	[Vector3(-0.6892, -0.1655, 0.7054), Vector3(-0.7586, -0.2012, 0.6197), Vector3(-0.7978, -0.2678, 0.5402), Vector3(-0.8136, -0.3524, 0.4625), Vector3(-0.8410, -0.3990, 0.3655)],
	[Vector3(0.9938, -0.0826, -0.0740), Vector3(0.9749, -0.1773, -0.1345), Vector3(0.9465, -0.2872, -0.1468), Vector3(0.9058, -0.3931, -0.1581), Vector3(0.8524, -0.4770, -0.2141)],
	[Vector3(-0.9648, -0.2596, -0.0429), Vector3(-0.9583, -0.2820, 0.0454), Vector3(-0.9478, -0.2866, 0.1398), Vector3(-0.9241, -0.3092, 0.2243), Vector3(-0.8860, -0.3574, 0.2955), Vector3(-0.8410, -0.3990, 0.3655)],
	[Vector3(-0.1867, 0.9824, 0.0000), Vector3(-0.2854, 0.9578, 0.0336), Vector3(-0.3706, 0.9249, 0.0851), Vector3(-0.4411, 0.8841, 0.1544), Vector3(-0.5064, 0.8331, 0.2225), Vector3(-0.5765, 0.7712, 0.2698), Vector3(-0.6512, 0.6990, 0.2956)],
	[Vector3(0.0000, 0.9824, 0.1867), Vector3(-0.0385, 0.9593, 0.2799), Vector3(-0.1029, 0.9265, 0.3619), Vector3(-0.1261, 0.8828, 0.4525), Vector3(-0.1176, 0.8283, 0.5478), Vector3(-0.1442, 0.7665, 0.6259)],
	[Vector3(-0.2288, 0.8994, -0.3725), Vector3(-0.1602, 0.8813, -0.4445), Vector3(-0.0744, 0.8672, -0.4924), Vector3(0.0294, 0.8576, -0.5134), Vector3(0.1235, 0.8320, -0.5409), Vector3(0.1927, 0.7810, -0.5941), Vector3(0.2553, 0.7182, -0.6473), Vector3(0.3335, 0.6623, -0.6709)],
	[Vector3(-0.5699, 0.7592, -0.3145), Vector3(-0.6482, 0.7137, -0.2654), Vector3(-0.7119, 0.6748, -0.1945), Vector3(-0.7639, 0.6356, -0.1118), Vector3(-0.8116, 0.5831, -0.0372), Vector3(-0.8593, 0.5112, 0.0188), Vector3(-0.9019, 0.4269, 0.0652)],
	[Vector3(-0.3994, 0.7578, -0.5159), Vector3(-0.3337, 0.7369, -0.5879), Vector3(-0.3114, 0.6720, -0.6719), Vector3(-0.2634, 0.6184, -0.7404), Vector3(-0.1675, 0.5956, -0.7856), Vector3(-0.1051, 0.5388, -0.8359)],
	[Vector3(0.5699, 0.7592, 0.3145), Vector3(0.6280, 0.7421, 0.2344), Vector3(0.6948, 0.7000, 0.1652), Vector3(0.7446, 0.6620, 0.0859), Vector3(0.7663, 0.6424, -0.0131), Vector3(0.7772, 0.6188, -0.1142), Vector3(0.7996, 0.5671, -0.1974)],
	[Vector3(0.2288, 0.8994, 0.3725), Vector3(0.1703, 0.8777, 0.4480), Vector3(0.0819, 0.8688, 0.4883), Vector3(-0.0170, 0.8582, 0.5131), Vector3(-0.0866, 0.8200, 0.5658), Vector3(-0.1442, 0.7665, 0.6259)],
]

static var _curves: Array = []
static var _frames := {}
static var _cells: ImageTexture
static var _mask: ImageTexture
static var _mask_image: Image
static var _road_image: Image  # the roads alone, for trees that may stand in a yard
const MASK_SIZE := 1024  # texels a face side in mask_texture()
const MASK_REACH := 0.62  # the face coordinate (over the radius) at its texture's edge

## Every road as a dense polyline of unit directions (Catmull-Rom through its
## waypoints), ends at a city run on to the city's outer street.
static func curves() -> Array:
	if not _curves.is_empty(): return _curves
	var r := CityLayout.radius()
	# Connect the relocated towns to the existing rural network.
	var roads: Array = ROADS.duplicate(true)
	for d: Dictionary in CityLayout.DISTRICTS:
		var center := CityLayout.district_frame(d).origin.normalized()
		var nearest := Vector3.UP
		var distance := INF
		for road: Array in ROADS:
			for point: Vector3 in road:
				var angle := center.angle_to(point)
				if angle<distance:
					distance = angle
					nearest = point
		var edge_angle := float(d.extent)*PI/(2.0*CityLayout.N)
		if distance>edge_angle:
			var edge := center.slerp(nearest, edge_angle/distance)
			roads.append([edge, edge.slerp(nearest, 0.5), nearest])
	for road: Array in roads:
		var pts: Array[Vector3] = []
		for p: Vector3 in road: pts.append(p)
		for end in [0, pts.size()-1]:
			for d: Dictionary in CityLayout.DISTRICTS:
				var c := CityLayout.district_frame(d).origin.normalized()
				var at: Vector3 = pts[end]
				var angle := at.angle_to(c)
				var edge_angle := float(d.extent)*PI/(2.0*CityLayout.N)
				if angle>0.001 and angle<0.21:
					var edge := c.slerp(at, edge_angle/angle)
					if end==0: pts.insert(0, edge)
					else: pts.append(edge)
		var out: Array[Vector3] = []
		for k in pts.size()-1:
			var p0 := pts[maxi(k-1, 0)]
			var p1 := pts[k]
			var p2 := pts[k+1]
			var p3 := pts[mini(k+2, pts.size()-1)]
			var steps := maxi(1, ceili(p1.angle_to(p2)*r/SAMPLE))
			for s in steps:
				var t := float(s)/steps
				var t2 := t*t
				var t3 := t2*t
				var q := 0.5*((2.0*p1)+(-p0+p2)*t+(2.0*p0-5.0*p1+4.0*p2-p3)*t2+(-p0+3.0*p1-3.0*p2+p3)*t3)
				out.append(q.normalized())
		out.append(pts[-1])
		_curves.append(out)
	return _curves

## A farmstead's yard frame (planet space, on the ground): +Z points into the
## widest gap between the roads that leave it, where the buildings stand.
static func farm_frame(k: int) -> Transform3D:
	if _frames.has(k): return _frames[k]
	var dir: Vector3 = FARMS[k][0]
	var frame := CityLayout._tangent(dir, FARMS[k][1])
	var angles: Array[float] = []
	for road: Array in ROADS:
		var next: Vector3 = Vector3.INF
		if (road[0] as Vector3).distance_to(dir)<0.0005: next = road[1]
		elif (road[-1] as Vector3).distance_to(dir)<0.0005: next = road[-2]
		if not next.is_finite(): continue
		var local := frame.basis.inverse()*(next-dir)
		angles.append(atan2(local.x, local.z))
	var bisector := PI
	if not angles.is_empty():
		angles.sort()
		var best := -1.0
		for i in angles.size():
			var a := angles[i]
			var b := angles[(i+1) % angles.size()]+(TAU if i==angles.size()-1 else 0.0)
			if b-a>best:
				best = b-a
				bisector = (a+b)*0.5
	var out := Transform3D(frame.basis*Basis(Vector3.UP, bisector), frame.origin)
	_frames[k] = out
	return out

## Where no crops, hedges or trees grow (farm_flora.gdshader): the roads, the
## farmyards and the city cores, stamped onto each cube face (faces stacked
## top to bottom, the same face choice and axes as the ground shader).
static func mask_texture() -> ImageTexture:
	if _mask: return _mask
	var image := Image.create(MASK_SIZE, MASK_SIZE*6, false, Image.FORMAT_R8)
	for curve: Array in curves():
		for dir: Vector3 in curve: _stamp(image, dir, ROAD_HALF+1.8)
	_road_image = image.duplicate()
	for k in FARMS.size():
		var frame := farm_frame(k)
		for z: float in [0.0, 16.0, 32.0, 48.0, 64.0]: _stamp(image, (frame*Vector3(0, 0, z)).normalized(), 32.0)
	var n := CityLayout.N
	for face in 6:
		for j in n:
			for i in n:
				# The cities and the ring of streets round them.
				if CityLayout.role(face, i, j)!="farm": _stamp(image, (CityLayout.cell(face, i, j).frame as Transform3D).origin.normalized(), 54.0)
	_mask_image = image
	_mask = ImageTexture.create_from_image(image)
	return _mask

static func _stamp(image: Image, dir: Vector3, radius: float) -> void:
	var texel := 2.0*MASK_REACH*CityLayout.radius()/MASK_SIZE
	var reach := ceili(radius/texel)
	for face in 6:
		var n: Vector3 = CityLayout.FACES[face]
		if dir.dot(n)<0.45: continue
		var ax := Vector3(n.y, n.z, n.x)
		var bx := n.cross(ax)
		var uv := Vector2(dir.dot(ax), dir.dot(bx))/MASK_REACH*0.5+Vector2(0.5, 0.5)
		if uv.x<-0.05 or uv.y<-0.05 or uv.x>1.05 or uv.y>1.05: continue
		var at := Vector2i(uv*MASK_SIZE)
		var rect := Rect2i(at-Vector2i(reach, reach), Vector2i(reach*2+1, reach*2+1)).intersection(Rect2i(0, 0, MASK_SIZE, MASK_SIZE))
		if rect.size.x<=0 or rect.size.y<=0: continue
		image.fill_rect(Rect2i(rect.position+Vector2i(0, face*MASK_SIZE), rect.size), Color(1, 0, 0))

# --- The fields (mirrors shaders/farm_fields.gdshaderinc exactly) ---------------------------

const FIELD_SIZE := 40.0
const M32 := 0xFFFFFFFF

static func hash3i(c: Vector3i, salt: int) -> Vector3:
	var x := (c.x+salt*7919) & M32
	var y := (c.y+salt*104729) & M32
	var z := (c.z+salt*1299709) & M32
	x = (x*1664525+1013904223) & M32
	y = (y*1664525+1013904223) & M32
	z = (z*1664525+1013904223) & M32
	x = (x+y*z) & M32
	y = (y+z*x) & M32
	z = (z+x*y) & M32
	x ^= x >> 16
	y ^= y >> 16
	z ^= z >> 16
	x = (x+y*z) & M32
	y = (y+z*x) & M32
	z = (z+x*y) & M32
	return Vector3(x, y, z)/4294967295.0

## The field at p (planet space, on the ground): [kind (0 wheat, 1 green crop,
## 2 ploughed, 3 meadow), metres to its border, the border is a hedge, shade,
## row direction hash].
static func field(p: Vector3) -> Array:
	var w := p+Vector3(sin(p.y*0.031+p.z*0.017), sin(p.z*0.027+p.x*0.021), sin(p.x*0.029+p.y*0.019))*7.0 \
		+Vector3(sin(p.z*0.11), sin(p.x*0.13), sin(p.y*0.12))*1.6
	var g := Vector3i(floori(w.x/FIELD_SIZE), floori(w.y/FIELD_SIZE), floori(w.z/FIELD_SIZE))
	var d1 := 1e9
	var d2 := 1e9
	var c1 := g
	var c2 := g
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				var cell := g+Vector3i(x, y, z)
				var seed := (Vector3(cell)+Vector3.ONE*0.1+0.8*hash3i(cell, 0))*FIELD_SIZE
				var d := w.distance_to(seed)
				if d<d1:
					d2 = d1
					c2 = c1
					d1 = d
					c1 = cell
				elif d<d2:
					d2 = d
					c2 = cell
	var id := hash3i(c1, 1)
	var id2 := hash3i(c2, 1)
	var farm_id := hash3i(Vector3i(floori(w.x/130.0), floori(w.y/130.0), floori(w.z/130.0)), 2)
	if hash3i(c1, 3).x<0.55: id.x = farm_id.x
	if hash3i(c2, 3).x<0.55: id2.x = farm_id.x
	var kind1 := _kind(id.x)
	var kind2 := _kind(id2.x)
	var hedged := kind1!=kind2 or hash3i(c1+c2, 4).y<0.35
	return [kind1, (d2-d1)*0.5, hedged, id.z, id.y]

static func _kind(x: float) -> int:
	return 0 if x<0.42 else 1 if x<0.64 else 2 if x<0.8 else 3

## Across a field's sowing rows, 0..1 (at = the face's ground coordinates).
static func row(at: Vector2, row_hash: float) -> float:
	var a := row_hash*3.14159
	return fposmod(at.dot(Vector2(-sin(a), cos(a)))/0.9, 1.0)

## Whether nothing should grow within `radius` m of `dir` (roads, yards, cities).
static func masked(dir: Vector3, radius := 0.0, roads_only := false) -> bool:
	mask_texture()
	var source := _road_image if roads_only else _mask_image
	var n: Vector3 = CityLayout.FACES[0]
	var face := 0
	for f in 6:
		if dir.dot(CityLayout.FACES[f])>dir.dot(n):
			n = CityLayout.FACES[f]
			face = f
	var ax := Vector3(n.y, n.z, n.x)
	var bx := n.cross(ax)
	var uv := Vector2(dir.dot(ax), dir.dot(bx))/MASK_REACH*0.5+Vector2(0.5, 0.5)
	var texel := 2.0*MASK_REACH*CityLayout.radius()/MASK_SIZE
	var reach := ceili(radius/texel)
	var at := Vector2i(uv*MASK_SIZE)
	for dy in range(-reach, reach+1, maxi(1, reach)):
		for dx in range(-reach, reach+1, maxi(1, reach)):
			var x := clampi(at.x+dx, 0, MASK_SIZE-1)
			var y := clampi(at.y+dy, 0, MASK_SIZE-1)
			if source.get_pixel(x, face*MASK_SIZE+y).r>0.4: return true
	return false

## One texel per city cell (CityLayout.N wide, six faces tall): 1 where the
## cell is farmland, 0 in a city core. The ground shader paints fields there.
static func cell_texture() -> ImageTexture:
	if _cells: return _cells
	var n := CityLayout.N
	var image := Image.create(n, 6*n, false, Image.FORMAT_R8)
	for face in 6:
		for j in n:
			for i in n:
				image.set_pixel(i, face*n+j, Color(1, 0, 0) if CityLayout.role(face, i, j)=="farm" else Color(0, 0, 0))
	_cells = ImageTexture.create_from_image(image)
	return _cells
