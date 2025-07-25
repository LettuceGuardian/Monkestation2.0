#define FAILURE 0
#define SUCCESS 1
#define NO_FUEL 2
#define ALREADY_LIT 3

/obj/item/flashlight
	name = "flashlight"
	desc = "A hand-held emergency light."
	custom_price = PAYCHECK_CREW
	icon = 'icons/obj/lighting.dmi'
	dir = WEST
	icon_state = "flashlight"
	inhand_icon_state = "flashlight"
	worn_icon_state = "flashlight"
	lefthand_file = 'icons/mob/inhands/items/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items/devices_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	flags_1 = CONDUCT_1
	slot_flags = ITEM_SLOT_BELT
	custom_materials = list(/datum/material/iron= SMALL_MATERIAL_AMOUNT * 0.5, /datum/material/glass= SMALL_MATERIAL_AMOUNT * 0.2)
	actions_types = list(/datum/action/item_action/toggle_light)
	action_slots = ALL
	light_system = OVERLAY_LIGHT_DIRECTIONAL
	light_outer_range = 4
	light_power = 1
	light_on = FALSE
	/// If we've been forcibly disabled for a temporary amount of time.
	COOLDOWN_DECLARE(disabled_time)
	/// Can we toggle this light on and off (used for contexual screentips only)
	var/toggle_context = TRUE
	/// The sound the light makes when it's turned on
	var/sound_on = 'sound/weapons/magin.ogg'
	/// The sound the light makes when it's turned off
	var/sound_off = 'sound/weapons/magout.ogg'
	/// Is the light turned on or off currently
	var/on = FALSE
	var/start_on = FALSE

/obj/item/flashlight/Initialize(mapload)
	. = ..()
	if(start_on)
		set_light_on(TRUE)
	if(icon_state == "[initial(icon_state)]-on")
		on = TRUE
	update_brightness()
	register_context()

/obj/item/flashlight/add_context(atom/source, list/context, obj/item/held_item, mob/living/user)
	// single use lights can be toggled on once
	if(isnull(held_item) && (toggle_context || !on))
		context[SCREENTIP_CONTEXT_RMB] = "Toggle light"
		return CONTEXTUAL_SCREENTIP_SET

	if(istype(held_item, /obj/item/flashlight) && (toggle_context || !on))
		context[SCREENTIP_CONTEXT_LMB] = "Toggle light"
		return CONTEXTUAL_SCREENTIP_SET

	return NONE

/obj/item/flashlight/proc/update_brightness()
	if(on)
		icon_state = "[initial(icon_state)]-on"
		if(!isnull(inhand_icon_state))
			inhand_icon_state = "[initial(inhand_icon_state)]-on"
	else
		icon_state = initial(icon_state)
		if(!isnull(inhand_icon_state))
			inhand_icon_state = initial(inhand_icon_state)
	set_light_on(on)
	if(light_system == COMPLEX_LIGHT)
		update_light()

/obj/item/flashlight/proc/toggle_light(mob/user)
	var/disrupted = FALSE
	on = !on
	playsound(src, on ? sound_on : sound_off, 40, TRUE)
	if(!COOLDOWN_FINISHED(src, disabled_time))
		if(user)
			balloon_alert(user, "disrupted!")
			on = FALSE
			disrupted = TRUE
	update_brightness()
	update_item_action_buttons()
	return !disrupted

/obj/item/flashlight/attack_self(mob/user)
	toggle_light(user)

/obj/item/flashlight/attack_hand_secondary(mob/user, list/modifiers)
	attack_self(user)
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/obj/item/flashlight/suicide_act(mob/living/carbon/human/user)
	if (user.is_blind())
		user.visible_message(span_suicide("[user] is putting [src] close to [user.p_their()] eyes and turning it on... but [user.p_theyre()] blind!"))
		return SHAME
	user.visible_message(span_suicide("[user] is putting [src] close to [user.p_their()] eyes and turning it on! It looks like [user.p_theyre()] trying to commit suicide!"))
	return FIRELOSS

