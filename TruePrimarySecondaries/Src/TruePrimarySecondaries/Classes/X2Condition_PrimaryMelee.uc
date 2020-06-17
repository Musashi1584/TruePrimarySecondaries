class X2Condition_PrimaryMelee extends X2Condition;

event name CallMeetsConditionWithSource(XComGameState_BaseObject kTarget, XComGameState_BaseObject kSource)
{
	local XComGameState_Unit SourceUnit;

	SourceUnit = XComGameState_Unit(kSource);

	if (class'LoadoutApiFactory'.static.GetLoadoutApi().HasPrimaryMeleeEquipped(SourceUnit))
	{
		return 'AA_Success';
	}

	return 'AA_WeaponIncompatible';
}

function bool CanEverBeValid(XComGameState_Unit SourceUnit, bool bStrategyCheck)
{
	return class'LoadoutApiFactory'.static.GetLoadoutApi().HasPrimaryMeleeEquipped(SourceUnit) && SourceUnit.IsSoldier();
}