local mod = get_mod("DamageTracker")
local Breed = mod:original_require("scripts/utilities/breed")

mod._health_cache = {}
setmetatable(mod._health_cache, { __mode = "k" })


mod.cached_settings = {
	enable_overkill = false,
	use_k_format = true,
	tracking_mode = "separated",
	fct_show_normal = true,
	fct_show_pure_weakspot = true,
	fct_show_pure_crit = true,
	fct_show_weakspot_crit = true,
	fct_show_dot = true,
	fct_show_explosion = true,
	fct_damage_threshold = 0,
	floating_weapon_filter = "both",
	floating_style = "compact",
	fct_los_check = false,
}

local function update_cached_settings()
	mod.cached_settings.enable_overkill = mod:get("enable_overkill_damage")
	mod.cached_settings.use_k_format = mod:get("use_k_format")
	mod.cached_settings.tracking_mode = mod:get("tracking_mode") or "separated"
	mod.cached_settings.fct_show_normal = mod:get("fct_show_normal")
	mod.cached_settings.fct_show_pure_weakspot = mod:get("fct_show_pure_weakspot")
	mod.cached_settings.fct_show_pure_crit = mod:get("fct_show_pure_crit")
	mod.cached_settings.fct_show_weakspot_crit = mod:get("fct_show_weakspot_crit")
	mod.cached_settings.fct_show_dot = mod:get("fct_show_dot")
	mod.cached_settings.fct_show_explosion = mod:get("fct_show_explosion")
	mod.cached_settings.fct_damage_threshold = mod:get("fct_damage_threshold") or 0
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

local function is_fct_eligible(hit_type, s)
	if hit_type == "normal" then return s.fct_show_normal
	elseif hit_type == "pure_weakspot" then return s.fct_show_pure_weakspot
	elseif hit_type == "pure_crit" then return s.fct_show_pure_crit
	elseif hit_type == "weakspot_crit" then return s.fct_show_weakspot_crit
	elseif hit_type == "dot" then return s.fct_show_dot
	elseif hit_type == "explosion" then return s.fct_show_explosion
	end
	return true
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

		local unit_data_extension = ScriptUnit.has_extension(attacked_unit, "unit_data_system")
		local breed_or_nil = unit_data_extension and unit_data_extension:breed()
		local is_minion = breed_or_nil and Breed.is_minion(breed_or_nil)

		if is_minion and attack_result ~= "died" then
			local health_ext = ScriptUnit.has_extension(attacked_unit, "health_system")
			if health_ext then
				local post_health = health_ext:current_health()
				if post_health > 0 then
					mod._health_cache[attacked_unit] = post_health
				end
			end
		end

		local local_player = Managers.player:local_player(1)
		if not local_player or local_player.player_unit ~= attacking_unit then return end

		local s = mod.cached_settings

		local is_dot = (attack_type == "buff" or attack_type == "damage_over_time")
		local is_explosion = (attack_type == "explosion")
		local is_w = hit_weakspot
		local is_c = is_critical_strike

		local hit_type = "normal"
		if is_dot then
			hit_type = "dot"
		elseif is_explosion then
			hit_type = "explosion"
		elseif is_w and is_c then
			hit_type = "weakspot_crit"
		elseif is_w then
			hit_type = "pure_weakspot"
		elseif is_c then
			hit_type = "pure_crit"
		end

		local tracking_needed = (s.tracking_mode ~= "disabled")
		local fct_needed = is_fct_eligible(hit_type, s)

		if not tracking_needed and not fct_needed then return end

		if not is_minion then return end

		local unit_health_extension = ScriptUnit.has_extension(attacked_unit, "health_system")
		if not unit_health_extension then return end

		local max_hp = unit_health_extension:max_health()
		local actual_damage

		if attack_result == "died" then
			local cached = mod._health_cache[attacked_unit]
			actual_damage = (cached and cached > 0) and cached or max_hp
		else
			if breed_or_nil and breed_or_nil.clamp_health_percent_damage then
				local health_damage_cap = max_hp * breed_or_nil.clamp_health_percent_damage
				damage = math.min(damage, health_damage_cap)
			end
			actual_damage = damage
		end

		local final_damage = s.enable_overkill and damage or actual_damage
		final_damage = math.ceil(final_damage)
		if final_damage <= 0 then return end

		-- [1] Static tracking events
		if tracking_needed then
			local mode = s.tracking_mode
			if is_dot then
				if mode == "combined" or mode == "separated" or mode == "dot_only" then
					Managers.event:trigger("damage_tracker_on_damage", final_damage, "main_dot", final_damage)
				end
			else
				if mode == "combined" or mode == "separated" or mode == "direct_only" then
					Managers.event:trigger("damage_tracker_on_damage", final_damage, "main_direct", final_damage)
				end
			end
		end

		-- [2] FCT weapon filter
		if fct_needed then
			local wf = s.floating_weapon_filter
			local pass_weapon = (wf == "both") or
				(wf == "melee_only" and attack_type == "melee") or
				(wf == "ranged_only" and attack_type == "ranged")
			if not pass_weapon then return end

			local threshold = s.fct_damage_threshold
			if threshold > 0 and final_damage < threshold then return end

			local breed_category = classify_breed_category(breed_or_nil)
			local fct_world_pos = (attack_type ~= "explosion") and hit_world_position or nil
			if not fct_world_pos and attacked_unit and Unit.has_node(attacked_unit, "j_spine") then
				fct_world_pos = Unit.world_position(attacked_unit, Unit.node(attacked_unit, "j_spine"))
			end
			fct_world_pos = fct_world_pos or POSITION_LOOKUP[attacked_unit] or Unit.world_position(attacked_unit, 1)
			Managers.event:trigger("damage_tracker_on_floating_damage", final_damage, hit_type, Vector3Box(fct_world_pos),
				attacked_unit, breed_category)
		end
	end)

mod.update = function(dt, t)
	local cache = mod._health_cache
	for unit, _ in pairs(cache) do
		if HEALTH_ALIVE[unit] then
			local health_ext = ScriptUnit.has_extension(unit, "health_system")
			if health_ext then
				local health = health_ext:current_health()
				if health > 0 then
					cache[unit] = health
				end
			end
		end
	end
	
end