//-----------------------------------------------------------
//	Class:	UITacticalQuickLaunch_UnitSlot_PrimarySecondaries
//	Author: Musashi
//	
//-----------------------------------------------------------


class UITacticalQuickLaunch_UnitSlot_PrimarySecondaries extends UITacticalQuickLaunch_UnitSlot;

simulated function AddFullInventory(XComGameState GameState, XComGameState_Unit Unit)
{
	// Add inventory
	AddItemToUnit(GameState, Unit, m_nPrimaryWeaponTemplate, eInvSlot_PrimaryWeapon);
	AddItemToUnit(GameState, Unit, m_nSecondaryWeaponTemplate, eInvSlot_SecondaryWeapon);
	AddItemToUnit(GameState, Unit, m_nArmorTemplate);
	AddItemToUnit(GameState, Unit, m_nHeavyWeaponTemplate);
	AddItemToUnit(GameState, Unit, m_nGrenadeSlotTemplate, eInvSlot_GrenadePocket);
	AddItemToUnit(GameState, Unit, m_nUtilityItem1Template);
	AddItemToUnit(GameState, Unit, m_nUtilityItem2Template);
}

simulated function name PopulateItemDropdown(UIDropdown kDropdown, name nCurrentEquipped, EInventorySlot eEquipmentType)
{
	local X2SoldierClassTemplate kSoldierClassTemplate;
	local X2DataTemplate kEquipmentTemplate;
	local bool bFoundCurrent, bHaveNothing;

	kDropdown.Clear(); // empty dropdown

	kSoldierClassTemplate = class'X2SoldierClassTemplateManager'.static.GetSoldierClassTemplateManager().FindSoldierClassTemplate(m_nSoldierClassTemplate);

	if (eEquipmentType != eInvSlot_Armor && kSoldierClassTemplate != none)
	{
		bHaveNothing = true;
		kDropdown.AddItem("(nothing)");
		if (nCurrentEquipped == '')
			kDropdown.SetSelected(0);
	}	
	
	foreach class'X2ItemTemplateManager'.static.GetItemTemplateManager().IterateTemplates(kEquipmentTemplate, none)
	{
		if (kEquipmentTemplate == none || (m_bMPSlot && (!kEquipmentTemplate.IsTemplateAvailableToAnyArea(kEquipmentTemplate.BITFIELD_GAMEAREA_Multiplayer))))
			continue;
		if( X2EquipmentTemplate(kEquipmentTemplate) != none &&
			X2EquipmentTemplate(kEquipmentTemplate).iItemSize > 0 &&  // xpad is only item with size 0, that is always equipped
			(((X2EquipmentTemplate(kEquipmentTemplate).InventorySlot == eEquipmentType) || (X2EquipmentTemplate(kEquipmentTemplate).InventorySlot == eInvSlot_Utility && eEquipmentType == eInvSlot_GrenadePocket))) ||
			(class'X2DownloadableContentInfo_TruePrimarySecondaries'.static.IsSecondaryMeleeWeaponTemplate(X2WeaponTemplate(kEquipmentTemplate)) ||
			 class'X2DownloadableContentInfo_TruePrimarySecondaries'.static.IsSecondaryPistolWeaponTemplate(X2WeaponTemplate(kEquipmentTemplate))
			)
	)
		{
			if (kSoldierClassTemplate != None && kEquipmentTemplate.IsA('X2WeaponTemplate'))
			{
				if (!kSoldierClassTemplate.IsWeaponAllowedByClass(X2WeaponTemplate(kEquipmentTemplate)))
				{
					if (nCurrentEquipped == kEquipmentTemplate.DataName)
						nCurrentEquipped = '';
					continue;
				}
			}

			if (kSoldierClassTemplate != None && kEquipmentTemplate.IsA('X2ArmorTemplate'))
			{
				if (!kSoldierClassTemplate.IsArmorAllowedByClass(X2ArmorTemplate(kEquipmentTemplate)))
				{
					if (nCurrentEquipped == kEquipmentTemplate.DataName)
						nCurrentEquipped = '';
					continue;
				}
			}

			if (eEquipmentType == eInvSlot_GrenadePocket)
			{
				if (X2GrenadeTemplate(kEquipmentTemplate) == None)
				{
					if (nCurrentEquipped == kEquipmentTemplate.DataName)
						nCurrentEquipped = '';
					continue;
				}
			}

			kDropdown.AddItem(X2EquipmentTemplate(kEquipmentTemplate).GetItemFriendlyName() @ GetStringFormatPoints(X2EquipmentTemplate(kEquipmentTemplate).GetPointsToComplete()), string(kEquipmentTemplate.DataName));

			if (kEquipmentTemplate.DataName == nCurrentEquipped)
			{
				kDropdown.SetSelected(kDropdown.items.Length - 1);
				bFoundCurrent = true;
			}
		}
	}
	if (eEquipmentType == eInvSlot_PrimaryWeapon || eEquipmentType == eInvSlot_SecondaryWeapon || eEquipmentType == eInvSlot_GrenadePocket)
	{
		if (!bFoundCurrent)
		{
			if (bHaveNothing && kDropdown.Items.Length > 1)
			{			
				kDropdown.SetSelected(1);			
			}
			else
			{
				kDropdown.SetSelected(0);
			}
			nCurrentEquipped = name(kDropdown.GetSelectedItemData());
		}
	}
	return nCurrentEquipped;
}

