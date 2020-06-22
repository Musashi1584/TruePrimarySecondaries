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

static function bool IsPrimarySecondaryTemplate(X2WeaponTemplate WeaponTemplate, optional EInventorySlot InventorySlot = eInvSlot_PrimaryWeapon)
{
	local LoadoutApiInterface LoadoutApi;

	if (WeaponTemplate == none)
	{
		return false;
	}

	LoadoutApi = class'LoadoutApiFactory'.static.GetLoadoutApi();

	return InventorySlot == eInvSlot_PrimaryWeapon && (LoadoutApi.IsMeleeWeaponTemplate(WeaponTemplate) || LoadoutApi.IsPistolWeaponTemplate(WeaponTemplate));
}

static function bool HasAndReplacePrimarySuffix(out coerce string TemplateName)
{
	if (InStr(TemplateName, "_Primary") != INDEX_NONE)
	{
		TemplateName = Repl(TemplateName, "_Primary", "");
		return true;
	}
	return false;
}

static function bool ShouldLog()
{
	return class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog;
}

static function bool ShouldLogAnimations()
{
	return class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLogAnimations;
}