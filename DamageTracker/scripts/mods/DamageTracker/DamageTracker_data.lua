local mod = get_mod("DamageTracker")

local color_options = {}
for _, name in ipairs(Color.list) do
	local c = Color[name](255, true)
	local text = string.format("{#color(%s,%s,%s)}%s", c[2], c[3], c[4], string.gsub(name, "_", " "))
	table.insert(color_options, { text = text, value = name })
end
table.sort(color_options, function(a, b) return a.text < b.text end)

local tracking_mode_options = {
	{ text = "mode_combined",    value = "combined" },
	{ text = "mode_separated",   value = "separated" },
	{ text = "mode_direct_only", value = "direct_only" },
	{ text = "mode_dot_only",    value = "dot_only" },
	{ text = "mode_disabled",    value = "disabled" },
}

local format_options = {
	{ text = "mode_both",        value = "both" },
	{ text = "mode_total_only",  value = "total_only" },
	{ text = "mode_single_only", value = "single_only" },
}

	local floating_style_options = {
	{ text = "fct_style_fixed",   value = "fixed" },
	{ text = "fct_style_compact", value = "compact" },
	{ text = "fct_style_float",   value = "float" },
}

local finesse_weapon_options = {
	{ text = "weapon_filter_both",   value = "both" },
	{ text = "weapon_filter_melee",  value = "melee_only" },
	{ text = "weapon_filter_ranged", value = "ranged_only" },
}

local icon_options = {
	{ text = "icon_none",                      value = "none" },
	{ text = "icon_weapons",                   value = "weapons" },
	{ text = "icon_objective_main",            value = "objective_main" },
	{ text = "icon_incapacitated",             value = "incapacitated" },
	{ text = "icon_dead",                      value = "dead" },
	{ text = "icon_pocketable_syringe_power",  value = "pocketable_syringe_power" },
	{ text = "icon_scars",                     value = "scars" },
	{ text = "icon_mission_type_01",           value = "mission_type_01" },
	{ text = "icon_difficulty_skull_heresy",   value = "difficulty_skull_heresy" },
	{ text = "icon_difficulty_skull_uprising", value = "difficulty_skull_uprising" },
	{ text = "icon_preset_19",                 value = "preset_19" },
}

