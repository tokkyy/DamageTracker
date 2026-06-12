local mod = get_mod("DamageTracker")

local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIRenderer = require("scripts/managers/ui/ui_renderer")

local sizeAnim = { 400, 100 }
local POOL_SIZE = 20

local HIT_TYPE_PRIORITY = {
	weakspot_crit = 5,
	pure_crit = 4,
	pure_weakspot = 3,
	explosion = 2,
	normal = 2,
	dot = 1,
}

local FCT_ANIMATION_PROFILES = {
	normal = { dur = 1, pop_str = 0.2, pop_dur = 0.15, grav = 80, dx_range = { -30, 30 }, dy_range = { -60, -90 } },
	dot = { dur = 0.8, pop_str = 0.0, pop_dur = 0.10, grav = 20, dx_range = { -10, 10 }, dy_range = { 10, 40 } },
	pure_weakspot = { dur = 1.2, pop_str = 0.3, pop_dur = 0.17, grav = 120, dx_range = { 20, 60 }, dy_range = { -100, -130 } },
	pure_crit = { dur = 1.2, pop_str = 0.4, pop_dur = 0.15, grav = 120, dx_range = { -60, -20 }, dy_range = { -100, -130 } },
	weakspot_crit = { dur = 1.4, pop_str = 0.5, pop_dur = 0.20, grav = 80, dx_range = { -15, 15 }, dy_range = { -140, -180 } },
	explosion = { dur = 1.1, pop_str = 0.25, pop_dur = 0.16, grav = 100, dx_range = { -40, 40 }, dy_range = { -80, -110 } },
}

local scenegraph_definition = {
	screen = UIWorkspaceSettings.screen,
}
local base_style = {
	line_spacing = 1.2,
	drop_shadow = true,
	font_type = "machine_medium",
	size = sizeAnim,
	text_horizontal_alignment = "center",
	text_vertical_alignment = "center",
	offset = { 0, 0, 10 },
}
local widget_definitions = {}

for i = 1, POOL_SIZE do
	local s_name = "fct_container_" .. i
	local w_name = "fct_widget_" .. i
	scenegraph_definition[s_name] = {
		parent = "screen",
		vertical_alignment = "center",
		horizontal_alignment = "center",
		size = sizeAnim,
		position = { 0, 0, 20 + i }
	}

	widget_definitions[w_name] = UIWidget.create_definition({
		{ value = "", value_id = "text", style_id = "text", pass_type = "text", style = table.clone(base_style) },
		{
			value = "",
			value_id = "icon",
			style_id = "icon",
			pass_type = "texture",
			style = {
				vertical_alignment = "center",
				horizontal_alignment = "center",
				color = { 0, 255, 255, 255 },
				size = { 45, 45 },
				offset = { 0, 0, 10 }
			}
		},
	}, s_name)
end

local FloatingTextFixed = class("FloatingTextFixed", "HudElementBase")

-- ── init ────────────────────────────────────────────────────────────

FloatingTextFixed.init = function(self, parent, draw_layer, start_scale)
	FloatingTextFixed.super.init(self, parent, draw_layer, start_scale, {
		scenegraph_definition = scenegraph_definition,
		widget_definitions = widget_definitions,
	})

	self._resolution_lookup = RESOLUTION_LOOKUP

	self.fct_pool = {}
	for i = 1, POOL_SIZE do
		self.fct_pool[i] = {
			active = false,
			timer = 0,
			duration = 1.0,
			widget_name = "fct_widget_" .. i,
			x = 0,
			y = 0,
			dx = 0,
			dy = 0,
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
		}
	end

	self._active_count = 0
	self:_apply_widget_settings()
	self:_register_events()
end

-- ── events ───────────────────────────────────────────────────────────

FloatingTextFixed._register_events = function(self)
	Managers.event:register(self, "damage_tracker_on_floating_damage", "_on_floating_damage")
	Managers.event:register(self, "damage_tracker_settings_changed", "_apply_widget_settings")
end

FloatingTextFixed.destroy = function(self)
	Managers.event:unregister(self, "damage_tracker_on_floating_damage")
	Managers.event:unregister(self, "damage_tracker_settings_changed")
	FloatingTextFixed.super.destroy(self)
