/// Preset central command names to chose from for centcom reports.
#define CENTCOM_PRESET "Central Command"
#define SYNDICATE_PRESET "The Syndicate"
#define WIZARD_PRESET "The Wizard Federation"
#define CUSTOM_PRESET "Custom Command Name"

ADMIN_VERB(change_command_name, R_ADMIN, FALSE, "Change Command Name", "Change the name of Central Command.", ADMIN_CATEGORY_EVENTS)
	var/input = input(user, "Please input a new name for Central Command.", "What?", "") as text | null
	if(!input)
		return
	change_command_name(input)
	message_admins("[key_name_admin(user)] has changed Central Command's name to [input]")
	log_admin("[key_name(user)] has changed the Central Command name to: [input]")

/// Verb to open the create command report window and send command reports.
ADMIN_VERB(create_command_report, R_ADMIN, FALSE, "Create Command Report", "Create a command report to be sent to the station.", ADMIN_CATEGORY_EVENTS)
	BLACKBOX_LOG_ADMIN_VERB("Create Command Report")
	var/datum/command_report_menu/tgui = new /datum/command_report_menu(user.mob)
	tgui.ui_interact(user.mob)

/// Datum for holding the TGUI window for command reports.
/datum/command_report_menu
	/// The mob using the UI.
	var/mob/ui_user
	/// The name of central command that will accompany our report
	var/command_name = CENTCOM_PRESET
	/// Whether we are using a custom name instead of a preset.
	var/custom_name
	/// The actual contents of the report we're going to send.
	var/command_report_content
	/// Whether the report's contents are announced.
	var/announce_contents = TRUE
	/// Whether a copy of the report is printed at every console.
	var/print_report = TRUE
	/// The sound that's going to accompany our message.
	var/played_sound = DEFAULT_COMMANDREPORT_SOUND
	/// The colour of the announcement when sent
	var/announcement_color = "default"
	/// The subheader to include when sending the announcement. Keep blank to not include a subheader
	var/subheader = ""
	/// A static list of preset names that can be chosen.
	var/list/preset_names = list(CENTCOM_PRESET, SYNDICATE_PRESET, WIZARD_PRESET, CUSTOM_PRESET)

/datum/command_report_menu/New(mob/user)
	ui_user = user
	if(command_name() != CENTCOM_PRESET)
		command_name = command_name()
		preset_names.Insert(1, command_name())

/datum/command_report_menu/ui_state(mob/user)
	return ADMIN_STATE(R_ADMIN)

/datum/command_report_menu/ui_close()
	qdel(src)

/datum/command_report_menu/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "CommandReport")
		ui.open()

/datum/command_report_menu/ui_data(mob/user)
	var/list/data = list()
	data["command_name"] = command_name
	data["custom_name"] = custom_name
	data["command_report_content"] = command_report_content
	data["announce_contents"] = announce_contents
	data["print_report"] = print_report
	data["played_sound"] = played_sound
	data["announcement_color"] = announcement_color
	data["subheader"] = subheader

	return data

/datum/command_report_menu/ui_static_data(mob/user)
	var/list/data = list()
	data["command_name_presets"] = preset_names
	data["announcer_sounds"] = list(DEFAULT_COMMANDREPORT_SOUND, DEFAULT_ALERT_SOUND, CUSTOM_ALERT_SOUND) + GLOB.announcer_keys // Monkestation edit - custom alert sounds
	data["announcement_colors"] = ANNOUNCEMENT_COLORS

	return data

