class X2Condition_NotDualPistols extends X2Condition;

function bool CanEverBeValid(XComGameState_Unit SourceUnit, bool bStrategyCheck)
{
	return !class'LoadoutApiFactory'.static.GetLoadoutApi().HasDualPistolEquipped(SourceUnit);
}