/obj/item/flashlight/attack(mob/living/carbon/M, mob/living/carbon/human/user)
	add_fingerprint(user)
	if(istype(M) && on && (user.zone_selected in list(BODY_ZONE_PRECISE_EYES, BODY_ZONE_PRECISE_MOUTH)))

		if((HAS_TRAIT(user, TRAIT_CLUMSY) || HAS_TRAIT(user, TRAIT_DUMB)) && prob(50)) //too dumb to use flashlight properly
			return ..() //just hit them in the head

		if(!ISADVANCEDTOOLUSER(user))
			to_chat(user, span_warning("You don't have the dexterity to do this!"))
			return

		if(!M.get_bodypart(BODY_ZONE_HEAD))
			to_chat(user, span_warning("[M] doesn't have a head!"))
			return

		if(light_power < 1)
			to_chat(user, "[span_warning("\The [src] isn't bright enough to see anything!")] ")
			return

		var/render_list = list()//information will be packaged in a list for clean display to the user

		switch(user.zone_selected)
			if(BODY_ZONE_PRECISE_EYES)
				if((M.head && M.head.flags_cover & HEADCOVERSEYES) || (M.wear_mask && M.wear_mask.flags_cover & MASKCOVERSEYES) || (M.glasses && M.glasses.flags_cover & GLASSESCOVERSEYES))
					to_chat(user, span_warning("You're going to need to remove that [(M.head && M.head.flags_cover & HEADCOVERSEYES) ? "helmet" : (M.wear_mask && M.wear_mask.flags_cover & MASKCOVERSEYES) ? "mask": "glasses"] first!"))
					return

				var/obj/item/organ/internal/eyes/E = M.get_organ_slot(ORGAN_SLOT_EYES)
				var/obj/item/organ/internal/brain = M.get_organ_slot(ORGAN_SLOT_BRAIN)
				if(!E)
					to_chat(user, span_warning("[M] doesn't have any eyes!"))
					return

				M.flash_act(visual = TRUE, length = (user.istate & ISTATE_HARM) ? 2.5 SECONDS : 1 SECONDS) // Apply a 1 second flash effect to the target. The duration increases to 2.5 Seconds if you have combat mode on.

				if(M == user) //they're using it on themselves
					user.visible_message(span_warning("[user] shines [src] into [M.p_their()] eyes."), ignored_mobs = user)
					render_list += span_info("You direct [src] to into your eyes:\n")

					if(M.is_blind())
						render_list += "<span class='notice ml-1'>You're not entirely certain what you were expecting...</span>\n"
					else
						render_list += "<span class='notice ml-1'>Trippy!</span>\n"

				else
					user.visible_message(span_warning("[user] directs [src] to [M]'s eyes."), ignored_mobs = user)
					render_list += span_info("You direct [src] to [M]'s eyes:\n")

					if(M.stat == DEAD || M.is_blind())
						render_list += "<span class='danger ml-1'>[M.p_their(TRUE)] pupils don't react to the light!</span>\n"//mob is dead
					else if(brain.damage > 20)
						render_list += "<span class='danger ml-1'>[M.p_their(TRUE)] pupils contract unevenly!</span>\n"//mob has sustained damage to their brain
					else
						render_list += "<span class='notice ml-1'>[M.p_their(TRUE)] pupils narrow.</span>\n"//they're okay :D

					if(M.dna && M.dna.check_mutation(/datum/mutation/xray))
						render_list += "<span class='danger ml-1'>[M.p_their(TRUE)] pupils give an eerie glow!</span>\n"//mob has X-ray vision

				//display our packaged information in an examine block for easy reading
				to_chat(user, boxed_message(jointext(render_list, "")), type = MESSAGE_TYPE_INFO)

			if(BODY_ZONE_PRECISE_MOUTH)

				if(M.is_mouth_covered())
					to_chat(user, span_warning("You're going to need to remove that [(M.head && M.head.flags_cover & HEADCOVERSMOUTH) ? "helmet" : "mask"] first!"))
					return

				var/list/mouth_organs = new
				for(var/obj/item/organ/organ as anything in M.organs)
					if(organ.zone == BODY_ZONE_PRECISE_MOUTH)
						mouth_organs.Add(organ)
				var/organ_list = ""
				var/organ_count = LAZYLEN(mouth_organs)
				if(organ_count)
					for(var/I in 1 to organ_count)
						if(I > 1)
							if(I == mouth_organs.len)
								organ_list += ", and "
							else
								organ_list += ", "
						var/obj/item/organ/O = mouth_organs[I]
						organ_list += (O.gender == "plural" ? O.name : "\an [O.name]")

				var/pill_count = 0
				for(var/datum/action/item_action/hands_free/activate_pill/AP in M.actions)
					pill_count++

				if(M == user)//if we're looking on our own mouth
					var/can_use_mirror = FALSE
					if(isturf(user.loc))
						var/obj/structure/mirror/mirror = locate(/obj/structure/mirror, user.loc)
						if(mirror)
							switch(user.dir)
								if(NORTH)
									can_use_mirror = mirror.pixel_y > 0
								if(SOUTH)
									can_use_mirror = mirror.pixel_y < 0
								if(EAST)
									can_use_mirror = mirror.pixel_x > 0
								if(WEST)
									can_use_mirror = mirror.pixel_x < 0

					M.visible_message(span_notice("[M] directs [src] to [ M.p_their()] mouth."), ignored_mobs = user)
					render_list += span_info("You point [src] into your mouth:\n")
					if(!can_use_mirror)
						to_chat(user, span_notice("You can't see anything without a mirror."))
						return
					if(organ_count)
						render_list += "<span class='notice ml-1'>Inside your mouth [organ_count > 1 ? "are" : "is"] [organ_list].</span>\n"
					else
						render_list += "<span class='notice ml-1'>There's nothing inside your mouth.</span>\n"
					if(pill_count)
						render_list += "<span class='notice ml-1'>You have [pill_count] implanted pill[pill_count > 1 ? "s" : ""].</span>\n"

				else //if we're looking in someone elses mouth
					user.visible_message(span_notice("[user] directs [src] to [M]'s mouth."), ignored_mobs = user)
					render_list += span_info("You point [src] into [M]'s mouth:\n")
					if(organ_count)
						render_list += "<span class='notice ml-1'>Inside [ M.p_their()] mouth [organ_count > 1 ? "are" : "is"] [organ_list].</span>\n"
					else
						render_list += "<span class='notice ml-1'>[M] doesn't have any organs in [ M.p_their()] mouth.</span>\n"
					if(pill_count)
						render_list += "<span class='notice ml-1'>[M] has [pill_count] pill[pill_count > 1 ? "s" : ""] implanted in [ M.p_their()] teeth.</span>\n"

				//assess any suffocation damage
				var/hypoxia_status = M.getOxyLoss() > 20

				if(M == user)
					if(hypoxia_status)
						render_list += "<span class='danger ml-1'>Your lips appear blue!</span>\n"//you have suffocation damage
					else
						render_list += "<span class='notice ml-1'>Your lips appear healthy.</span>\n"//you're okay!
				else
					if(hypoxia_status)
						render_list += "<span class='danger ml-1'>[M.p_their(TRUE)] lips appear blue!</span>\n"//they have suffocation damage
					else
						render_list += "<span class='notice ml-1'>[M.p_their(TRUE)] lips appear healthy.</span>\n"//they're okay!

				//assess blood level
				if(M == user)
					render_list += span_info("You press a finger to your gums:\n")
				else
					render_list += span_info("You press a finger to [M.p_their()] gums:\n")

				if(M.blood_volume <= BLOOD_VOLUME_SAFE && M.blood_volume > BLOOD_VOLUME_OKAY)
					render_list += "<span class='danger ml-1'>Color returns slowly!</span>\n"//low blood
				else if(M.blood_volume <= BLOOD_VOLUME_OKAY)
					render_list += "<span class='danger ml-1'>Color does not return!</span>\n"//critical blood
				else
					render_list += "<span class='notice ml-1'>Color returns quickly.</span>\n"//they're okay :D

				//display our packaged information in an examine block for easy reading
				to_chat(user, boxed_message(jointext(render_list, "")), type = MESSAGE_TYPE_INFO)

	else
		return ..()

/// for directional sprites - so we get the same sprite in the inventory each time we pick one up
/obj/item/flashlight/equipped(mob/user, slot, initial)
	. = ..()
	setDir(initial(dir))
	SEND_SIGNAL(user, COMSIG_ATOM_DIR_CHANGE, user.dir, user.dir) // This is dumb, but if we don't do this then the lighting overlay may be facing the wrong direction depending on how it is picked up

/// for directional sprites - so when we drop the flashlight, it drops facing the same way the user is facing
/obj/item/flashlight/dropped(mob/user, silent = FALSE)
	. = ..()
	if(istype(user) && dir != user.dir)
		setDir(user.dir)

/// when hit by a light disruptor - turns the light off, forces the light to be disabled for a few seconds
/obj/item/flashlight/on_saboteur(datum/source, disrupt_duration)
	. = ..()
	if(on)
		toggle_light()
	COOLDOWN_START(src, disabled_time, disrupt_duration)
	return TRUE

/obj/item/flashlight/pen
	name = "penlight"
	desc = "A pen-sized light, used by medical staff. It can also be used to create a hologram to alert people of incoming medical assistance."
	dir = EAST
	icon_state = "penlight"
	inhand_icon_state = ""
	worn_icon_state = "pen"
	w_class = WEIGHT_CLASS_TINY
	flags_1 = CONDUCT_1
	light_outer_range = 2
	var/holo_cooldown = 0

/obj/item/flashlight/pen/afterattack(atom/target, mob/user, proximity_flag)
	. = ..()
	if(!proximity_flag)
		if(holo_cooldown > world.time)
			to_chat(user, span_warning("[src] is not ready yet!"))
			return
		var/T = get_turf(target)
		if(locate(/mob/living) in T)
			new /obj/effect/temp_visual/medical_holosign(T,user) //produce a holographic glow
			holo_cooldown = world.time + 10 SECONDS
			return

// see: [/datum/wound/burn/flesh/proc/uv()]
/obj/item/flashlight/pen/paramedic
	name = "paramedic penlight"
	desc = "A high-powered UV penlight intended to help stave off infection in the field on serious burned patients. Probably really bad to look into."
	icon_state = "penlight_surgical"
	/// Our current UV cooldown
	COOLDOWN_DECLARE(uv_cooldown)
	/// How long between UV fryings
	var/uv_cooldown_length = 30 SECONDS
	/// How much sanitization to apply to the burn wound
	var/uv_power = 1

/obj/effect/temp_visual/medical_holosign
	name = "medical holosign"
	desc = "A small holographic glow that indicates a medic is coming to treat a patient."
	icon_state = "medi_holo"
	duration = 30

/obj/effect/temp_visual/medical_holosign/Initialize(mapload, creator)
	. = ..()
	playsound(loc, 'sound/machines/ping.ogg', 50, FALSE) //make some noise!
	if(creator)
		visible_message(span_danger("[creator] created a medical hologram!"))

/obj/item/flashlight/seclite
	name = "seclite"
	desc = "A robust flashlight used by security."
	dir = EAST
	icon_state = "seclite"
	inhand_icon_state = "seclite"
	worn_icon_state = "seclite"
	lefthand_file = 'icons/mob/inhands/equipment/security_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/security_righthand.dmi'
	force = 9 // Not as good as a stun baton.
	light_outer_range = 5 // A little better than the standard flashlight.
	hitsound = 'sound/weapons/genhit1.ogg'

// the desk lamps are a bit special
/obj/item/flashlight/lamp
	name = "desk lamp"
	desc = "A desk lamp with an adjustable mount."
	icon_state = "lamp"
	inhand_icon_state = "lamp"
	lefthand_file = 'icons/mob/inhands/items_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items_righthand.dmi'
	force = 10
	light_outer_range = 3.5
	light_system = COMPLEX_LIGHT
	light_color = LIGHT_COLOR_FAINT_BLUE
	w_class = WEIGHT_CLASS_BULKY
	flags_1 = CONDUCT_1
	custom_materials = null
	on = TRUE

// green-shaded desk lamp
/obj/item/flashlight/lamp/green
	desc = "A classic green-shaded desk lamp."
	icon_state = "lampgreen"
	inhand_icon_state = "lampgreen"
	light_color = LIGHT_COLOR_TUNGSTEN

//Bananalamp
/obj/item/flashlight/lamp/bananalamp
	name = "banana lamp"
	desc = "Only a clown would think to make a ghetto banana-shaped lamp. Even has a goofy pullstring."
	icon_state = "bananalamp"
	inhand_icon_state = null
	light_color = LIGHT_COLOR_BRIGHT_YELLOW

// FLARES
/obj/item/flashlight/flare
	name = "flare"
	desc = "A red Nanotrasen issued flare. There are instructions on the side, it reads 'pull cord, make light'."
	light_outer_range = 7 // Pretty bright.
	icon_state = "flare"
	inhand_icon_state = "flare"
	worn_icon_state = "flare"
	actions_types = list()
	heat = 1000
	light_color = LIGHT_COLOR_FLARE
	light_system = OVERLAY_LIGHT
	grind_results = list(/datum/reagent/sulfur = 15)
	sound_on = 'sound/items/match_strike.ogg'
	toggle_context = FALSE
	/// How many seconds of fuel we have left
	var/fuel = 0
	/// Do we randomize the fuel when initialized
	var/randomize_fuel = TRUE
	/// How much damage it does when turned on
	var/on_damage = 7
	/// Type of atom thats spawns after fuel is used up
	var/trash_type = /obj/item/trash/flare
	/// If the light source can be extinguished
	var/can_be_extinguished = FALSE
	custom_materials = list(/datum/material/plastic= SMALL_MATERIAL_AMOUNT * 0.5)

/obj/item/flashlight/flare/Initialize(mapload)
	. = ..()
	if(randomize_fuel)
		fuel = rand(25 MINUTES, 35 MINUTES)
	if(on)
		attack_verb_continuous = string_list(list("burns", "singes"))
		attack_verb_simple = string_list(list("burn", "singe"))
		hitsound = 'sound/items/welder.ogg'
		force = on_damage
		damtype = BURN
		update_brightness()

/obj/item/flashlight/flare/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/item/flashlight/flare/attack(mob/living/carbon/victim, mob/living/carbon/user)
	if(!isliving(victim))
		return ..()

	if(on && victim.ignite_mob())
		message_admins("[ADMIN_LOOKUPFLW(user)] set [key_name_admin(victim)] on fire with [src] at [AREACOORD(user)]")
		user.log_message("set [key_name(victim)] on fire with [src]", LOG_ATTACK)

	return ..()

/obj/item/flashlight/flare/toggle_light()
	if(on || !fuel)
		return FALSE

	name = "lit [initial(name)]"
	attack_verb_continuous = string_list(list("burns", "singes"))
	attack_verb_simple = string_list(list("burn", "singe"))
	hitsound = 'sound/items/welder.ogg'
	force = on_damage
	damtype = BURN
	. = ..()

/obj/item/flashlight/flare/proc/turn_off()
	on = FALSE
	name = initial(name)
	attack_verb_continuous = initial(attack_verb_continuous)
	attack_verb_simple = initial(attack_verb_simple)
	hitsound = initial(hitsound)
	force = initial(force)
	damtype = initial(damtype)
	update_brightness()

/obj/item/flashlight/flare/extinguish()
	. = ..()
	if((fuel != INFINITY) && can_be_extinguished)
		turn_off()

/obj/item/flashlight/flare/update_brightness()
	..()
	inhand_icon_state = "[initial(inhand_icon_state)]" + (on ? "-on" : "")
	update_appearance()

/obj/item/flashlight/flare/process(seconds_per_tick)
	open_flame(heat)
	fuel = max(fuel - seconds_per_tick * (1 SECONDS), 0)

	if(!fuel || !on)
		turn_off()
		STOP_PROCESSING(SSobj, src)

		if(!fuel && trash_type)
			new trash_type(loc)
			qdel(src)

/obj/item/flashlight/flare/proc/ignition(mob/user)
	if(!fuel)
		if(user)
			balloon_alert(user, "out of fuel!")
		return NO_FUEL
	if(on)
		if(user)
			balloon_alert(user, "already lit!")
		return ALREADY_LIT
	if(!toggle_light())
		return FAILURE

	if(fuel != INFINITY)
		START_PROCESSING(SSobj, src)

	return SUCCESS

/obj/item/flashlight/flare/fire_act(exposed_temperature, exposed_volume)
	ignition()
	return ..()

/obj/item/flashlight/flare/attack_self(mob/user)
	if(ignition(user) == SUCCESS)
		user.visible_message(span_notice("[user] lights \the [src]."), span_notice("You light \the [initial(src.name)]!"))

/obj/item/flashlight/flare/get_temperature()
	return on * heat

/obj/item/flashlight/flare/candle
	name = "red candle"
	desc = "In Greek myth, Prometheus stole fire from the Gods and gave it to \
		humankind. The jewelry he kept for himself."
	icon = 'icons/obj/candle.dmi'
	icon_state = "candle1"
	inhand_icon_state = "candle"
	lefthand_file = 'icons/mob/inhands/items_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items_righthand.dmi'
	w_class = WEIGHT_CLASS_TINY
	heat = 1000
	light_color = LIGHT_COLOR_FIRE
	light_outer_range = 2
	fuel = 35 MINUTES
	randomize_fuel = FALSE
	trash_type = /obj/item/trash/candle
	can_be_extinguished = TRUE
	/// The current wax level, used for drawing the correct icon
	var/current_wax_level = 1
	/// The previous wax level, remembered so we only have to make 3 update_appearance calls total as opposed to every tick
	var/last_wax_level = 1

	/// Pollutant type for scented candles
	var/scented_type

/obj/item/flashlight/flare/candle/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/update_icon_updates_onmob, ITEM_SLOT_HANDS)