/datum/command_report_menu/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	switch(action)
		if("update_command_name")
			if(params["updated_name"] == CUSTOM_PRESET)
				custom_name = TRUE
			else if (params["updated_name"] in preset_names)
				custom_name = FALSE

			command_name = params["updated_name"]
		if("set_report_sound")
			// monkestation start
			if (params["picked_sound"] == CUSTOM_ALERT_SOUND)
				var/soundInput = input(ui_user, "Please pick a sound file to play when you create the command report.", "Pick a Sound File") as null|sound
				if (isnull(soundInput))
					to_chat(ui_user, span_danger("No file was selected."))
					custom_played_sound = null
					played_sound = DEFAULT_ALERT_SOUND
				else
					custom_played_sound = soundInput
					played_sound = CUSTOM_ALERT_SOUND
			else
				played_sound = params["picked_sound"]
		//monkestation end
		if("toggle_announce")
			announce_contents = !announce_contents
		if("toggle_printing")
			print_report = !print_report
		if("update_announcement_color")
			var/colors = ANNOUNCEMENT_COLORS
			var/chosen_color = params["updated_announcement_color"]
			if(chosen_color in colors)
				announcement_color = chosen_color
		if("set_subheader")
			subheader = params["new_subheader"]
		if("submit_report")
			if(!command_name)
				to_chat(ui_user, span_danger("You can't send a report with no command name."))
				return
			if(!params["report"])
				to_chat(ui_user, span_danger("You can't send a report with no contents."))
				return
			command_report_content = params["report"]
			var/is_preview = params["preview"] //monkestation edit - report previewing
			send_announcement(is_preview) //monkestation edit - report previewing

	return TRUE

/*
 * The actual proc that sends the priority announcement and reports
 *
 * Uses the variables set by the user on our datum as the arguments for the report.
 */
/datum/command_report_menu/proc/send_announcement(preview = FALSE)
	/// Our current command name to swap back to after sending the report.
	var/original_command_name = command_name()
	change_command_name(command_name)

	/// The sound we're going to play on report.
	var/report_sound = played_sound
	// monkestation edit start - Custom alert sounds
	switch(played_sound)
		if (DEFAULT_COMMANDREPORT_SOUND)
			report_sound = SSstation.announcer.get_rand_report_sound()
		if (DEFAULT_ALERT_SOUND)
			report_sound = SSstation.announcer.get_rand_alert_sound()
		if (CUSTOM_ALERT_SOUND)
			if (!isnull(custom_played_sound))
				report_sound = custom_played_sound
			else
				to_chat(ui_user, span_danger("The custom sound you selected was not able to be played. Aborting..."))
				played_sound = DEFAULT_ALERT_SOUND
				change_command_name(original_command_name)
				return
	// monkestation end

	if(announce_contents)
		var/chosen_color = announcement_color
		if(chosen_color == "default")
			if(command_name == SYNDICATE_PRESET)
				chosen_color = "red"
			else if(command_name == WIZARD_PRESET)
				chosen_color = "purple"
		// monkestation edit start - preview reports, togglable update append
		if (preview)
			to_chat(ui_user, "The following is a preview of what the command report will look like for other players.")
			priority_announce(command_report_content, subheader == ""? null : subheader, report_sound, has_important_message = TRUE, color_override = chosen_color, append_update = append_update_name, encode_title = sanitize_content, encode_text = sanitize_content, players = list(ui_user))
		else
			priority_announce(command_report_content, subheader == ""? null : subheader, report_sound, has_important_message = TRUE, color_override = chosen_color, append_update = append_update_name, encode_title = sanitize_content, encode_text = sanitize_content)
		// monkestation edit end

	if(!preview && (!announce_contents || print_report))
		print_command_report(command_report_content, "[announce_contents ? "" : "Classified "][command_name] Update", !announce_contents, sanitize = sanitize_content)

	change_command_name(original_command_name)

	if (!preview) // monkestation edit - preview reports
		log_admin("[key_name(ui_user)] has created a command report: \"[command_report_content]\", sent from \"[command_name]\" with the sound \"[played_sound]\".")
		message_admins("[key_name_admin(ui_user)] has created a command report, sent from \"[command_name]\" with the sound \"[played_sound]\"")


#undef CENTCOM_PRESET
#undef SYNDICATE_PRESET
#undef WIZARD_PRESET
#undef CUSTOM_PRESET
