local mod = get_mod("DamageTracker")

local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIRenderer = require("scripts/managers/ui/ui_renderer")
local ScriptCamera = require("scripts/foundation/utilities/script_camera")

local sizeAnim = { 400, 100 }
local POOL_SIZE = 20

local HIT_TYPE_TO_OFFSET = {
	pure_weakspot = "head",
	weakspot_crit = "head",
	pure_crit = "body",
	normal = "body",
	explosion = "body",
	dot = "dot",
}

local SAME_TARGET_DISTANCE = 0.5

local function is_same_target(box_a, box_b)
	if box_a == box_b then return true end
	if not (box_a and box_b) then return false end
	local a = box_a:unbox()
	local b = box_b:unbox()
	return Vector3.length(a - b) <= SAME_TARGET_DISTANCE
end

local function count_same_target_nodes(pool, target_box)
	local count = 0
	local oldest_idx = nil
	local max_timer = -1
	for i = 1, POOL_SIZE do
		local node = pool[i]
		if node.active and is_same_target(node.world_pos_box, target_box) then
			count = count + 1
			if node.timer > max_timer then
				max_timer = node.timer
				oldest_idx = i
			end
		end
	end
	return count, oldest_idx
end

local scenegraph_definition = {
	screen = UIWorkspaceSettings.screen,
}
local base_style = {
	line_spacing = 1.2, drop_shadow = true, font_type = "machine_medium", size = sizeAnim,
	text_horizontal_alignment = "center", text_vertical_alignment = "center", offset = { 0, 0, 10 },
}
local widget_definitions = {}

for i = 1, POOL_SIZE do
	local s_name = "fct_container_" .. i
	local w_name = "fct_widget_" .. i
	scenegraph_definition[s_name] = { parent = "screen", vertical_alignment = "center", horizontal_alignment = "center",
		size = sizeAnim, position = { 0, 0, 20 + i } }

	widget_definitions[w_name] = UIWidget.create_definition({
		{ value = "", value_id = "text", style_id = "text", pass_type = "text", style = table.clone(base_style) },
		{ value = "", value_id = "icon", style_id = "icon", pass_type = "texture",
			style = { vertical_alignment = "center", horizontal_alignment = "center",
				color = { 0, 255, 255, 255 }, size = { 45, 45 }, offset = { 0, 0, 10 } } },
	}, s_name)
end

local FloatingTextFloat = class("FloatingTextFloat", "HudElementBase")

-- ── init ────────────────────────────────────────────────────────────

FloatingTextFloat.init = function(self, parent, draw_layer, start_scale)
	FloatingTextFloat.super.init(self, parent, draw_layer, start_scale, {
		scenegraph_definition = scenegraph_definition,
		widget_definitions = widget_definitions,
	})

	self._resolution_lookup = RESOLUTION_LOOKUP
	self._level_world = Managers.world:world("level_world")

	self.fct_pool = {}
	for i = 1, POOL_SIZE do
		self.fct_pool[i] = {
			active = false,
			timer = 0,
			duration = 1.0,
			widget_name = "fct_widget_" .. i,
			x = 0, y = 0, dx = 0, dy = 0,
			gravity = 0,
			pop_strength = 0,
			pop_duration = 0.2,
			base_size = 40,
			damage = 0,
			hit_type = "normal",
			text_width = 0,
			dirty_width = false,
			style_data = nil,
			world_pos_box = nil,
			spread_x = 0,
			spread_y = 0,
			fade_penalty = 1.0,
			last_update_time = 0,
			is_dot = false,
			float_category = nil,
			float_y = 0,
		}
	end

	self._active_count = 0
	self:_apply_widget_settings()
	self:_register_events()
end

-- ── events ───────────────────────────────────────────────────────────

FloatingTextFloat._register_events = function(self)
	Managers.event:register(self, "damage_tracker_on_floating_damage", "_on_floating_damage")
	Managers.event:register(self, "damage_tracker_settings_changed", "_apply_widget_settings")
end

FloatingTextFloat.destroy = function(self)
	Managers.event:unregister(self, "damage_tracker_on_floating_damage")
	Managers.event:unregister(self, "damage_tracker_settings_changed")
	FloatingTextFloat.super.destroy(self)
end

-- ── settings ─────────────────────────────────────────────────────────