/**
 * Just checks the wax level of the candle for displaying the correct sprite.
 *
 * This gets called in process() every tick. If the wax level has changed, then we call our update.
 */
/obj/item/flashlight/flare/candle/proc/check_wax_level()
	switch(fuel)
		if(25 MINUTES to INFINITY)
			current_wax_level = 1
		if(15 MINUTES to 25 MINUTES)
			current_wax_level = 2
		if(0 to 15 MINUTES)
			current_wax_level = 3

	if(last_wax_level != current_wax_level)
		last_wax_level = current_wax_level
		update_appearance(UPDATE_ICON | UPDATE_NAME)

/obj/item/flashlight/flare/candle/update_icon_state()
	. = ..()
	icon_state = "candle[current_wax_level][on ? "_lit" : ""]"
	inhand_icon_state = "candle[on ? "_lit" : ""]"

/**
 * Try to ignite the candle.
 *
 * Candles are ignited a bit differently from flares, in that they must be manually lit from other fire sources.
 * This will perform all the necessary checks to ensure that can happen, and display a message if it worked.
 *
 * Arguments:
 * * obj/item/fire_starter - the item being used to ignite the candle.
 * * mob/user - the user to display a message to.
 * * quiet - suppresses the to_chat message.
 * * silent - suppresses the balloon alerts as well as the to_chat message.
 */
