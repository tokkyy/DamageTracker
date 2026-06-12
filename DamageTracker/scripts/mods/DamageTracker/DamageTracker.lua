local mod = get_mod("DamageTracker")
local Breed = mod:original_require("scripts/utilities/breed")


mod.cached_settings = {
	use_k_format = true,
	tracking_mode = "separated",
	floating_mode = "all_direct",
	floating_weapon_filter = "both",
	floating_style = "compact",
	fct_los_check = false,
}

local function update_cached_settings()
	mod.cached_settings.use_k_format = mod:get("use_k_format")
	mod.cached_settings.tracking_mode = mod:get("tracking_mode") or "separated"
	mod.cached_settings.floating_mode = mod:get("floating_mode") or "all_direct"
	mod.cached_settings.floating_weapon_filter = mod:get("floating_weapon_filter") or "both"
	mod.cached_settings.floating_style = mod:get("floating_style") or "compact"
	mod.cached_settings.fct_los_check = mod:get("fct_los_check")
end

mod.on_all_mods_loaded = function()
	update_cached_settings()
end

mod.on_setting_changed = function(setting_id)
	update_cached_settings()
	Managers.event:trigger("damage_tracker_settings_changed", setting_id)
end

mod.ICON_CONFIG = {
	none = { texture = "", size_multiplier = 0, padding = 0 },
	weapons = { texture = "content/ui/materials/icons/item_types/weapons", size_multiplier = 1.0, padding = 4 },
	objective_main = { texture = "content/ui/materials/hud/interactions/icons/objective_main", size_multiplier = 2.0, padding = 6 },
	incapacitated = { texture = "content/ui/materials/icons/player_states/incapacitated", size_multiplier = 1.5, padding = 0 },
	mission_type_01 = { texture = "content/ui/materials/icons/mission_types/mission_type_01", size_multiplier = 0.9, padding = 3 },
	difficulty_skull_heresy = { texture = "content/ui/materials/icons/difficulty/flat/difficulty_skull_heresy", size_multiplier = 1.5, padding = 4 },
	difficulty_skull_uprising = { texture = "content/ui/materials/icons/difficulty/flat/difficulty_skull_uprising", size_multiplier = 1.5, padding = 4 },
	dead = { texture = "content/ui/materials/icons/player_states/dead", size_multiplier = 1.3, padding = 6 },
	pocketable_syringe_power = { texture = "content/ui/materials/hud/interactions/icons/pocketable_syringe_power", size_multiplier = 1.3, padding = 6 },
	scars = { texture = "content/ui/materials/icons/item_types/scars", size_multiplier = 1.3, padding = 4 },
	preset_19 = { texture = "content/ui/materials/icons/presets/preset_19", size_multiplier = 1.0, padding = 6 },
}

mod.get_color = function(color_name, fallback)
	local c = Color[color_name] and Color[color_name](255, true) or Color[fallback](255, true)
	return table.clone(c)
end

mod.preload_style = function(prefix, default_color, default_icon_key)
	local icon_key = mod:get(prefix .. "_icon") or default_icon_key
	local icon_cfg = mod.ICON_CONFIG[icon_key] or mod.ICON_CONFIG.none
	return {
		color = mod.get_color(mod:get(prefix .. "_color"), default_color),
		icon_cfg = icon_cfg,
		icon_key = icon_key,
		size = mod:get(prefix .. "_size") or 40,
	}
end

mod.format_damage_number = function(value)
	if not mod.cached_settings.use_k_format or value < 1000 then
		return tostring(math.floor(value))
	end
	return string.format("%.1fk", value / 1000):gsub("%.0k", "k")
end

local function classify_breed_category(breed_or_nil)
	if not breed_or_nil then
		return "other"
	end

	local enemy_type = Breed.enemy_type(breed_or_nil)
	if enemy_type == "elite" then
		return "elite"
	elseif enemy_type == "special" then
		return "special"
	elseif enemy_type == "monster" or enemy_type == "captain" then
		return "boss"
	elseif breed_or_nil.tags then
		if breed_or_nil.tags.cultist_captain or breed_or_nil.tags.ritualist then
			return "boss"
		elseif breed_or_nil.tags.horde or breed_or_nil.tags.roamer then
			return "horde"
		end
	end

	return "other"
end

local function is_fct_eligible(hit_type, floating_mode)
	if floating_mode == "disabled" then return false end
	if floating_mode == "finesse_only" then
		return hit_type == "pure_weakspot" or hit_type == "pure_crit" or hit_type == "weakspot_crit"
	end
	if floating_mode == "all_direct" then return hit_type ~= "dot" end
	return true
end

local _tracked_units = {}
local QUEUE_MAX_AGE = 0.5

mod._classify_hit_type = function(attack_type, hit_weakspot, is_critical_strike)
	if attack_type == "buff" or attack_type == "damage_over_time" then
		return "dot"
	elseif attack_type == "explosion" then
		return "explosion"
	elseif hit_weakspot and is_critical_strike then
		return "weakspot_crit"
	elseif hit_weakspot then
		return "pure_weakspot"
	elseif is_critical_strike then
		return "pure_crit"
	else
		return "normal"
	end
