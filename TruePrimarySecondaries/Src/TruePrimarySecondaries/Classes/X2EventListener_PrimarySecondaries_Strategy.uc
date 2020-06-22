class X2EventListener_PrimarySecondaries_Strategy extends X2EventListener;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateOverrideShowItemInLockerListListenerTemplate());
	Templates.AddItem(CreateSquaddieItemStateAppliedListenerTemplate());
	
	return Templates;
}

static function CHEventListenerTemplate CreateOverrideShowItemInLockerListListenerTemplate()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'PrimarySecondariesShowItemInLockerListListener');

	Template.RegisterInTactical = false;
	Template.RegisterInStrategy = true;

	Template.AddCHEvent('OverrideShowItemInLockerList', OnOverrideShowItemInLockerList, ELD_Immediate);
	`LOG("Register Event ShowItemInLockerList", class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');

	return Template;
}

static function CHEventListenerTemplate CreateSquaddieItemStateAppliedListenerTemplate()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'PrimarySecondariesSquaddieItemStateAppliedListener');

	Template.RegisterInTactical = false;
	Template.RegisterInStrategy = true;

	Template.AddCHEvent('SquaddieItemStateApplied', OnSquaddieItemStateApplied, ELD_OnStateSubmitted);
	`LOG("Register Event SquaddieItemStateApplied", class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');

	return Template;
}

static function EventListenerReturn OnOverrideShowItemInLockerList(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_Item ItemState;
	local LoadoutApiInterface LoadoutApi;
	local XComLWTuple Tuple;
	local EInventorySlot Slot;

	Tuple = XComLWTuple(EventData);
	ItemState = XComGameState_Item(EventSource);
	LoadoutApi = class'LoadoutApiFactory'.static.GetLoadoutApi();

	Slot = EInventorySlot(Tuple.Data[1].i);

	`LOG(GetFuncName() @ Slot @ ItemState.GetMyTemplateName() @ ItemState.Quantity, class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');

	if (Slot != eInvSlot_PrimaryWeapon)
	{
		return ELR_NoInterrupt;
	}

	//if (class'LoadoutApiLib'.static.IsSecondaryPistolItem(ItemState, true) ||
	//	class'LoadoutApiLib'.static.IsSecondaryMeleeItem(ItemState, true)
	if (LoadoutApi.IsSecondaryPistolItem(ItemState, true) ||
		LoadoutApi.IsSecondaryMeleeItem(ItemState, true)
	)
	{
		`LOG(GetFuncName() @ "allow" @ ItemState.GetMyTemplateName(), class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
		Tuple.Data[0].b = true;
		EventData = Tuple;
	}
	
	return ELR_NoInterrupt;
}

static function EventListenerReturn OnSquaddieItemStateApplied(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState NewGameState;
	local XComGameState_Item ItemState;
	local XComGameState_Unit UnitState;
	local X2ItemTemplateManager ItemTemplateMan;
	local X2EquipmentTemplate ItemTemplate;
	local X2WeaponTemplate WeaponTemplate;
	local InventoryLoadout Loadout;
	local name SquaddieLoadout;
	local bool bFoundLoadout;
	local int Index;
	local string ItemTemplateName;

	ItemState = XComGameState_Item(EventData);
	UnitState = XComGameState_Unit(EventSource);

	// We assume the secondary weapon worked and hook in here, ignore all other slots
	if (ItemState.InventorySlot != eInvSlot_SecondaryWeapon)
	{
		return ELR_NoInterrupt;
	}

	SquaddieLoadout = UnitState.GetSoldierClassTemplate().SquaddieLoadout;
	ItemTemplateMan = class'X2ItemTemplateManager'.static.GetItemTemplateManager();

	foreach ItemTemplateMan.Loadouts(Loadout)
	{
		if (Loadout.LoadoutName == SquaddieLoadout)
		{
			bFoundLoadout = true;
			break;
		}
	}
	if (!bFoundLoadout)
	{
		return ELR_NoInterrupt;
	}

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("TruePrimarySecondaries SquaddieItemStateApplied");
	UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));

	for (Index = 0; Index < Loadout.Items.Length; Index++)
	{
		ItemTemplateName = string(Loadout.Items[Index].Item);
		if (!class'Helper'.static.HasAndReplacePrimarySuffix(ItemTemplateName))
		{
			continue;
		}

		ItemTemplate = X2EquipmentTemplate(ItemTemplateMan.FindItemTemplate(name(ItemTemplateName)));
		if (ItemTemplate == none)
		{
			continue;
		}
	
		WeaponTemplate = X2WeaponTemplate(ItemTemplate);
		if (WeaponTemplate == none)
		{
			continue;
		}
	
		if (class'Helper'.static.IsPrimarySecondaryTemplate(WeaponTemplate))
		{
			
			//  If there is an item occupying the slot remove it.
			ItemState = UnitState.GetItemInSlot(eInvSlot_PrimaryWeapon, NewGameState);

			if (ItemState != none)
			{
				if (ItemState.GetMyTemplateName() == ItemTemplate.DataName)
				{
					continue;
				}
				if (!UnitState.RemoveItemFromInventory(ItemState, NewGameState))
				{
					`LOG(GetFuncName() @ "Unable to remove item from inventory. Squaddie loadout will be affected." @ ItemState.ToString(), class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
					continue;
				}
			}
			if (!UnitState.CanAddItemToInventory(ItemTemplate, eInvSlot_PrimaryWeapon, NewGameState))
			{
				`LOG(GetFuncName() @ "Unable to add new item to inventory. Squaddie loadout will be affected." @ ItemTemplate.DataName, class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
				continue;
			}

			ItemState = ItemTemplate.CreateInstanceFromTemplate(NewGameState);

			//Transfer settings that were configured in the character pool with respect to the weapon. Should only be applied here
			//where we are handing out generic weapons.
			if (ItemTemplate.InventorySlot == eInvSlot_PrimaryWeapon || ItemTemplate.InventorySlot == eInvSlot_SecondaryWeapon ||
				ItemTemplate.InventorySlot == eInvSlot_TertiaryWeapon)
			{
				WeaponTemplate = X2WeaponTemplate(ItemState.GetMyTemplate());
				if (WeaponTemplate != none && WeaponTemplate.bUseArmorAppearance)
				{
					ItemState.WeaponAppearance.iWeaponTint = UnitState.kAppearance.iArmorTint;
				}
				else
				{
					ItemState.WeaponAppearance.iWeaponTint = UnitState.kAppearance.iWeaponTint;
				}
				ItemState.WeaponAppearance.nmWeaponPattern = UnitState.kAppearance.nmWeaponPattern;
			}

			if (!UnitState.AddItemToInventory(ItemState, eInvSlot_PrimaryWeapon, NewGameState))
			{
				`LOG(GetFuncName() @ "Added new item to inventory" @ ItemState.GetMyTemplateName(), class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
			}
			else
			{
				`LOG(GetFuncName() @ "Unable to add new item to inventory. Squaddie loadout will be affected." @ ItemState.GetMyTemplateName(), class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
			}

			
		}
	}

	if (NewGameState.GetNumGameStateObjects() > 0)
	{
		`LOG(default.class @ GetFuncName() @ "Submitting Game State", class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
		`GAMERULES.SubmitGameState(NewGameState);
	}
	else
	{
		`XCOMHISTORY.CleanupPendingGameState(NewGameState);
	}
	return ELR_NoInterrupt;
}