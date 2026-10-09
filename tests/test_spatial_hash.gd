extends GutTest


func test_insert_query_move_and_remove() -> void:
	var hash := SpatialHash.new(0.8)
	hash.insert(1, 0.0, 0.0, 0.4)
	hash.insert(2, 5.0, 0.0, 0.4)
	hash.insert(3, 0.2, 0.15, 0.4)
	var near := hash.query(0.0, 0.0, 0.5)
	assert_true(_contains(near, 1))
	assert_true(_contains(near, 3))
	assert_false(_contains(near, 2))
	hash.move(3, 10.0, 10.0)
	near = hash.query(0.0, 0.0, 0.5)
	assert_false(_contains(near, 3))
	var far := hash.query(10.0, 10.0, 0.5)
	assert_true(_contains(far, 3))
	assert_false(_contains(far, 1))
	hash.remove(1)
	assert_false(hash.has_id(1))
	var empty := hash.query(0.0, 0.0, 0.5)
	assert_false(_contains(empty, 1))


func test_negative_lane_coordinates_change_cells() -> void:
	var hash := SpatialHash.new(0.8)
	hash.insert(7, -0.2, -3.4, 0.4)
	assert_true(_contains(hash.query(-0.2, -3.4, 0.3), 7))
	hash.move(7, -0.2, -8.0)
	assert_false(_contains(hash.query(-0.2, -3.4, 0.3), 7))
	assert_true(_contains(hash.query(-0.2, -8.0, 0.3), 7))


func test_same_cell_returns_both_ids() -> void:
	var hash := SpatialHash.new(1.0)
	hash.insert(4, 0.1, 0.1, 0.4)
	hash.insert(5, 0.2, 0.15, 0.4)
	var ids := hash.query(0.15, 0.12, 0.4)
	assert_eq(ids.size(), 2)
	hash.remove(4)
	ids = hash.query(0.15, 0.12, 0.4)
	assert_eq(ids.size(), 1)
	assert_eq(ids[0], 5)


func _contains(ids: PackedInt32Array, want: int) -> bool:
	for id in ids:
		if id == want:
			return true
	return false