end

mod._purge_stale_entries = function(state, current_time)
	local queue = state.metadata_queue
	local write_idx = 1
	for i = 1, #queue do
		local entry = queue[i]
		if current_time - entry.timestamp <= QUEUE_MAX_AGE then
			queue[write_idx] = entry
			write_idx = write_idx + 1
		end
	end
	for i = write_idx, #queue do
		queue[i] = nil
	end
end

mod._fire_fct_events = function(unit, breed_or_nil, entries, category_delta, total_reported, s)
	local n = #entries
	if n == 0 or category_delta <= 0 then return end

	local wf = s.floating_weapon_filter
	local breed_category = classify_breed_category(breed_or_nil)
	local attributed_sum = 0

	for i = 1, n do
		local entry = entries[i]

		local pass_weapon = (wf == "both") or
			(wf == "melee_only" and entry.attack_type == "melee") or
			(wf == "ranged_only" and entry.attack_type == "ranged")
		if not pass_weapon then goto continue_fct_entry end

		local attributed
		if i == n then
			attributed = category_delta - attributed_sum
			if attributed <= 0 then break end
		else
			if total_reported > 0 then
				attributed = math.max(1, math.floor(category_delta * entry.reported_damage / total_reported + 0.5))
			else
				attributed = math.max(1, math.floor(category_delta / n))
			end
			attributed_sum = attributed_sum + attributed
		end

		local hit_type = mod._classify_hit_type(entry.attack_type, entry.hit_weakspot, entry.is_critical_strike)
		if not is_fct_eligible(hit_type, s.floating_mode) then
			goto continue_fct_entry
		end

		local fct_world_pos = entry.hit_world_position

		if entry.attack_type == "explosion" then
			if unit and Unit.has_node(unit, "j_spine") then
				fct_world_pos = Vector3Box(Unit.world_position(unit, Unit.node(unit, "j_spine")))
			elseif unit then
				local pos = POSITION_LOOKUP[unit]
				fct_world_pos = pos and Vector3Box(pos) or Vector3Box(Unit.world_position(unit, 1))
			end
		elseif not fct_world_pos then
			if unit and Unit.has_node(unit, "j_spine") then
				fct_world_pos = Vector3Box(Unit.world_position(unit, Unit.node(unit, "j_spine")))
			elseif unit then
				local pos = POSITION_LOOKUP[unit]
				fct_world_pos = pos and Vector3Box(pos) or Vector3Box(Unit.world_position(unit, 1))
			end
		end

		if fct_world_pos then
			Managers.event:trigger("damage_tracker_on_floating_damage",
				attributed, hit_type, fct_world_pos, unit, breed_category)
		end

		::continue_fct_entry::
	end
end

