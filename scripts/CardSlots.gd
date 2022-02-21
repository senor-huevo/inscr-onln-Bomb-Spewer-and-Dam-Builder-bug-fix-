extends VBoxContainer


onready var playerSlots = $PlayerSlots.get_children()
onready var enemySlots = $EnemySlots.get_children()
onready var fightManager = get_node("/root/Main/CardFight")
onready var handManager = fightManager.get_node("HandsContainer/Hands")
onready var allCards = get_node("/root/Main/AllCards")

# Cards selected for sacrifice
var sacVictims = []


# Board interactions
func clear_slots():
	for slot in playerSlots:
		if slot.get_child_count() > 0:
			slot.get_child(0).queue_free()
	for slot in enemySlots:
		if slot.get_child_count() > 0:
			slot.get_child(0).queue_free()


# Sacrifice
func get_available_blood() -> int:
	var blood = 0
	
	for slot in playerSlots:
		if slot.get_child_count() > 0:
			blood += 1
	
	return blood

func clear_sacrifices():
	for victim in sacVictims:
		victim.get_node("CardBody/SacOlay").visible = false
		rpc_id(fightManager.opponent, "set_sac_olay_vis", victim.get_parent().get_position_in_parent(), false)
	
	sacVictims.clear()

func is_sacrifice_possible(card_to_summon):
	if get_available_blood() < card_to_summon.card_data["blood_cost"]:
		return false

func attempt_sacrifice():
	if len(sacVictims) >= handManager.raisedCard.card_data["blood_cost"]:
		# Kill sacrifical victims
		for victim in sacVictims:
			victim.get_node("AnimationPlayer").play("Sacrifice")
			rpc_id(fightManager.opponent, "remote_card_anim", victim.get_parent().get_position_in_parent(), "Sacrifice")
			fightManager.add_bones(1)
			
			# SIGILS
			## Unkillable
			if "Unkillable" in victim.card_data["sigils"]:
				fightManager.draw_card(allCards.all_cards.find(victim.card_data))
			
		sacVictims.clear()
		
		# Force player to summon the new card
		fightManager.state = fightManager.GameStates.FORCEPLAY

# Combat
func initiate_combat():
	for slot in playerSlots:
		if slot.get_child_count() > 0 and slot.get_child(0).attack > 0:
			
			# Regular attack
			var cardAnim = slot.get_child(0).get_node("AnimationPlayer")
			cardAnim.play("Attack")
			rpc_id(fightManager.opponent, "remote_card_anim", slot.get_position_in_parent(), "AttackRemote")
			yield(cardAnim, "animation_finished")
		
	fightManager.end_turn()


# Do the attack damage
func handle_attack(slot_index):
	var direct_attack = false
	
	var pCard = playerSlots[slot_index].get_child(0)
	var eCard = null
	
	if enemySlots[slot_index].get_child_count() == 0:
		direct_attack = true
	else:
		eCard = enemySlots[slot_index].get_child(0)
		if "Airborne" in pCard.card_data["sigils"] and not "Mighty Leap" in eCard.card_data["sigils"]:
			direct_attack = true
	
	if direct_attack:
		fightManager.inflict_damage(pCard.attack)
	else:
		eCard.health -= pCard.attack
		eCard.draw_stats()
		if eCard.health <= 0 or "Touch of Death" in pCard.card_data["sigils"]:
			eCard.get_node("AnimationPlayer").play("Perish")
			fightManager.add_opponent_bones(1)
	
	rpc_id(fightManager.opponent, "handle_enemy_attack", slot_index)

# Sigil handling
func has_friendly_sigil(sigil):
	for slot in playerSlots:
		if slot.get_child_count() > 0:
			if sigil in slot.get_child(0).card_data["sigils"]:
				return true
	
	return false

# Remote
remote func set_sac_olay_vis(slot, vis):
	enemySlots[slot].get_child(0).get_node("CardBody/SacOlay").visible = vis


remote func remote_card_anim(slot, anim_name):
	enemySlots[slot].get_child(0).get_node("AnimationPlayer").play(anim_name)
	
	if anim_name in ["Perish", "Sacrifice"]:
		fightManager.add_opponent_bones(1)
	
remote func handle_enemy_attack(slot_index):
	
	# Is there an opposing card to attack?
	if playerSlots[slot_index].get_child_count() > 0:
		var pCard = playerSlots[slot_index].get_child(0)
		var eCard = enemySlots[slot_index].get_child(0)
		pCard.health -= eCard.attack
		pCard.draw_stats()
		if pCard.health <= 0 or "Touch of Death" in eCard.card_data["sigils"]:
			pCard.get_node("AnimationPlayer").play("Perish")
			fightManager.add_bones(1)
			
			## SIGILS
			# Unkillable
			if "Unkillable" in pCard.card_data["sigils"]:
				fightManager.draw_card(allCards.all_cards.find(pCard.card_data))
		
	else:
		var dmg = enemySlots[slot_index].get_child(0).attack
		fightManager.inflict_damage(-dmg)
		
