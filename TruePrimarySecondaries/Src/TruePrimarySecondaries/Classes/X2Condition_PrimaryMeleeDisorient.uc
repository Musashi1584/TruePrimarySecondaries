class X2Condition_PrimaryMeleeDisorient extends X2Condition_UnitEffects;

//	This condition will behave exactly as the regular condition that gets added to the ability template by Template.AddShooterExclusions(), with one exception:
//	The condition will fail if the ability is NOT attached to a primary melee weapon AND the owner unit is disoriented.

event name CallAbilityMeetsCondition(XComGameState_Ability kAbility, XComGameState_BaseObject kTarget) 
{
	local XComGameState_Item	SourceWeapon;
	local XComGameState_Unit	UnitState;
	
	SourceWeapon = kAbility.GetSourceWeapon();

	//	If this ability is NOT attached to a primary melee weapon
	if (SourceWeapon == none || !class'LoadoutApiFactory'.static.GetLoadoutApi().IsPrimaryMeleeItem(SourceWeapon))
	{ 
		//	Have to get Owner Unit from the Ability State, `kTarget` is not relevant here.
		UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(kAbility.OwnerStateObject.ObjectID));
		if (UnitState != none && UnitState.IsUnitAffectedByEffectName(class'X2AbilityTemplateManager'.default.DisorientedName) )
		{
			return 'AA_UnitIsDisoriented';
		}
	}
	return 'AA_Success'; 
}