end

-- ── settings ─────────────────────────────────────────────────────────

FloatingTextFixed._apply_widget_settings = function(self)
	self._cached_ui_settings = self._cached_ui_settings or {}
	local s = self._cached_ui_settings

	s.floating_mode = mod:get("floating_mode") or "all_direct"
	s.floating_style = mod:get("floating_style") or "compact"
	s.fct_font_type = mod:get("fct_font_type") or "machine_medium"
	s.show_horde = mod:get("fct_show_horde")
	s.show_elite = mod:get("fct_show_elite")
	s.show_special = mod:get("fct_show_special")
	s.show_boss = mod:get("fct_show_boss")
	s.show_other = mod:get("fct_show_other")

	s.fct_x = mod:get("floating_x") or -15
	s.fct_y = mod:get("floating_y") or -240

	s.fct_styles = {
		normal = mod.preload_style("fixed_normal", "ui_hud_green_super_light", "none"),
		dot = mod.preload_style("fixed_dot", "medium_turquoise", "none"),
		pure_crit = mod.preload_style("fixed_pure_crit", "ui_hud_red_light", "objective_main"),
		pure_weakspot = mod.preload_style("fixed_pure_weakspot", "ui_orange_light", "scars"),
		weakspot_crit = mod.preload_style("fixed_weakspot_crit", "citadel_wrack_white", "pocketable_syringe_power"),
		explosion = mod.preload_style("fixed_explosion", "orange", "preset_19"),
	}

	for i = 1, POOL_SIZE do
		self.fct_pool[i].active = false
		self._widgets_by_name[self.fct_pool[i].widget_name].style.icon.color[1] = 0
		self._widgets_by_name[self.fct_pool[i].widget_name].style.text.font_type = s.fct_font_type
	end
	self._active_count = 0
end

-- ── filters ──────────────────────────────────────────────────────────

FloatingTextFixed._check_filters = function(self, hit_type, breed_category)
	local s = self._cached_ui_settings
	if s.floating_mode == "disabled" then return false end
	if s.floating_mode == "finesse_only" and (hit_type == "normal" or hit_type == "dot" or hit_type == "explosion") then return false end
	if s.floating_mode == "all_direct" and hit_type == "dot" then return false end

	local cat = breed_category or "other"
	if cat == "horde" and s.show_horde == false then return false end
	if cat == "elite" and s.show_elite == false then return false end
	if cat == "special" and s.show_special == false then return false end
	if cat == "boss" and s.show_boss == false then return false end
	if cat == "other" and s.show_other == false then return false end

	return true
end

-- ── pool ─────────────────────────────────────────────────────────────

FloatingTextFixed._acquire_node = function(self)
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

FloatingTextFixed._release_node = function(self, node, w)
	node.active = false
	self._active_count = self._active_count - 1
	w.content.text = ""
	w.style.icon.color[1] = 0
	node.world_pos_box = nil
end

FloatingTextFixed._init_node = function(self, node, t, is_dot, damage, hit_type, style_data, world_pos_box)
	node.active = true
	node.timer = 0
	node.last_update_time = t
	node.is_dot = is_dot
	node.damage = damage
	node.hit_type = hit_type
	node.style_data = style_data
	node.world_pos_box = world_pos_box
	node.dirty_width = true
end

-- ── helpers ──────────────────────────────────────────────────────────

FloatingTextFixed._calc_alpha = function(self, p, node)
	if p > 0.6 then
		return math.max(0, 1 - ((p - 0.6) * 2.5)) * node.fade_penalty
	end
	return node.fade_penalty
end

FloatingTextFixed._damage_scale_factor = function(self, damage, s)
	return math.max(0.8, math.min(1.5, (damage / 2100) + 0.6))
end

FloatingTextFixed._apply_node_visuals = function(self, node)
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

