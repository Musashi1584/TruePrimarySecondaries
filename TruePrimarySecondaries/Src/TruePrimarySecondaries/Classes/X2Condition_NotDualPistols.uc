class X2Condition_NotDualPistols extends X2Condition;

function bool CanEverBeValid(XComGameState_Unit SourceUnit, bool bStrategyCheck)
{
	return !class'X2DownloadableContentInfo_TruePrimarySecondaries'.static.HasDualPistolEquipped(SourceUnit);
}