FloatingTextFloat._apply_widget_settings = function(self)
	self._cached_ui_settings = self._cached_ui_settings or {}
	local s = self._cached_ui_settings

	s.show_normal = mod:get("fct_show_normal")
	s.show_pure_weakspot = mod:get("fct_show_pure_weakspot")
	s.show_pure_crit = mod:get("fct_show_pure_crit")
	s.show_weakspot_crit = mod:get("fct_show_weakspot_crit")
	s.show_dot = mod:get("fct_show_dot")
	s.show_explosion = mod:get("fct_show_explosion")
	s.floating_style = mod:get("floating_style") or "compact"
	s.fct_font_type = mod:get("fct_font_type") or "machine_medium"
	s.show_horde = mod:get("fct_show_horde")
	s.show_elite = mod:get("fct_show_elite")
	s.show_special = mod:get("fct_show_special")
	s.show_boss = mod:get("fct_show_boss")
	s.show_other = mod:get("fct_show_other")

	s.float_head_offset = mod:get("float_head_offset") or -40
	s.float_body_offset = mod:get("float_body_offset") or -20
	s.float_dot_offset = mod:get("float_dot_offset") or 20
	s.float_distance_scaling = mod:get("float_distance_scaling")
	s.float_los_check = mod:get("float_los_check")
	s.distance_reference = mod:get("fct_distance_reference") or 10

	s.float_styles = {
		normal = mod.preload_style("float_normal", "ui_hud_green_super_light", "none"),
		dot = mod.preload_style("float_dot", "white", "none"),
		pure_crit = mod.preload_style("float_pure_crit", "ui_hud_red_light", "objective_main"),
		pure_weakspot = mod.preload_style("float_pure_weakspot", "ui_orange_light", "scars"),
		weakspot_crit = mod.preload_style("float_weakspot_crit", "citadel_wrack_white", "pocketable_syringe_power"),
		explosion = mod.preload_style("float_explosion", "orange", "preset_19"),
	}

	for i = 1, POOL_SIZE do
		self.fct_pool[i].active = false
		self._widgets_by_name[self.fct_pool[i].widget_name].style.icon.color[1] = 0
		self._widgets_by_name[self.fct_pool[i].widget_name].style.text.font_type = s.fct_font_type
	end
	self._active_count = 0
end

-- ── filters ──────────────────────────────────────────────────────────

FloatingTextFloat._check_filters = function(self, hit_type, breed_category)
	local s = self._cached_ui_settings
	if hit_type == "normal" and not s.show_normal then return false end
	if hit_type == "pure_weakspot" and not s.show_pure_weakspot then return false end
	if hit_type == "pure_crit" and not s.show_pure_crit then return false end
	if hit_type == "weakspot_crit" and not s.show_weakspot_crit then return false end
	if hit_type == "dot" and not s.show_dot then return false end
	if hit_type == "explosion" and not s.show_explosion then return false end

	local cat = breed_category or "other"
	if cat == "horde" and s.show_horde == false then return false end
	if cat == "elite" and s.show_elite == false then return false end
	if cat == "special" and s.show_special == false then return false end
	if cat == "boss" and s.show_boss == false then return false end
	if cat == "other" and s.show_other == false then return false end

	return true
end

-- ── pool ─────────────────────────────────────────────────────────────

FloatingTextFloat._acquire_node = function(self)
	local target_idx, oldest_idx, max_timer = 1, 1, -1
	for i = 1, POOL_SIZE do
		if not self.fct_pool[i].active then
			target_idx = i
			break
		end
		if self.fct_pool[i].timer > max_timer then
			max_timer = self.fct_pool[i].timer
			oldest_idx = i
		end
	end
	local was_new = false
	if self.fct_pool[target_idx].active then
		target_idx = oldest_idx
	else
		self._active_count = self._active_count + 1
		was_new = true
	end
	return self.fct_pool[target_idx], was_new
end

FloatingTextFloat._release_node = function(self, node, w)
	node.active = false
	self._active_count = self._active_count - 1
	w.content.text = ""
	w.style.icon.color[1] = 0
	node.world_pos_box = nil
end

FloatingTextFloat._init_node = function(self, node, t, is_dot, damage, hit_type, style_data, world_pos_box, base_size, duration, v_cat)
	node.active = true
	node.timer = 0
	node.last_update_time = t
	node.is_dot = is_dot
	node.damage = damage
	node.hit_type = hit_type
	node.style_data = style_data
	node.world_pos_box = world_pos_box
	node.base_size = base_size
	node.duration = duration
	node.float_category = v_cat
	node.float_y = 0
	node.dirty_width = true
	node.pop_strength = 0.2
	node.pop_duration = 0.15
	node.fade_penalty = 1.0