FloatingTextFixed._on_floating_damage = function(self, damage, hit_type, world_pos_box, attacked_unit, breed_category)
	local s = self._cached_ui_settings
	if s.floating_style ~= "fixed" then return end
	if not self:_check_filters(hit_type, breed_category) then return end
	local t = Managers.time:time("ui")
	local is_dot = (hit_type == "dot")
	local window = is_dot and 0.2 or 0.055

	-- Time-window merge
	local target_node = nil
	local latest_time = -1
	for i = 1, POOL_SIZE do
		local node = self.fct_pool[i]
		if node.active and node.is_dot == is_dot and (t - node.last_update_time) <= window then
			if node.last_update_time > latest_time then
				latest_time = node.last_update_time
				target_node = node
			end
		end
	end

	if target_node then
		target_node.damage = target_node.damage + damage
		target_node.last_update_time = t

		if HIT_TYPE_PRIORITY[hit_type] > (HIT_TYPE_PRIORITY[target_node.hit_type] or 0) then
			target_node.hit_type = hit_type
		end

		local style = s.fct_styles[target_node.hit_type]
		target_node.style_data = style
		target_node.base_size = style.size *
			math.max(0.8, math.min(1.5, (target_node.damage / 2100) + 0.6))
		target_node.dirty_width = true

		local w = self._widgets_by_name[target_node.widget_name]
		w.content.text = mod.format_damage_number(target_node.damage)
		w.style.text.text_color = style.color
		w.style.icon.color = table.clone(style.color)
		w.content.icon = style.icon_cfg.texture
		return
	end

	-- Enforce global active cap
	local cap = 6
	if self._active_count >= cap then
		local oldest_idx, max_timer = nil, -1
		for i = 1, POOL_SIZE do
			if self.fct_pool[i].active and self.fct_pool[i].timer > max_timer then
				max_timer = self.fct_pool[i].timer
				oldest_idx = i
			end
		end
		if oldest_idx then
			self:_release_node(self.fct_pool[oldest_idx],
				self._widgets_by_name[self.fct_pool[oldest_idx].widget_name])
		end
	end

	-- Allocate new node
	local node = self:_acquire_node()
	local prof = FCT_ANIMATION_PROFILES[hit_type]
	local style = s.fct_styles[hit_type]
	local dsf = self:_damage_scale_factor(damage, s)

	self:_init_node(node, t, is_dot, damage, hit_type, style, world_pos_box)

	node.base_size = style.size * dsf
	node.pop_strength = prof.pop_str
	node.pop_duration = prof.pop_dur
	node.duration = prof.dur + (dsf * 0.2)

	node.dx = math.random(prof.dx_range[1], prof.dx_range[2])
	node.dy = math.random(prof.dy_range[1], prof.dy_range[2])
	node.gravity = prof.grav
	node.x = s.fct_x + math.random(-15, 15)
	node.y = s.fct_y + math.random(-15, 15)
	node.spread_x = 0
	node.spread_y = 0
	node.fade_penalty = 1.0

	self:_apply_node_visuals(node)

	for i = 1, POOL_SIZE do
		local other = self.fct_pool[i]
		if other ~= node and other.active then
			other.fade_penalty = math.max(0.15, other.fade_penalty * 0.6)
		end
	end
end

-- ── update ───────────────────────────────────────────────────────────

FloatingTextFixed._update_node_position = function(self, node, camera, s, dt, inv_scale, logical_w, logical_h)
	node.dy = node.dy + (node.gravity * dt)
	node.x = node.x + (node.dx * dt)
	node.y = node.y + (node.dy * dt)
	return node.x, node.y
end

FloatingTextFixed.update = function(self, dt, t, ui_renderer, render_settings, input_service)
	FloatingTextFixed.super.update(self, dt, t, ui_renderer, render_settings, input_service)

	if self._active_count == 0 then
		return
	end

	local s = self._cached_ui_settings
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

		if node.timer < node.pop_duration and node.pop_strength > 0 then
			local pop_p = node.timer / node.pop_duration
			current_size = current_size * (1.0 + (math.sin(pop_p * math.pi) * node.pop_strength))
		end

		node.fade_penalty = math.min(1.0, node.fade_penalty + dt * 1.5)

		local alpha = self:_calc_alpha(p, node)

		local render_x, render_y, should_render, size_override =
			self:_update_node_position(node, nil, s, dt, inv_scale, logical_w, logical_h)

		if size_override then
			current_size = current_size * size_override
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

return FloatingTextFixed
