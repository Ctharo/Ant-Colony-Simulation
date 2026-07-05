class_name PheromoneMemory
extends RefCounted
## Rolling memory of pheromone concentration samples taken as an ant moves.
##
## The ant samples the heatmap one cell at a time; this class accumulates
## those samples and derives a gradient direction from them. Extracted from
## ant.gd so it can be tested and reused independently.
## Place at: res://entities/ant/pheromone_memory.gd

## A single heatmap reading at a given cell.
class ConcentrationSample:
	var cell_pos: Vector2i
	var concentration: float
	var timestamp: int

	func _init(p_cell_pos: Vector2i, p_concentration: float) -> void:
		cell_pos = p_cell_pos
		concentration = p_concentration
		timestamp = Time.get_ticks_msec()


## Maximum number of samples retained (oldest dropped first).
var max_samples: int = 20
## Samples older than this (ms) are discarded on the next add.
var memory_duration: int = 60_000

var samples: Array[ConcentrationSample] = []
## Last sampled cell — used to avoid duplicate samples while standing still.
var _current_cell: Vector2i


## Records a sample, deduplicating by cell and pruning expired entries.
func add_sample(cell_pos: Vector2i, concentration: float) -> void:
	# Still in the same cell — nothing new to learn.
	if _current_cell == cell_pos:
		return
	_current_cell = cell_pos

	var current_time: int = Time.get_ticks_msec()

	# Drop samples that have aged out.
	samples = samples.filter(func(sample: ConcentrationSample) -> bool:
		return current_time - sample.timestamp < memory_duration
	)

	# If we've visited this cell before, refresh it instead of duplicating.
	for sample: ConcentrationSample in samples:
		if sample.cell_pos == cell_pos:
			sample.concentration = concentration
			sample.timestamp = current_time
			return

	samples.append(ConcentrationSample.new(cell_pos, concentration))

	while samples.size() > max_samples:
		samples.pop_front()


## Derives a normalized direction pointing toward increasing concentration,
## weighted so recent samples and larger concentration changes dominate.
## Returns Vector2.ZERO when there is not enough data to form a gradient.
func get_concentration_vector() -> Vector2:
	if samples.size() < 2:
		return Vector2.ZERO

	var weighted_direction := Vector2.ZERO
	var total_weight := 0.0

	# Walk consecutive sample pairs to estimate the local gradient.
	for i: int in range(samples.size() - 1):
		var from_sample: ConcentrationSample = samples[i]
		var to_sample: ConcentrationSample = samples[i + 1]

		# Direction of travel from the older sample to the newer one.
		var direction := Vector2(to_sample.cell_pos - from_sample.cell_pos).normalized()

		# Positive when concentration rose along that step.
		var concentration_diff := to_sample.concentration - from_sample.concentration

		# Bias toward the most recent movement history.
		var recency_weight := float(i + 1) / samples.size()

		weighted_direction += direction * concentration_diff * recency_weight
		total_weight += absf(concentration_diff) * recency_weight

	if total_weight > 0.0:
		return weighted_direction.normalized()
	return Vector2.ZERO