/obj/item/flashlight/flare/candle/proc/try_light_candle(obj/item/fire_starter, mob/user, quiet, silent)
	if(!istype(fire_starter))
		return
	if(!istype(user))
		return

	var/success_msg = fire_starter.ignition_effect(src, user)
	var/ignition_result

	if(success_msg)
		ignition_result = ignition()

	switch(ignition_result)
		if(SUCCESS)
			update_appearance(UPDATE_ICON | UPDATE_NAME)
			if(!quiet && !silent)
				user.visible_message(success_msg)
			return SUCCESS
		if(ALREADY_LIT)
			if(!silent)
				balloon_alert(user, "already lit!")
			return ALREADY_LIT
		if(NO_FUEL)
			if(!silent)
				balloon_alert(user, "out of fuel!")
			return NO_FUEL

/// allows lighting an unlit candle from some fire source by left clicking the candle with the source
/obj/item/flashlight/flare/candle/attackby(obj/item/attacking_item, mob/user, params)
	if(try_light_candle(attacking_item, user, silent = istype(attacking_item, src.type))) // so we don't double balloon alerts when a candle is used to light another candle
		return COMPONENT_CANCEL_ATTACK_CHAIN
	else
		return ..()

// allows lighting an unlit candle from some fire source by left clicking the source with the candle
/obj/item/flashlight/flare/candle/pre_attack(atom/target, mob/living/user, params)
	if(ismob(target))
		return ..()

	if(try_light_candle(target, user, quiet = TRUE))
		return COMPONENT_CANCEL_ATTACK_CHAIN

	return ..()

