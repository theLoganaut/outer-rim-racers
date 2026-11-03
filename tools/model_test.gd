extends Node
## Dev tool: contact sheet of all vehicle classes at every yaw frame.
func _ready() -> void:
	var vm := VehicleModels.new()
	add_child(vm)
	await vm.render_all()
	var W := VehicleModels.CELL_W
	var H := VehicleModels.CELL_H
	var sheet := Image.create(W * VehicleModels.YAW_FRAMES, H * 4, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#7a8a9a"))
	var row := 0
	for cls in Data.HALF.keys():
		var v: Dictionary = Data.VEH[cls]
		var fr := VehicleModels.frames(cls, v.cb[0], v.cb[1], v.cb[2])
		for i in VehicleModels.YAW_FRAMES:
			var img: Image = fr[0][i].get_image()
			sheet.blend_rect(img, Rect2i(0, 0, W, H), Vector2i(i * W, row * H))
		row += 1
	sheet.resize(sheet.get_width() * 2, sheet.get_height() * 2, Image.INTERPOLATE_NEAREST)
	sheet.save_png("/private/tmp/claude-501/-Users-logan-outer-rim-racers/178e8a75-dafd-466a-b69d-e2c3940756fe/scratchpad/models.png")
	print("saved")
	get_tree().quit()
