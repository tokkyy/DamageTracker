return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`DamageTracker` encountered an error loading the Darktide Mod Framework.")
		new_mod("DamageTracker", {
			mod_script       = "DamageTracker/scripts/mods/DamageTracker/DamageTracker",
			mod_data         = "DamageTracker/scripts/mods/DamageTracker/DamageTracker_data",
			mod_localization = "DamageTracker/scripts/mods/DamageTracker/DamageTracker_localization",
		})
	end,
	packages = {},
}