/obj/item/flashlight/flare/candle/attack_self(mob/user)
	if(on && (fuel != INFINITY || !can_be_extinguished)) // can't extinguish eternal candles
		turn_off()
		user.visible_message(span_notice("[user] snuffs [src]."))

/obj/item/flashlight/flare/candle/process(seconds_per_tick)
	. = ..()

	if(scented_type)
		var/turf/my_turf = get_turf(src)
		my_turf.pollute_turf(scented_type, 5)

	check_wax_level()

/obj/item/flashlight/flare/candle/infinite
	name = "eternal candle"
	fuel = INFINITY
	on = TRUE
	randomize_fuel = FALSE
	can_be_extinguished = FALSE

/obj/item/flashlight/flare/torch
	name = "torch"
	desc = "A torch fashioned from some leaves and a log."
	light_outer_range = 4
	icon_state = "torch"
	inhand_icon_state = "torch"
	lefthand_file = 'icons/mob/inhands/items_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items_righthand.dmi'
	light_color = LIGHT_COLOR_ORANGE
	on_damage = 10
	slot_flags = null
	trash_type = /obj/effect/decal/cleanable/ash
	can_be_extinguished = TRUE

/obj/item/flashlight/lantern
	name = "lantern"
	icon_state = "lantern"
	inhand_icon_state = "lantern"
	lefthand_file = 'icons/mob/inhands/equipment/mining_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/mining_righthand.dmi'
	desc = "A mining lantern."
	light_outer_range = 6 // luminosity when on
	light_system = OVERLAY_LIGHT