end

-- ── helpers ──────────────────────────────────────────────────────────

FloatingTextFloat._calc_alpha = function(self, p, node)
	local fp = node.fade_penalty or 1
	local hold_ratio = 0.25
	if p <= hold_ratio then
		return fp
	end
	return math.max(0, fp * (1 - ((p - hold_ratio) / (1 - hold_ratio))))
end

FloatingTextFloat._damage_scale_factor = function(self, damage, s)
	return math.max(0.8, math.min(1.5, (damage / 2100) + 0.6))
end

FloatingTextFloat._apply_node_visuals = function(self, node)
	local w = self._widgets_by_name[node.widget_name]
	local style = node.style_data
	w.content.text = mod.format_damage_number(node.damage)
	w.style.text.text_color = style.color
	w.style.icon.color = table.clone(style.color)
	w.content.icon = style.icon_cfg.texture
	w.alpha_multiplier = 1
	node.dirty_width = true
end

-- ── damage event ─────────────────────────────────────────────────────

FloatingTextFloat._on_floating_damage = function(self, damage, hit_type, world_pos_box, attacked_unit, breed_category)
	local s = self._cached_ui_settings
	if s.floating_style ~= "float" then return end
	if not self:_check_filters(hit_type, breed_category) then return end
	local t = Managers.time:time("ui")
	local is_dot = (hit_type == "dot")

	local v_cat = hit_type
	local v_world_pos_box = world_pos_box

	local player = Managers.player:local_player(1)
	local camera = nil
	if player and player.viewport_name then
		camera = Managers.state.camera:camera(player.viewport_name)
	end

	if camera then
		local world_pos = v_world_pos_box:unbox()

		if Camera.inside_frustum(camera, world_pos) <= 0 then
			return
		end

		if s.float_los_check then
			local physics_world = World.get_data(self._level_world, "physics_world")

			if physics_world then
				local camera_pos = Camera.world_position(camera)
				local to_target = world_pos - camera_pos
				local distance = Vector3.length(to_target)

				if distance > 0 then
					local direction = Vector3.normalize(to_target)
					local hit = PhysicsWorld.raycast(
						physics_world, camera_pos, direction, distance,
						"closest", "collision_filter", "filter_minion_line_of_sight_check"
					)

					if hit then
						if type(hit) == "boolean" then
							return
						elseif type(hit) == "table" then
							local hit_actor = hit[4]
							local hit_unit = hit_actor and Actor.unit(hit_actor)
							if not attacked_unit or hit_unit ~= attacked_unit then
								return
							end
						end
					end
				end
			end
		end
	end

	local style = s.float_styles[v_cat]
	local dsf = self:_damage_scale_factor(damage, s)
	local base_size = style.size * dsf

	local same_count, oldest_idx = count_same_target_nodes(self.fct_pool, v_world_pos_box)
	local cap = 6
	if same_count >= cap and oldest_idx then
		self:_release_node(self.fct_pool[oldest_idx],
			self._widgets_by_name[self.fct_pool[oldest_idx].widget_name])
	end

	local node = self:_acquire_node()

	self:_init_node(node, t, is_dot, damage, hit_type, style, v_world_pos_box,
		base_size, 1.0, v_cat)

	local push_amount = 0.3 * base_size
	for i = 1, POOL_SIZE do
		local other = self.fct_pool[i]
		if other ~= node and other.active and is_same_target(other.world_pos_box, v_world_pos_box) then
			other.float_y = (other.float_y or 0) + push_amount
			other.fade_penalty = math.max(0.15, (other.fade_penalty or 1) * 0.5)
		end
	end

	self:_apply_node_visuals(node)
end

-- ── update ───────────────────────────────────────────────────────────

