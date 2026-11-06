class_name TheoryLampTiming
extends RefCounted
## Shared irregular white-lamp faults, evaluated against the server clock.
static func level(time: float,seed: float) -> float:
	var period := 7.5+fposmod(seed,3.5)
	var t := fposmod(time+seed*3.17,period)
	var power := 0.025
	if t<2.8:
		power = 0.10 if sin(t*51.0+seed)+0.35*sin(t*89.0)>0.87 else 0.82+0.18*sin(t*5.3+seed)
	elif t>period*0.62 and t<period*0.62+0.85:
		power = 0.18 if sin(t*71.0+seed)>0.45 else 0.7
	return power