/obj/item/flashlight/lantern/heirloom_moth
	name = "old lantern"
	desc = "An old lantern that has seen plenty of use."
	light_outer_range = 4

/obj/item/flashlight/lantern/syndicate
	name = "suspicious lantern"
	desc = "A suspicious looking lantern."
	icon_state = "syndilantern"
	inhand_icon_state = "syndilantern"
	light_outer_range = 10

/obj/item/flashlight/lantern/jade
	name = "jade lantern"
	desc = "An ornate, green lantern."
	color = LIGHT_COLOR_GREEN
	light_color = LIGHT_COLOR_GREEN

/obj/item/flashlight/slime
	gender = PLURAL
	name = "glowing slime extract"
	desc = "Extract from a yellow slime. It emits a strong light when squeezed."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "slime"
	inhand_icon_state = null
	w_class = WEIGHT_CLASS_SMALL
	slot_flags = ITEM_SLOT_BELT
	custom_materials = null
	light_outer_range = 7 //luminosity when on
	light_system = OVERLAY_LIGHT

/obj/item/flashlight/emp
	var/emp_max_charges = 4
	var/emp_cur_charges = 4
	var/charge_timer = 0
	/// How many seconds between each recharge
	var/charge_delay = 20

/obj/item/flashlight/emp/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/item/flashlight/emp/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/item/flashlight/emp/process(seconds_per_tick)
	charge_timer += seconds_per_tick
	if(charge_timer < charge_delay)
		return FALSE
	charge_timer -= charge_delay
	emp_cur_charges = min(emp_cur_charges+1, emp_max_charges)
	return TRUE

