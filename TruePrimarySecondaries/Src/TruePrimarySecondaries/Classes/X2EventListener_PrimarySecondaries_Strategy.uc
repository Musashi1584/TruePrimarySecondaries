class X2EventListener_PrimarySecondaries_Strategy extends X2EventListener;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateOverrideShowItemInLockerListListenerTemplate());
	Templates.AddItem(CreateSquaddieItemStateAppliedListenerTemplate());
	Templates.AddItem(CreateOnBestGearLoadoutAppliedListenerTemplate());

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

static function CHEventListenerTemplate CreateOnBestGearLoadoutAppliedListenerTemplate()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'PrimarySecondariesOnBestGearLoadoutAppliedListener');

	Template.RegisterInTactical = false;
	Template.RegisterInStrategy = true;

	Template.AddCHEvent('OnBestGearLoadoutApplied', OnOnBestGearLoadoutApplied, ELD_OnStateSubmitted);
	`LOG("Register Event OnBestGearLoadoutApplied", class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');

	return Template;
}

static function EventListenerReturn OnOverrideShowItemInLockerList(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_Item ItemState;
	local XComGameState_Unit UnitState;
	local LoadoutApiInterface LoadoutApi;
	local XComLWTuple Tuple;
	local EInventorySlot Slot;

	Tuple = XComLWTuple(EventData);
	ItemState = XComGameState_Item(EventSource);
	LoadoutApi = class'LoadoutApiFactory'.static.GetLoadoutApi();

	Slot = EInventorySlot(Tuple.Data[1].i);
	UnitState = XComGameState_Unit(Tuple.Data[2].o);

	if (Slot != eInvSlot_PrimaryWeapon)
	{
		return ELR_NoInterrupt;
	}

	if ((LoadoutApi.IsSecondaryPistolItem(ItemState, true) ||
		LoadoutApi.IsSecondaryMeleeItem(ItemState, true)) &&
		class'X2DownloadableContentInfo_TruePrimarySecondaries'.static.IsWeaponAllowedByClass(
			UnitState.GetSoldierClassTemplate(),
			X2WeaponTemplate(ItemState.GetMyTemplate()),
			Slot)
	)
	{
		`LOG(GetFuncName() @ "allow" @ ItemState.GetMyTemplateName() @ X2WeaponTemplate(ItemState.GetMyTemplate()).WeaponCat, class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
		Tuple.Data[0].b = true;
		EventData = Tuple;
	}
	
	`LOG(GetFuncName() @ "ignore" @ ItemState.GetMyTemplateName(), class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnSquaddieItemStateApplied(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
}

static function EventListenerReturn OnOnBestGearLoadoutApplied(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
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
	local array<X2WeaponTemplate> BestPrimaryWeaponTemplates;

	UnitState = XComGameState_Unit(EventData);

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
	
		if (class'Helper'.static.IsPrimarySecondaryTemplate(WeaponTemplate, eInvSlot_PrimaryWeapon))
		{
			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("TruePrimarySecondaries SquaddieItemStateApplied");
			UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));

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

			UnitState.bIgnoreItemEquipRestrictions = true;
			if (UnitState.AddItemToInventory(ItemState, eInvSlot_PrimaryWeapon, NewGameState))
			{
				`LOG(GetFuncName() @ "Added new item to inventory" @ ItemState.GetMyTemplateName(), class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
			}
			else
			{
				`LOG(GetFuncName() @ "Unable to add new item to inventory. Squaddie loadout will be affected." @ ItemState.GetMyTemplateName(), class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
			}
			UnitState.bIgnoreItemEquipRestrictions = false;

			BestPrimaryWeaponTemplates = GetBestPrimaryWeaponTemplates(WeaponTemplate);
			UnitState.UpgradeEquipment(NewGameState, ItemState, BestPrimaryWeaponTemplates, eInvSlot_PrimaryWeapon);

			if (NewGameState.GetNumGameStateObjects() > 0)
			{
				`LOG(GetFuncName() @ "Submitting Game State", class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
				`GAMERULES.SubmitGameState(NewGameState);
			}
			else
			{
				`LOG(GetFuncName() @ "CleanupPendingGameState", class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
				`XCOMHISTORY.CleanupPendingGameState(NewGameState);
			}
		}
	}

	
	return ELR_NoInterrupt;

}

static function array<X2WeaponTemplate> GetBestPrimaryWeaponTemplates(
	X2WeaponTemplate DefaultLoadoutWeapon
)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersXCom XComHQ;
	local X2WeaponTemplate WeaponTemplate, BestWeaponTemplate;
	local array<X2WeaponTemplate> BestWeaponTemplates;
	local XComGameState_Item ItemState;
	local int idx, HighestTier;

	History = `XCOMHISTORY;
	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ();

	BestWeaponTemplate = DefaultLoadoutWeapon;
	BestWeaponTemplates.AddItem(BestWeaponTemplate);
	HighestTier = BestWeaponTemplate.Tier;

	if( XComHQ != none )
	{
		// Try to find a better primary weapon as an infinite item in the inventory
		for (idx = 0; idx < XComHQ.Inventory.Length; idx++)
		{
			ItemState = XComGameState_Item(History.GetGameStateForObjectID(XComHQ.Inventory[idx].ObjectID));
			WeaponTemplate = X2WeaponTemplate(ItemState.GetMyTemplate());

			if (WeaponTemplate != none && WeaponTemplate.bInfiniteItem && (BestWeaponTemplate == none || (BestWeaponTemplates.Find(WeaponTemplate) == INDEX_NONE && WeaponTemplate.Tier >= BestWeaponTemplate.Tier)) && 
				WeaponTemplate.WeaponCat == DefaultLoadoutWeapon.WeaponCat)
			{
				BestWeaponTemplate = WeaponTemplate;
				BestWeaponTemplates.AddItem(BestWeaponTemplate);
				HighestTier = BestWeaponTemplate.Tier;
			}
		}
	}

	for(idx = 0; idx < BestWeaponTemplates.Length; idx++)
	{
		if(BestWeaponTemplates[idx].Tier < HighestTier)
		{
			BestWeaponTemplates.Remove(idx, 1);
			idx--;
		}
	}

	return BestWeaponTemplates;
}