local data = {
	name = mod:localize("mod_title"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets = {
			-- General checkboxes
			{ setting_id = "enable_overkill_damage", type = "checkbox", default_value = false },
			{ setting_id = "use_k_format",           type = "checkbox", default_value = true },

			-- Static Damage Display
			{
				setting_id = "main_tracking_setting",
				type = "group",
				sub_widgets = {
					{ setting_id = "tracking_mode",  type = "dropdown", default_value = "separated", options = table.clone(tracking_mode_options) },
					{ setting_id = "display_format", type = "dropdown", default_value = "both",      options = table.clone(format_options) },
					{ setting_id = "main_text_size", type = "numeric",  default_value = 35,          range = { 20, 80 } },
					{ setting_id = "main_x",         type = "numeric",  default_value = 350,         range = { -900, 900 } },
					{ setting_id = "main_y",         type = "numeric",  default_value = 150,         range = { -900, 900 } },
					{
						setting_id = "main_font_type",
						type = "dropdown",
						default_value = "machine_medium",
						options = {
							{ text = "font_machine_medium",      value = "machine_medium" },
							{ text = "font_proxima_nova_bold",   value = "proxima_nova_bold" },
							{ text = "font_proxima_nova_medium", value = "proxima_nova_medium" },
							{ text = "font_mono_tide_bold",      value = "mono_tide_bold" },
							{ text = "font_mono_tide_medium",    value = "mono_tide_medium" },
							{ text = "font_itc_novarese_bold",   value = "itc_novarese_bold" },
							{ text = "font_arial",               value = "arial" },
						}
					},
					{ setting_id = "combined_color", type = "dropdown", default_value = "terminal_text_header",     options = table.clone(color_options) },
					{ setting_id = "combined_icon",  type = "dropdown", default_value = "mission_type_01",          options = table.clone(icon_options) },
					{ setting_id = "direct_color",   type = "dropdown", default_value = "ui_hud_green_super_light", options = table.clone(color_options) },
					{ setting_id = "direct_icon",    type = "dropdown", default_value = "weapons",                  options = table.clone(icon_options) },
					{ setting_id = "dot_color",      type = "dropdown", default_value = "medium_turquoise",         options = table.clone(color_options) },
					{ setting_id = "dot_icon",       type = "dropdown", default_value = "dead",                     options = table.clone(icon_options) },
				},
			},

			-- Floating Combat Text
			{
				setting_id = "floating_text_setting",
				type = "group",
				sub_widgets = {
					{
						setting_id = "fct_general",
						type = "group",
						sub_widgets = {
							{
									setting_id = "fct_hit_types",
									type = "group",
									sub_widgets = {
										{ setting_id = "fct_show_normal",         type = "checkbox", default_value = true },
										{ setting_id = "fct_show_pure_weakspot",  type = "checkbox", default_value = true },
										{ setting_id = "fct_show_pure_crit",      type = "checkbox", default_value = true },
										{ setting_id = "fct_show_weakspot_crit",  type = "checkbox", default_value = true },
										{ setting_id = "fct_show_dot",            type = "checkbox", default_value = false },
										{ setting_id = "fct_show_explosion",      type = "checkbox", default_value = true },
									},
								},
								{ setting_id = "fct_damage_threshold", type = "numeric", default_value = 0,
								  range = {0, 10000}, decimals_number = 0, step_size_value = 1 },
							{ setting_id = "floating_style",            type = "dropdown", default_value = "float",    options = table.clone(floating_style_options) },
							{ setting_id = "floating_weapon_filter",    type = "dropdown", default_value = "both",       options = table.clone(finesse_weapon_options) },
							{
								setting_id = "fct_font_type",
								type = "dropdown",
								default_value = "machine_medium",
								options = {
									{ text = "font_machine_medium",      value = "machine_medium" },
									{ text = "font_proxima_nova_bold",   value = "proxima_nova_bold" },
									{ text = "font_proxima_nova_medium", value = "proxima_nova_medium" },
									{ text = "font_mono_tide_bold",      value = "mono_tide_bold" },
									{ text = "font_mono_tide_medium",    value = "mono_tide_medium" },
									{ text = "font_itc_novarese_bold",   value = "itc_novarese_bold" },
									{ text = "font_arial",               value = "arial" },
								}
							},
						},
					},
					{
						setting_id = "fct_enemy_filters",
						type = "group",
						sub_widgets = {
							{ setting_id = "fct_show_horde",   type = "checkbox", default_value = true },
							{ setting_id = "fct_show_elite",   type = "checkbox", default_value = true },
							{ setting_id = "fct_show_special", type = "checkbox", default_value = true },
							{ setting_id = "fct_show_boss",    type = "checkbox", default_value = true },
							{ setting_id = "fct_show_other",   type = "checkbox", default_value = true },
						},
					},
					{
						setting_id = "fct_fixed_mode",
						type = "group",
						sub_widgets = {
							{ setting_id = "floating_x",                type = "numeric",  default_value = -15,                         range = { -900, 900 } },
							{ setting_id = "floating_y",                type = "numeric",  default_value = -240,                        range = { -900, 900 } },
							{ setting_id = "fixed_normal_color",        type = "dropdown", default_value = "ui_hud_green_super_light",  options = table.clone(color_options) },
							{ setting_id = "fixed_normal_size",         type = "numeric",  default_value = 35,                          range = { 10, 100 } },
							{ setting_id = "fixed_normal_icon",         type = "dropdown", default_value = "none",                      options = table.clone(icon_options) },
							{ setting_id = "fixed_dot_color",           type = "dropdown", default_value = "medium_turquoise",          options = table.clone(color_options) },
							{ setting_id = "fixed_dot_size",            type = "numeric",  default_value = 25,                          range = { 10, 100 } },
							{ setting_id = "fixed_dot_icon",            type = "dropdown", default_value = "none",                      options = table.clone(icon_options) },
							{ setting_id = "fixed_pure_crit_color",     type = "dropdown", default_value = "ui_hud_red_light",          options = table.clone(color_options) },
							{ setting_id = "fixed_pure_crit_size",      type = "numeric",  default_value = 40,                          range = { 20, 100 } },
							{ setting_id = "fixed_pure_crit_icon",      type = "dropdown", default_value = "objective_main",            options = table.clone(icon_options) },
							{ setting_id = "fixed_pure_weakspot_color", type = "dropdown", default_value = "ui_orange_light",           options = table.clone(color_options) },
							{ setting_id = "fixed_pure_weakspot_size",  type = "numeric",  default_value = 40,                          range = { 20, 100 } },
							{ setting_id = "fixed_pure_weakspot_icon",  type = "dropdown", default_value = "difficulty_skull_uprising", options = table.clone(icon_options) },
							{ setting_id = "fixed_weakspot_crit_color", type = "dropdown", default_value = "citadel_wrack_white",       options = table.clone(color_options) },
							{ setting_id = "fixed_weakspot_crit_size",  type = "numeric",  default_value = 45,                          range = { 20, 100 } },
							{ setting_id = "fixed_weakspot_crit_icon",  type = "dropdown", default_value = "pocketable_syringe_power",  options = table.clone(icon_options) },
							{ setting_id = "fixed_explosion_color",     type = "dropdown", default_value = "deep_pink",                    options = table.clone(color_options) },
							{ setting_id = "fixed_explosion_size",      type = "numeric",  default_value = 38,                          range = { 10, 100 } },
							{ setting_id = "fixed_explosion_icon",      type = "dropdown", default_value = "preset_19",                 options = table.clone(icon_options) },
						},
					},
					{
						setting_id = "fct_compact_mode",
						type = "group",
						sub_widgets = {
							{ setting_id = "fct_offset_head",             type = "numeric",  default_value = -50,                         range = { -300, 300 } },
							{ setting_id = "fct_offset_body",             type = "numeric",  default_value = -50,                           range = { -300, 300 } },
							{ setting_id = "fct_distance_scaling",        type = "checkbox", default_value = true },
							{ setting_id = "fct_distance_reference",      type = "numeric",  default_value = 10,                          range = { 5, 30 } },
							{ setting_id = "fct_los_check",               type = "checkbox", default_value = false },
							{ setting_id = "compact_normal_color",        type = "dropdown", default_value = "ui_hud_green_super_light",  options = table.clone(color_options) },
							{ setting_id = "compact_normal_size",         type = "numeric",  default_value = 35,                          range = { 10, 100 } },
							{ setting_id = "compact_normal_icon",         type = "dropdown", default_value = "none",                      options = table.clone(icon_options) },
							{ setting_id = "compact_dot_color",           type = "dropdown", default_value = "medium_turquoise",          options = table.clone(color_options) },
							{ setting_id = "compact_dot_size",            type = "numeric",  default_value = 25,                          range = { 10, 100 } },
							{ setting_id = "compact_dot_icon",            type = "dropdown", default_value = "none",                      options = table.clone(icon_options) },
							{ setting_id = "compact_pure_crit_color",     type = "dropdown", default_value = "ui_hud_red_light",          options = table.clone(color_options) },
							{ setting_id = "compact_pure_crit_size",      type = "numeric",  default_value = 40,                          range = { 20, 100 } },
							{ setting_id = "compact_pure_crit_icon",      type = "dropdown", default_value = "objective_main",            options = table.clone(icon_options) },
							{ setting_id = "compact_pure_weakspot_color", type = "dropdown", default_value = "ui_orange_light",           options = table.clone(color_options) },
							{ setting_id = "compact_pure_weakspot_size",  type = "numeric",  default_value = 40,                          range = { 20, 100 } },
							{ setting_id = "compact_pure_weakspot_icon",  type = "dropdown", default_value = "difficulty_skull_uprising", options = table.clone(icon_options) },
							{ setting_id = "compact_weakspot_crit_color", type = "dropdown", default_value = "citadel_wrack_white",       options = table.clone(color_options) },
							{ setting_id = "compact_weakspot_crit_size",  type = "numeric",  default_value = 45,                          range = { 20, 100 } },
							{ setting_id = "compact_weakspot_crit_icon",  type = "dropdown", default_value = "pocketable_syringe_power",  options = table.clone(icon_options) },
							{ setting_id = "compact_explosion_color",     type = "dropdown", default_value = "deep_pink",                    options = table.clone(color_options) },
							{ setting_id = "compact_explosion_size",      type = "numeric",  default_value = 38,                          range = { 10, 100 } },
							{ setting_id = "compact_explosion_icon",      type = "dropdown", default_value = "preset_19",                 options = table.clone(icon_options) },
						},
					},
					{
						setting_id = "fct_float_mode",
						type = "group",
						sub_widgets = {
							{ setting_id = "float_head_offset",         type = "numeric",  default_value = -20,                        range = { -150, 150 } },
							{ setting_id = "float_body_offset",         type = "numeric",  default_value = -20,                        range = { -150, 150 } },
							{ setting_id = "float_dot_offset",          type = "numeric",  default_value = 20,                         range = { -150, 150 } },
							{ setting_id = "float_distance_scaling",    type = "checkbox", default_value = true },
							{ setting_id = "float_los_check",           type = "checkbox", default_value = false },
							{ setting_id = "float_normal_color",        type = "dropdown", default_value = "ui_hud_green_super_light", options = table.clone(color_options) },
							{ setting_id = "float_normal_size",         type = "numeric",  default_value = 40,                         range = { 10, 100 } },
							{ setting_id = "float_normal_icon",         type = "dropdown", default_value = "none",                     options = table.clone(icon_options) },
							{ setting_id = "float_dot_color",           type = "dropdown", default_value = "medium_turquoise",         options = table.clone(color_options) },
							{ setting_id = "float_dot_size",            type = "numeric",  default_value = 30,                         range = { 10, 100 } },
							{ setting_id = "float_dot_icon",            type = "dropdown", default_value = "none",                     options = table.clone(icon_options) },
							{ setting_id = "float_pure_crit_color",     type = "dropdown", default_value = "ui_hud_red_light",         options = table.clone(color_options) },
							{ setting_id = "float_pure_crit_size",      type = "numeric",  default_value = 45,                         range = { 20, 100 } },
							{ setting_id = "float_pure_crit_icon",      type = "dropdown", default_value = "objective_main",           options = table.clone(icon_options) },
							{ setting_id = "float_pure_weakspot_color", type = "dropdown", default_value = "ui_orange_light",          options = table.clone(color_options) },
							{ setting_id = "float_pure_weakspot_size",  type = "numeric",  default_value = 50,                         range = { 20, 100 } },
							{ setting_id = "float_pure_weakspot_icon",  type = "dropdown", default_value = "difficulty_skull_uprising",                    options = table.clone(icon_options) },
							{ setting_id = "float_weakspot_crit_color", type = "dropdown", default_value = "citadel_wrack_white",      options = table.clone(color_options) },
							{ setting_id = "float_weakspot_crit_size",  type = "numeric",  default_value = 55,                         range = { 20, 100 } },
							{ setting_id = "float_weakspot_crit_icon",  type = "dropdown", default_value = "pocketable_syringe_power", options = table.clone(icon_options) },
							{ setting_id = "float_explosion_color",     type = "dropdown", default_value = "deep_pink",                   options = table.clone(color_options) },
							{ setting_id = "float_explosion_size",      type = "numeric",  default_value = 45,                         range = { 10, 100 } },
							{ setting_id = "float_explosion_icon",      type = "dropdown", default_value = "preset_19",                options = table.clone(icon_options) },
						},
					},
				},
			},
		},
	},
}

return data