/obj/item/flashlight/emp/attack(mob/living/M, mob/living/user)
	if(on && (user.zone_selected in list(BODY_ZONE_PRECISE_EYES, BODY_ZONE_PRECISE_MOUTH))) // call original attack when examining organs
		..()
	return

/obj/item/flashlight/emp/afterattack(atom/movable/A, mob/user, proximity)
	. = ..()
	if(!proximity)
		return

	if(emp_cur_charges > 0)
		emp_cur_charges -= 1

		if(ismob(A))
			var/mob/M = A
			log_combat(user, M, "attacked", "EMP-light")
			M.visible_message(span_danger("[user] blinks \the [src] at \the [A]."), \
								span_userdanger("[user] blinks \the [src] at you."))
		else
			A.visible_message(span_danger("[user] blinks \the [src] at \the [A]."))
		to_chat(user, span_notice("\The [src] now has [emp_cur_charges] charge\s."))
		A.emp_act(EMP_HEAVY)
	else
		to_chat(user, span_warning("\The [src] needs time to recharge!"))
	return

/obj/item/flashlight/emp/debug //for testing emp_act()
	name = "debug EMP flashlight"
	emp_max_charges = 100
	emp_cur_charges = 100

// Glowsticks, in the uncomfortable range of similar to flares,
// but not similar enough to make it worth a refactor
/obj/item/flashlight/glowstick
	name = "glowstick"
	desc = "A military-grade glowstick."
	custom_price = PAYCHECK_LOWER
	w_class = WEIGHT_CLASS_SMALL
	light_outer_range = 4
	light_system = OVERLAY_LIGHT
	color = LIGHT_COLOR_GREEN
	icon_state = "glowstick"
	base_icon_state = "glowstick"
	inhand_icon_state = null
	worn_icon_state = "lightstick"
	grind_results = list(/datum/reagent/phenol = 15, /datum/reagent/hydrogen = 10, /datum/reagent/oxygen = 5) //Meth-in-a-stick
	sound_on = 'sound/effects/wounds/crack2.ogg' // the cracking sound isn't just for wounds silly
	toggle_context = FALSE
	/// How many seconds of fuel we have left
	var/fuel = 0

/obj/item/flashlight/glowstick/Initialize(mapload)
	fuel = rand(50 MINUTES, 60 MINUTES)
	set_light_color(color)
	return ..()

/obj/item/flashlight/glowstick/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/item/flashlight/glowstick/process(seconds_per_tick)
	fuel = max(fuel - seconds_per_tick * (1 SECONDS), 0)
	if(fuel <= 0)
		turn_off()
		STOP_PROCESSING(SSobj, src)

/obj/item/flashlight/glowstick/proc/turn_off()
	on = FALSE
	update_appearance(UPDATE_ICON)

/obj/item/flashlight/glowstick/update_appearance(updates=ALL)
	. = ..()
	if(fuel <= 0)
		set_light_on(FALSE)
		return
	if(on)
		set_light_on(TRUE)
		return

/obj/item/flashlight/glowstick/update_icon_state()
	icon_state = "[base_icon_state][(fuel <= 0) ? "-empty" : ""]"
	inhand_icon_state = "[base_icon_state][((fuel > 0) && on) ? "-on" : ""]"
	return ..()

/obj/item/flashlight/glowstick/update_overlays()
	. = ..()
	if(fuel <= 0 && !on)
		return

	var/mutable_appearance/glowstick_overlay = mutable_appearance(icon, "glowstick-glow")
	glowstick_overlay.color = color
	. += glowstick_overlay