FloatingTextFloat._update_node_position = function(self, node, camera, s, dt, inv_scale, logical_w, logical_h)
	if not camera or not node.world_pos_box then
		return 0, 0, false
	end

	local world_pos = node.world_pos_box:unbox()

	if Camera.inside_frustum(camera, world_pos) <= 0 then
		self:_release_node(node, self._widgets_by_name[node.widget_name])
		return 0, 0, false
	end

	local screen_pos = Camera.world_to_screen(camera, world_pos)
	local v_cat = node.float_category or "body"

	local float_dist_scale = 1.0
	local size_dist_scale = 1.0
	local camera_pos = Camera.world_position(camera)
	local real_distance = Vector3.length(world_pos - camera_pos)
	local raw_scale = math.min(1.0, (s.distance_reference or 10) / real_distance)
	float_dist_scale = math.max(0.2, raw_scale)
	if s.float_distance_scaling then
		size_dist_scale = math.max(0.5, raw_scale)
	end

	local cat_offset = 0
	local offset_key = HIT_TYPE_TO_OFFSET[v_cat] or "body"
	if offset_key == "head" then cat_offset = s.float_head_offset
	elseif offset_key == "dot" then cat_offset = s.float_dot_offset
	else cat_offset = s.float_body_offset end

	node.float_y = (node.float_y or 0) + 140 * inv_scale * float_dist_scale * dt

	local render_x = (screen_pos.x * inv_scale) - (logical_w / 2)
	local render_y = (screen_pos.y * inv_scale) - (logical_h / 2) + cat_offset - node.float_y

	local margin = 120
	if render_x < -(logical_w + margin) or render_x > (logical_w + margin)
		or render_y < -(logical_h + margin) or render_y > (logical_h + margin) then
		self:_release_node(node, self._widgets_by_name[node.widget_name])
		return 0, 0, false
	end

	return render_x, render_y, true, size_dist_scale
end

FloatingTextFloat.update = function(self, dt, t, ui_renderer, render_settings, input_service)
	FloatingTextFloat.super.update(self, dt, t, ui_renderer, render_settings, input_service)

	if self._active_count == 0 then
		return
	end

	local s = self._cached_ui_settings

	local camera = nil
	local player = Managers.player:local_player(1)
	if player and player.viewport_name then
		camera = Managers.state.camera:camera(player.viewport_name)
	end

	local inv_scale = self._resolution_lookup.inverse_scale
	local logical_w = self._resolution_lookup.width * inv_scale
	local logical_h = self._resolution_lookup.height * inv_scale

	for i = 1, POOL_SIZE do
		local node = self.fct_pool[i]
		if not node.active then goto continue end

		local w = self._widgets_by_name[node.widget_name]

		node.timer = node.timer + dt
		local p = node.timer / node.duration
		local current_size = node.base_size

		if node.timer < node.pop_duration and (node.pop_strength or 0) > 0 then
			local pop_p = node.timer / node.pop_duration
			current_size = current_size * (1.0 + (math.sin(pop_p * math.pi) * node.pop_strength))
		end

		local alpha = self:_calc_alpha(p, node)

		local render_x, render_y, should_render, size_override =
			self:_update_node_position(node, camera, s, dt, inv_scale, logical_w, logical_h)

		if size_override then
			current_size = current_size * size_override
		end

		local pushed_height = node.float_y or 0
		local shrink_threshold = node.base_size
		if pushed_height > shrink_threshold then
			local excess = pushed_height - shrink_threshold
			local shrink = math.max(0.5, 1.0 - excess / (shrink_threshold * 3))
			current_size = current_size * shrink
		end

		if should_render ~= false then
			w.style.text.offset[1] = render_x
			w.style.text.offset[2] = render_y
			w.style.text.font_size = current_size
			w.alpha_multiplier = alpha

			local cfg = node.style_data.icon_cfg
			if node.style_data.icon_key ~= "none" then
				w.style.icon.color[1] = 255
				local icon_size = current_size * cfg.size_multiplier
				w.style.icon.size[1], w.style.icon.size[2] = icon_size, icon_size

				if node.dirty_width then
					node.text_width = UIRenderer.text_size(ui_renderer, w.content.text,
						w.style.text.font_type, node.base_size)
					node.dirty_width = false
				end

				local current_text_width = node.text_width * (current_size / node.base_size)
				w.style.icon.offset[1] = render_x + (current_text_width / 2) +
					(icon_size / (2 * cfg.size_multiplier)) + cfg.padding
				w.style.icon.offset[2] = render_y
			else
				w.style.icon.color[1] = 0
			end
		else
			w.alpha_multiplier = 0
		end

		if node.active and node.timer >= node.duration then
			self:_release_node(node, w)
		end

		::continue::
	end
end

return FloatingTextFloat
