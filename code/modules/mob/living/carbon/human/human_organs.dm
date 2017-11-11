/mob/living/carbon/human/proc/update_eyes()
	var/obj/item/organ/internal/eyes/eyes = get_int_organ(/obj/item/organ/internal/eyes)
	if(eyes)
		eyes.update_colour()
		update_body()

/mob/living/carbon/human/var/list/organs = list()
/mob/living/carbon/human/var/list/organs_by_name = list() // map organ names to organs

// Takes care of organ related updates, such as broken and missing limbs
/mob/living/carbon/human/proc/handle_organs()

	number_wounds = 0
	var/force_process = 0
	var/damage_this_tick = getBruteLoss() + getFireLoss() + getToxLoss()
	if(damage_this_tick > last_dam)
		force_process = 1
	last_dam = damage_this_tick
	if(force_process)
		bad_external_organs.Cut()
		for(var/obj/item/organ/external/Ex in organs)
			bad_external_organs |= Ex

	//processing internal organs is pretty cheap, do that first.
	for(var/obj/item/organ/internal/I in internal_organs)
		I.process()

	//handle_stance()
	handle_grasp()
	handle_stance()

	if(!force_process && !bad_external_organs.len)
		return

	for(var/obj/item/organ/external/E in bad_external_organs)
		if(!E)
			continue
		if(!E.need_process())
			bad_external_organs -= E
			continue
		else
			E.process()
			number_wounds += E.number_wounds

			if(!lying && world.time - l_move_time < 15)
			//Moving around with fractured ribs won't do you any good
				if(E.is_broken() && E.internal_organs && E.internal_organs.len && prob(15))
					var/obj/item/organ/internal/I = pick(E.internal_organs)
					custom_pain("You feel broken bones moving in your [E.name]!", 1)
					I.take_damage(rand(3,5))

				//Moving makes open wounds get infected much faster
				if(E.wounds.len)
					for(var/datum/wound/W in E.wounds)
						if(W.infection_check())
							W.germ_level += 1


/mob/living/carbon/human/proc/handle_stance()
	// Don't need to process any of this if they aren't standing anyways
	// unless their stance is damaged, and we want to check if they should stay down
	if(!stance_damage && (lying || resting) && (life_tick % 4) == 0)
		return

	stance_damage = 0

	// Buckled to a bed/chair. Stance damage is forced to 0 since they're sitting on something solid
	if(istype(buckled, /obj/structure/stool/bed))
		return

	for(var/limb_tag in list("l_leg","r_leg","l_foot","r_foot"))
		var/obj/item/organ/external/E = organs_by_name[limb_tag]
		if(!E || (E.status & (ORGAN_DESTROYED|ORGAN_DEAD)) || E.is_malfunctioning())
			stance_damage += 8 // let it fail even if just foot&leg. Also malfunctioning happens sporadically so it should impact more when it procs
			// persistant edit here! if theres any wound thats so bad it cant heal naturally
		else //	if(E.is_broken() || !E.is_usable())
		//	stance_damage += 1
			for(var/datum/wound/W in E.wounds)
				if(!W.simpleheal && W.damage >= 30) // advanced wounds THAT DONT HEAL damage the stance
					stance_damage += 8
					if(W.is_treated())
						stance_damage -= 4
						if(W.surgery_treated)
							stance_damage -= 4
		
	// Canes and crutches help you stand (if the latter is ever added)
	// One cane mitigates a broken leg+foot, or a missing foot.
	// Two canes are needed for a lost leg. If you are missing both legs, canes aren't gonna help you.
	if(l_hand && istype(l_hand, /obj/item/weapon/cane))
		stance_damage -= 4
	if(r_hand && istype(r_hand, /obj/item/weapon/cane))
		stance_damage -= 4

	if(stance_damage < 0)
		stance_damage = 0

	// standing is poor
	if(stance_damage >= 8)
		if(!(lying || resting))
			if(species && !(species.flags & NO_PAIN))
				emote("scream")
				fall(1)
			custom_emote(1, "collapses!")
		Weaken(10) //can't emote while weakened, apparently.


/mob/living/carbon/human/proc/handle_grasp()

	if(!l_hand && !r_hand)
		return

	for(var/obj/item/organ/external/E in organs)
		if(!E || !E.can_grasp) // if(E.is_broken())
			continue

	//	if(E.is_broken())
		for(var/datum/wound/W in E.wounds)
			if(!W.simpleheal && W.damage >= 30) // advanced wounds THAT DONT HEAL damage the grasp
				if(W.is_treated())
					if(W.damage <= 40)
						continue
					if(W.surgery_treated)
						continue
				if((E.body_part == HAND_LEFT) || (E.body_part == ARM_LEFT))
					if(!l_hand)
						break
					unEquip(l_hand)
				else
					if(!r_hand)
						break
					unEquip(r_hand)

				var/emote_scream = pick("screams in pain and ", "lets out a sharp cry and ", "cries out and ")
				custom_emote(1, "[(species.flags & NO_PAIN) ? "" : emote_scream ]drops what they were holding in their [E.name]!")

		if(E.is_malfunctioning())

			if((E.body_part == HAND_LEFT) || (E.body_part == ARM_LEFT))
				if(!l_hand)
					continue
				unEquip(l_hand)
			else
				if(!r_hand)
					continue
				unEquip(r_hand)

			custom_emote(1, "drops what they were holding, their [E.name] malfunctioning!")

			var/datum/effect/system/spark_spread/spark_system = new /datum/effect/system/spark_spread()
			spark_system.set_up(5, 0, src)
			spark_system.attach(src)
			spark_system.start()
			spawn(10)
				qdel(spark_system)

//Handles chem traces
/mob/living/carbon/human/proc/handle_trace_chems()
	//New are added for reagents to random organs.
	for(var/datum/reagent/A in reagents.reagent_list)
		var/obj/item/organ/internal/O = pick(organs)
		O.trace_chemicals[A.name] = 100

/*
When assimilate is 1, organs that have a different UE will still have their DNA overriden by that of the host
Otherwise, this restricts itself to organs that share the UE of the host.

old_ue: Set this to a UE string, and this proc will overwrite the dna of organs that have that UE, instead of the host's present UE
*/
/mob/living/carbon/human/proc/sync_organ_dna(var/assimilate = 1, var/old_ue = null)
	var/ue_to_compare = (old_ue) ? old_ue : dna.unique_enzymes
	var/list/all_bits = internal_organs|organs
	for(var/obj/item/organ/O in all_bits)
		if(assimilate || !O.dna ||O.dna.unique_enzymes == ue_to_compare)
			O.set_dna(dna)

/*
Given the name of an organ, returns the external organ it's contained in
I use this to standardize shadowling dethrall code
-- Crazylemon
*/
/mob/living/carbon/human/proc/named_organ_parent(var/organ_name)
	if(!get_int_organ(organ_name))
		return null
	var/obj/item/organ/internal/O = get_int_organ(organ_name)
	return O.parent_organ