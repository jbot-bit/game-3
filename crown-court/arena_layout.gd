extends RefCounted
## Authored reconstruction from retained public Crown Jam frames. World and Sim
## share this analytic surface; these are not recovered proprietary constants.

const HALF_WIDTH = 32.0
const HALF_LENGTH = 56.0
const SIDE_BANK_START = 28.0
const END_BANK_START = 50.0
const SIDE_BANK_HEIGHT = 1.35
const END_BANK_HEIGHT = 1.65
const ROAD_HEIGHT = 1.15
const ROAD_HALF_WIDTH = 1.9
const ROAD_SHOULDER = 2.0
const ROAD_GOAL_RADIUS = 9.5
const MAX_TERRAIN_HEIGHT = 1.65

static func bank_height(x: float, z: float) -> float:
	return maxf(smoothstep(SIDE_BANK_START,HALF_WIDTH,absf(x))*SIDE_BANK_HEIGHT,
		smoothstep(END_BANK_START,HALF_LENGTH,absf(z))*END_BANK_HEIGHT)

static func road_center_x(z_abs: float) -> float:
	var z = absf(z_abs)
	if z < 10: return lerpf(21,22,smoothstep(0,10,z))
	if z < 21: return lerpf(22,20,smoothstep(10,21,z))
	if z < 29: return lerpf(20,21,smoothstep(21,29,z))
	if z < 43: return lerpf(21,12,smoothstep(29,43,z))
	return 12.0

static func road_cross_z(x_abs: float) -> float:
	return 20.0+2.0*(1.0-smoothstep(0,20,absf(x_abs)))

static func road_profile(distance: float) -> float:
	return 1.0-smoothstep(ROAD_HALF_WIDTH,ROAD_HALF_WIDTH+ROAD_SHOULDER,absf(distance))

static func road_weight(x: float, z: float) -> float:
	var ax = absf(x)
	var az = absf(z)
	var weight = 0.0
	if az < 49:
		weight = road_profile(ax-road_center_x(az))*(1.0-smoothstep(44,49,az))
	if az > 15.8 and az < 26.2 and ax < 27:
		weight = maxf(weight,road_profile(az-road_cross_z(ax))*(1.0-smoothstep(23,27,ax)))
	if az > 34.0 and az < 54 and ax < ROAD_GOAL_RADIUS+ROAD_HALF_WIDTH+ROAD_SHOULDER:
		var radial = sqrt(ax*ax+(az-48.0)*(az-48.0))
		weight = maxf(weight,road_profile(radial-ROAD_GOAL_RADIUS)*(1.0-smoothstep(49,54,az)))
	return weight

static func floor_height(x: float, z: float) -> float:
	return maxf(bank_height(x,z),ROAD_HEIGHT*road_weight(x,z))

static func floor_normal(x: float, z: float) -> Vector3:
	var e = 0.04
	return Vector3((floor_height(x-e,z)-floor_height(x+e,z))/(2*e),1,
		(floor_height(x,z-e)-floor_height(x,z+e))/(2*e)).normalized()
