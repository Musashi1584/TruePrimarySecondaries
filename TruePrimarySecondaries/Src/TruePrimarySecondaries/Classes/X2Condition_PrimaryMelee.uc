class X2Condition_PrimaryMelee extends X2Condition;

event name CallMeetsConditionWithSource(XComGameState_BaseObject kTarget, XComGameState_BaseObject kSource)
{
	local XComGameState_Unit SourceUnit;

	SourceUnit = XComGameState_Unit(kSource);

	if (class'X2DownloadableContentInfo_TruePrimarySecondaries'.static.HasPrimaryMeleeEquipped(SourceUnit))
	{
		return 'AA_Success';
	}

	return 'AA_WeaponIncompatible';
}

function bool CanEverBeValid(XComGameState_Unit SourceUnit, bool bStrategyCheck)
{
	return class'X2DownloadableContentInfo_TruePrimarySecondaries'.static.HasPrimaryMeleeEquipped(SourceUnit) && SourceUnit.IsSoldier();
}