class_name Hud
extends CanvasLayer
## Screen effects (PS1 pixelation, camcorder, night vision), HUD text and menus.

const SCREEN_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float nv = 0.0;
uniform float cam = 0.0;
uniform float hurt = 0.0;
uniform vec2 res = vec2(320.0, 180.0);   // 1/4 of 720p: integer scale, no shimmer

float rand(vec2 c) { return fract(sin(dot(c, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = (floor(SCREEN_UV * res) + 0.5) / res;      // PS1-style low resolution
	vec3 c = texture(screen_tex, uv).rgb;
	c = floor(c * 24.0) / 24.0;                          // colour banding
	float g = rand(floor(SCREEN_UV * res) + vec2(fract(TIME) * 91.0, fract(TIME * 1.3) * 37.0));
	if (nv > 0.5) {
		float l = dot(c, vec3(0.3, 0.59, 0.11));
		l = pow(l, 0.75) * 1.7;
		c = vec3(0.15, 1.0, 0.3) * l + (g - 0.5) * 0.1;
	} else {
		c += (g - 0.5) * (0.03 + 0.04 * cam);
	}
	c *= mix(1.0, 0.92 + 0.08 * sin(SCREEN_UV.y * 540.0), cam);   // scanlines
	float vig = smoothstep(0.9, 0.3, distance(SCREEN_UV, vec2(0.5)));
	c *= mix(1.0, vig, 0.55);
	c = mix(c, vec3(0.5, 0.0, 0.0), hurt * (1.0 - vig) * 0.9); // red edges when hurt
	COLOR = vec4(c, 1.0);
}
"""

var player: Player
var _screen := ColorRect.new()
var _mat := ShaderMaterial.new()
var _rec := Control.new()
var _rec_label := Label.new()
var _batt_label := Label.new()
var _nv_label := Label.new()
var _time_label := Label.new()
var _objective := Label.new()
var _prompt := Label.new()
var _subtitle := Label.new()
var _locker := Control.new()
var _breath := ProgressBar.new()
var _panel := ColorRect.new()
var _panel_title := Label.new()
var _panel_text := Label.new()
var _sub_t := 0.0
var _hurt := 0.0
var _rec_time := 0.0


func _ready() -> void:
	var shader := Shader.new()
	shader.code = SCREEN_SHADER
	_mat.shader = shader
	_screen.material = _mat
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full(_screen)
	add_child(_screen)

	# Locker view: dark slats with gaps to peek through.
	_full(_locker)
	_locker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_locker)
	for i in 9:
		var slat := ColorRect.new()
		slat.color = Color(0.02, 0.02, 0.02)
		slat.anchor_left = 0
		slat.anchor_right = 1
		slat.anchor_top = i / 9.0
		slat.anchor_bottom = i / 9.0 + 0.055
		slat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_locker.add_child(slat)
	_breath.anchor_left = 0.4
	_breath.anchor_right = 0.6
	_breath.anchor_top = 0.92
	_breath.anchor_bottom = 0.94
	_breath.max_value = 1.0
	_breath.show_percentage = false
	_locker.add_child(_breath)

	# Camcorder overlay.
	_full(_rec)
	_rec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rec)
	_place(_rec_label, _rec, Vector2(0.05, 0.06), 28, Color(1, 0.2, 0.2))
	_place(_time_label, _rec, Vector2(0.05, 0.12), 20, Color.WHITE)
	_place(_batt_label, _rec, Vector2(0.78, 0.06), 22, Color.WHITE)
	_place(_nv_label, _rec, Vector2(0.78, 0.12), 20, Color(0.4, 1, 0.4))
	for corner in [Vector2(0.03, 0.04), Vector2(0.93, 0.04), Vector2(0.03, 0.88), Vector2(0.93, 0.88)]:
		var br := Label.new()
		_place(br, _rec, corner, 48, Color(1, 1, 1, 0.8))
		br.text = "+"

	_place(_objective, self, Vector2(0.03, 0.9), 18, Color(0.85, 0.85, 0.8))
	_place(_prompt, self, Vector2(0.44, 0.6), 22, Color.WHITE)
	_place(_subtitle, self, Vector2(0.2, 0.8), 22, Color(1, 0.95, 0.85))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.anchor_right = 0.8

	_full(_panel)
	_panel.color = Color(0, 0, 0, 0.85)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_place(_panel_title, _panel, Vector2(0.0, 0.3), 64, Color(0.75, 0.05, 0.05))
	_panel_title.anchor_right = 1.0
	_panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_panel_text, _panel, Vector2(0.0, 0.45), 18, Color(0.85, 0.85, 0.85))
	_panel_text.anchor_right = 1.0
	_panel_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	player.subtitle.connect(say)
	player.objective_changed.connect(_update_objective)
	player.hurt.connect(func(_h: int) -> void: _hurt = 1.0)
	_update_objective()


func _process(delta: float) -> void:
	_rec.visible = player.camcorder_up
	_locker.visible = player.hidden_in != null
	_mat.set_shader_parameter("nv", 1.0 if player.night_vision else 0.0)
	_mat.set_shader_parameter("cam", 1.0 if player.camcorder_up else 0.0)
	var missing := 1.0 - float(player.health) / Player.MAX_HEALTH
	_hurt = maxf(_hurt - delta * 1.5, missing * 0.7)
	_mat.set_shader_parameter("hurt", _hurt)
	if player.camcorder_up:
		_rec_time += delta
		_rec_label.text = "● REC" if fmod(_rec_time, 1.0) < 0.6 else "   REC"
		_time_label.text = "%02d:%02d:%02d" % [int(_rec_time / 3600), int(_rec_time / 60) % 60, int(_rec_time) % 60]
		var bars := ceili(player.battery * 4.0)
		_batt_label.text = "[%s%s] x%d" % ["|".repeat(bars), ".".repeat(4 - bars), player.spare_batteries]
		_batt_label.modulate = Color(1, 0.3, 0.3) if player.battery < 0.25 else Color.WHITE
		_nv_label.text = "NIGHT VISION" if player.night_vision else "NV OFF [F]"
	_breath.value = player.breath
	var it = null if player.hidden_in or player.dead else player.find_interactable()
	_prompt.text = ("[Click] " + it.prompt(player)) if it else ("[Click] Leave   [Space] Hold breath" if player.hidden_in else "")
	if _sub_t > 0.0:
		_sub_t -= delta
		_subtitle.modulate.a = clampf(_sub_t, 0.0, 1.0)


func say(text: String) -> void:
	_subtitle.text = text
	_sub_t = 4.0


func show_panel(title: String, text: String) -> void:
	_panel.visible = true
	_panel_title.text = title
	_panel_text.text = text


func hide_panel() -> void:
	_panel.visible = false


func _update_objective() -> void:
	if player.fuses > 0 or _objective.text.begins_with("Fuses"):
		_objective.text = "Fuses carried: %d  - find the fuse box" % player.fuses
	else:
		_objective.text = "Find a way to restore power to the exit gate"


func set_objective(text: String) -> void:
	_objective.text = text


func _full(c: Control) -> void:
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0


func _place(l: Label, parent: Node, at: Vector2, size: int, color: Color) -> void:
	l.anchor_left = at.x
	l.anchor_top = at.y
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
