//-----------------------------------------------------------
//	Class:	Helper
//	Author: Musashi
//	
//-----------------------------------------------------------


class Helper extends Object;

static function bool TriggerShowItemInLockerList(
	XComGameState_Item ItemState,
	EInventorySlot InventorySlot,
	optional XComGameState_Unit UnitState = none,
	optional XComGameState CheckGameState = none
)
{
	local XComLWTuple Tuple;

	Tuple = new class'XComLWTuple';
	Tuple.Id = 'OverrideShowItemInLockerList';
	Tuple.Data.Add(3);
	Tuple.Data[0].kind = XComLWTVBool;
	Tuple.Data[0].b = false;
	Tuple.Data[1].kind = XComLWTVInt;
	Tuple.Data[1].i = InventorySlot;
	Tuple.Data[2].kind = XComLWTVObject;
	Tuple.Data[2].o = UnitState;

	`XEVENTMGR.TriggerEvent('OverrideShowItemInLockerList', Tuple, ItemState, CheckGameState);

	return Tuple.Data[0].b;
}

static function bool IsPrimarySecondaryTemplate(X2WeaponTemplate WeaponTemplate, EInventorySlot InventorySlot)
{
	if (WeaponTemplate == none)
	{
		return false;
	}

	return InventorySlot == eInvSlot_PrimaryWeapon &&
		(class'LoadoutApiFactory'.static.GetLoadoutApi().IsMeleeWeaponTemplate(WeaponTemplate) ||
		class'LoadoutApiFactory'.static.GetLoadoutApi().IsPistolWeaponTemplate(WeaponTemplate));
}