mod._process_drained_queue = function(unit, breed_or_nil, queue, delta, tracking_needed, s)
	local dot_entries = {}
	local direct_entries = {}
	local dot_total_reported = 0
	local direct_total_reported = 0

	for i = 1, #queue do
		local entry = queue[i]
		local is_dot = (entry.attack_type == "buff" or entry.attack_type == "damage_over_time")
		if is_dot then
			dot_entries[#dot_entries + 1] = entry
			dot_total_reported = dot_total_reported + entry.reported_damage
		else
			direct_entries[#direct_entries + 1] = entry
			direct_total_reported = direct_total_reported + entry.reported_damage
		end
	end

	local total_reported = dot_total_reported + direct_total_reported
	if total_reported <= 0 then return end

	local dot_delta = math.floor(delta * dot_total_reported / total_reported + 0.5)
	local direct_delta = delta - dot_delta
	if dot_delta < 0 then dot_delta = 0 end
	if direct_delta < 0 then direct_delta = 0 end

	if tracking_needed then
		local mode = s.tracking_mode
		if dot_delta > 0 and #dot_entries > 0 then
			if mode == "combined" or mode == "separated" or mode == "dot_only" then
				Managers.event:trigger("damage_tracker_on_damage", dot_delta, "main_dot", dot_delta)
			end
		end
		if direct_delta > 0 and #direct_entries > 0 then
			if mode == "combined" or mode == "separated" or mode == "direct_only" then
				Managers.event:trigger("damage_tracker_on_damage", direct_delta, "main_direct", direct_delta)
			end
		end
	end

	mod._fire_fct_events(unit, breed_or_nil, dot_entries, dot_delta, dot_total_reported, s)
	mod._fire_fct_events(unit, breed_or_nil, direct_entries, direct_delta, direct_total_reported, s)
end

mod:register_hud_element({
	filename = "DamageTracker/scripts/mods/DamageTracker/hud/StaticDamagePanel",
	class_name = "StaticDamagePanel",
	visibility_groups = { "tactical_overlay", "alive" },
	use_hud_scale = true,
	validation_function = function(params) return Managers.state.game_mode:game_mode_name() ~= "hub" end,
})

mod:register_hud_element({
	filename = "DamageTracker/scripts/mods/DamageTracker/hud/FloatingTextFixed",
	class_name = "FloatingTextFixed",
	visibility_groups = { "tactical_overlay", "alive" },
	use_hud_scale = true,
	validation_function = function(params) return Managers.state.game_mode:game_mode_name() ~= "hub" end,
})

mod:register_hud_element({
	filename = "DamageTracker/scripts/mods/DamageTracker/hud/FloatingTextCompact",
	class_name = "FloatingTextCompact",
	visibility_groups = { "tactical_overlay", "alive" },
	use_hud_scale = true,
	validation_function = function(params) return Managers.state.game_mode:game_mode_name() ~= "hub" end,
})

mod:register_hud_element({
	filename = "DamageTracker/scripts/mods/DamageTracker/hud/FloatingTextFloat",
	class_name = "FloatingTextFloat",
	visibility_groups = { "tactical_overlay", "alive" },
	use_hud_scale = true,
	validation_function = function(params) return Managers.state.game_mode:game_mode_name() ~= "hub" end,
})

mod:hook_safe(CLASS.AttackReportManager, "add_attack_result",
	function(self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position,
			 hit_weakspot, damage, attack_result, attack_type, damage_efficiency, is_critical_strike, ...)
		if not damage or damage <= 0 then return end

		local local_player = Managers.player:local_player(1)
		if not local_player or local_player.player_unit ~= attacking_unit then return end

		local s = mod.cached_settings
		local hit_type = mod._classify_hit_type(attack_type, hit_weakspot, is_critical_strike)

		local tracking_needed = (s.tracking_mode ~= "disabled")
		local fct_needed = is_fct_eligible(hit_type, s.floating_mode)
		if not tracking_needed and not fct_needed then return end

		local unit_data_extension = ScriptUnit.has_extension(attacked_unit, "unit_data_system")
		local breed_or_nil = unit_data_extension and unit_data_extension:breed()
		if not (breed_or_nil and Breed.is_minion(breed_or_nil)) then return end

		local unit_health_extension = ScriptUnit.has_extension(attacked_unit, "health_system")
		if not unit_health_extension then return end

		local state = _tracked_units[attacked_unit]
		if not state then
			local total = unit_health_extension:total_damage_taken()
			local raw = unit_health_extension:damage_taken()
			local max_hp = unit_health_extension:max_health()
			local before = math.max(0, raw - damage)
			local actual_this_hit = math.min(damage, math.max(0, max_hp - before))
			state = {
				prev_total_damage = math.max(0, total - actual_this_hit),
				breed_or_nil = breed_or_nil,
				metadata_queue = {},
			}
			_tracked_units[attacked_unit] = state
		end
		local entry = {
			attack_type = attack_type,
			hit_weakspot = hit_weakspot,
			is_critical_strike = is_critical_strike,
			reported_damage = damage,
			hit_world_position = hit_world_position and Vector3Box(hit_world_position) or nil,
			timestamp = os.clock(),
		}
		state.metadata_queue[#state.metadata_queue + 1] = entry
	end)

mod.update = function(dt, t)
	if not mod:is_enabled() then return end

	local local_player = Managers.player:local_player_safe(1)
	if not local_player then return end

	local now = os.clock()
	local s = mod.cached_settings
	local tracking_needed = (s.tracking_mode ~= "disabled")

	local units_to_drain = {}

	for unit, state in pairs(_tracked_units) do
		if not Unit.alive(unit) then
			if #state.metadata_queue > 0 then
				units_to_drain[#units_to_drain + 1] = { unit = unit, state = state }
			else
				_tracked_units[unit] = nil
			end
			goto continue_poll
		end

		if #state.metadata_queue == 0 then
			goto continue_poll
		end

		mod._purge_stale_entries(state, now)

		if #state.metadata_queue > 0 then
			units_to_drain[#units_to_drain + 1] = { unit = unit, state = state }
		end

		::continue_poll::
	end

	for i = 1, #units_to_drain do
		local info = units_to_drain[i]
		local unit = info.unit
		local state = info.state

		local health_extension = ScriptUnit.has_extension(unit, "health_system")
		if not health_extension then
			_tracked_units[unit] = nil
			goto next_unit
		end

		local current_total = health_extension:total_damage_taken()
		local prev_total = state.prev_total_damage
		local delta = current_total - prev_total

		if delta <= 0 then
			goto next_unit
		end

		local queue = state.metadata_queue
		state.metadata_queue = {}
		state.prev_total_damage = current_total

		mod._process_drained_queue(unit, state.breed_or_nil, queue, delta, tracking_needed, s)

		if not Unit.alive(unit) then
			_tracked_units[unit] = nil
		end

		::next_unit::
	end

	mod._last_cleanup_time = mod._last_cleanup_time or 0
	if now - mod._last_cleanup_time > 5 then
		mod._last_cleanup_time = now
		for unit, state in pairs(_tracked_units) do
			if not Unit.alive(unit) and #state.metadata_queue == 0 then
				_tracked_units[unit] = nil
			end
		end
	end
end