/obj/item/flashlight/glowstick/attack_self(mob/user)
	if(fuel <= 0)
		balloon_alert(user, "glowstick is spent!")
		return
	if(on)
		balloon_alert(user, "already lit!")
		return

	. = ..()
	if(.)
		user.visible_message(span_notice("[user] cracks and shakes [src]."), span_notice("You crack and shake [src], turning it on!"))
		START_PROCESSING(SSobj, src)

/obj/item/flashlight/glowstick/suicide_act(mob/living/carbon/human/user)
	if(!fuel)
		user.visible_message(span_suicide("[user] is trying to squirt [src]'s fluids into [user.p_their()] eyes... but it's empty!"))
		return SHAME
	var/obj/item/organ/internal/eyes/eyes = user.get_organ_slot(ORGAN_SLOT_EYES)
	if(!eyes)
		user.visible_message(span_suicide("[user] is trying to squirt [src]'s fluids into [user.p_their()] eyes... but [user.p_they()] don't have any!"))
		return SHAME
	user.visible_message(span_suicide("[user] is squirting [src]'s fluids into [user.p_their()] eyes! It looks like [user.p_theyre()] trying to commit suicide!"))
	fuel = 0
	return FIRELOSS

/obj/item/flashlight/glowstick/red
	name = "red glowstick"
	color = COLOR_SOFT_RED

/obj/item/flashlight/glowstick/blue
	name = "blue glowstick"
	color = LIGHT_COLOR_BLUE

/obj/item/flashlight/glowstick/cyan
	name = "cyan glowstick"
	color = LIGHT_COLOR_CYAN

/obj/item/flashlight/glowstick/orange
	name = "orange glowstick"
	color = LIGHT_COLOR_ORANGE

/obj/item/flashlight/glowstick/yellow
	name = "yellow glowstick"
	color = LIGHT_COLOR_DIM_YELLOW

/obj/item/flashlight/glowstick/pink
	name = "pink glowstick"
	color = LIGHT_COLOR_PINK

/obj/item/flashlight/spotlight //invisible lighting source
	name = "disco light"
	desc = "Groovy..."
	icon_state = null
	light_system = OVERLAY_LIGHT
	light_outer_range = 4
	light_power = 10
	alpha = 0
	plane = FLOOR_PLANE
	on = TRUE
	anchored = TRUE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	///Boolean that switches when a full color flip ends, so the light can appear in all colors.
	var/even_cycle = FALSE
	///Base light_range that can be set on Initialize to use in smooth light range expansions and contractions.
	var/base_light_outer_range = 4

/obj/item/flashlight/spotlight/Initialize(mapload, _light_range, _light_power, _light_color)
	. = ..()
	if(!isnull(_light_range))
		base_light_outer_range = _light_range
		set_light_range(_light_range)
	if(!isnull(_light_power))
		set_light_power(_light_power)
	if(!isnull(_light_color))
		set_light_color(_light_color)

/obj/item/flashlight/flashdark
	name = "flashdark"
	desc = "A strange device manufactured with mysterious elements that somehow emits darkness. Or maybe it just sucks in light? Nobody knows for sure."
	icon_state = "flashdark"
	inhand_icon_state = "flashdark"
	light_system = COMPLEX_LIGHT //The overlay light component is not yet ready to produce darkness.
	light_outer_range = 0
	///Variable to preserve old lighting behavior in flashlights, to handle darkness.
	var/dark_light_outer_range = 2.5
	///Variable to preserve old lighting behavior in flashlights, to handle darkness.
	var/dark_light_power = -3

/obj/item/flashlight/flashdark/update_brightness()
	. = ..()
	if(on)
		set_light(l_outer_range = dark_light_outer_range, l_power = dark_light_power)
	else
		set_light(0)

//type and subtypes spawned and used to give some eyes lights,
/obj/item/flashlight/eyelight
	name = "eyelight"
	desc = "This shouldn't exist outside of someone's head, how are you seeing this?"
	light_system = OVERLAY_LIGHT
	light_outer_range = 15
	light_power = 1
	flags_1 = CONDUCT_1
	item_flags = DROPDEL
	actions_types = list()

/obj/item/flashlight/eyelight/adapted
	name = "adaptedlight"
	desc = "There is no possible way for a player to see this, so I can safely talk at length about why this exists. Adapted eyes come \
	with icons that go above the lighting layer so to make sure the red eyes that pierce the darkness are always visible we make the \
	human emit the smallest amount of light possible. Thanks for reading :)"
	light_outer_range = 1
	light_power = 0.07

/obj/item/flashlight/eyelight/glow
	light_system = MOVABLE_LIGHT_BEAM
	light_outer_range = 4
	light_power = 2

#undef FAILURE
#undef SUCCESS
#undef NO_FUEL
#undef ALREADY_LIT
