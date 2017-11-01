// the underfloor wiring terminal for the APC
// autogenerated when an APC is placed
// all conduit connects go to this object instead of the APC
// using this solves the problem of having the APC in a wall yet also inside an area

/obj/machinery/power/terminal
	name = "terminal"
	icon_state = "term"
	desc = "It's an underfloor wiring terminal for power equipment."
	level = 1
	layer = TURF_LAYER
	var/obj/machinery/power/master = null
	anchored = 1
	layer = 2.6 // a bit above wires


/obj/machinery/power/terminal/New()
	..()
	var/turf/T = src.loc
	if(!T)
		return
	if(level==1) hide(T.intact)
	return
	
/obj/machinery/power/terminal/Destroy()
	if(master)
		master.disconnect_terminal()
	return ..()


/obj/machinery/power/terminal/hide(var/i)
	if(i)
		invisibility = 101
		icon_state = "term-f"
	else
		invisibility = 0
		icon_state = "term"

/obj/machinery/power/terminal/connect_to_network()
	var/turf/T = src.loc
	if(!T || !istype(T))
		return 0
	for(var/obj/structure/cable/C in T.contents) //check if we have a node cable on the machine turf, the first found is picked
		if(!C || !C.powernet)
			continue
		C.powernet.add_machine(src)
		break
	return 1