class_name Shopping
extends RefCounted
## Buying second-hand clothes and changing your hair at Waschsalon Blitz (T-0073; static, no
## state).


## True when the person stands on a use slot of an object tagged `tag` whose lot is open now
## (objects on no lot count as open).
static func at_open(sim: Sim, person: Person, tag: String) -> bool:
	var here := person.cell()
	for id: int in sim.world.objects_tagged(tag):
		var obj: WorldObject = sim.world.objects[id]
		var lot := Lots.lot_at(sim, obj.origin)
		if lot != null and not Lots.is_open(lot, sim.clock):
			continue
		for slot: int in obj.slot_count(sim.content):
			if obj.slot_cell(sim.content, slot) == here:
				return true
	return false


## Buys `clothing_id` in `colour` for its catalog price (Money.spend: cash, then the bank;
## "purchase") into
## their wardrobe: "" when bought, else not_at_shop | unknown | owned | cant_afford.
static func buy_clothes(sim: Sim, person: Person, clothing_id: String, colour: String) -> String:
	if not at_open(sim, person, "clothes_rack"):
		return "not_at_shop"
	var def := sim.content.clothing_def(clothing_id)
	if def == null or not def.colours.has(colour):
		return "unknown"
	if Wardrobe.owns(person, clothing_id, colour):
		return "owned"
	if not Money.spend(sim, person, def.price, "purchase", clothing_id):
		return "cant_afford"
	Wardrobe.add(person, clothing_id, colour)
	return ""


## The new hair: "" when done, else not_at_barber | unknown (a style or colour the catalog
## doesn't have). The cut itself is paid by the get_haircut interaction.
static func change_hair(sim: Sim, person: Person, style: String, colour: String) -> String:
	if not at_open(sim, person, "barber_chair"):
		return "not_at_barber"
	if not sim.content.appearance.hair_styles.has(style) or not sim.content.appearance.hair_colours.has(colour):
		return "unknown"
	person.appearance.hair_style = style
	person.appearance.hair_colour = colour
	return ""
