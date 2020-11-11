class X2DownloadableContentInfo_TruePrimarySecondaries extends X2DownloadableContentInfo
	config (TruePrimarySecondaries);


struct AmmoCost
{
	var name Ability;
	var int Ammo;
};

struct PistolWeaponAttachment {
	var string Type;
	var name AttachSocket;
	var name UIArmoryCameraPointTag;
	var string MeshName;
	var string ProjectileName;
	var name MatchWeaponTemplate;
	var bool AttachToPawn;
	var string IconName;
	var string InventoryIconName;
	var string InventoryCategoryIcon;
	var name AttachmentFn;
};

struct ArchetypeReplacement {
	var() name TemplateName;
	var() string GameArchetype;
	var() int NumUpgradeSlots;
};

Struct WeaponConfig {
	var name TemplateName;
	var EInventorySlot ApplyToSlot;
	var bool bKeepPawnWeaponAnimation;
	var bool bUseSideSheaths;
	var bool bUseEmptyHandSoldierAnimations;
	var name CustomFireAnim;
	var string CustomWeaponPawnAnimset;

	structdefaultproperties
	{
		bKeepPawnWeaponAnimation = false
		bUseSideSheaths = true
		bUseEmptyHandSoldierAnimations = false
		ApplyToSlot = eInvSlot_Unknown
	}
};

struct DLCAnimSetAdditions
{
	var Name CharacterGroup;
	var String AnimSet;
	var String FemaleAnimSet;
};

var config array<DLCAnimSetAdditions> AnimSetAdditions;
var config array<AmmoCost> AmmoCosts;
var config array<ArchetypeReplacement> ArchetypeReplacements;
var config array<PistolWeaponAttachment> PistolAttachements;
var config array<name> PistolCategories;
var config array<name> WeaponCategoryBlacklist;
var config array<name> DontOverridePawnAndWeaponAnimsetsWeaponCategories;
var config array<WeaponConfig> IndividualWeaponConfig;

var array<name> SkipWeapons;

var config array<int> MIDSHORT_CONVENTIONAL_RANGE;
var config int PRIMARY_PISTOLS_CLIP_SIZE;
var config int PRIMARY_SAWEDOFF_CLIP_SIZE;
var config int PRIMARY_PISTOLS_DAMAGE_MODIFER;
var config bool bPrimaryPistolsInfiniteAmmo;
var config bool bLog;
var config bool bLogAnimations;
var config bool bUseSlomoInAnimations;
var config bool bUseVisualPistolUpgrades;

static function bool CanAddItemToInventory_CH_Improved(out int bCanAddItem, const EInventorySlot Slot, const X2ItemTemplate ItemTemplate, int Quantity, XComGameState_Unit UnitState, optional XComGameState CheckGameState, optional out string DisabledReason, optional XComGameState_Item ItemState)
{
	local bool bEvaluate;
	
	if (!UnitState.bIgnoreItemEquipRestrictions &&
		class'Helper'.static.IsPrimarySecondaryTemplate(X2WeaponTemplate(ItemTemplate), Slot))
	{
		if (Slot == eInvSlot_PrimaryWeapon &&
			IsWeaponAllowedByClass(
			UnitState.GetSoldierClassTemplate(),
			X2WeaponTemplate(ItemTemplate),
			Slot)
		)
		{
			bCanAddItem = 1;
			DisabledReason = "";
			bEvaluate = true;
			`Log(GetFuncName() @ "Allow" @ ItemTemplate.DataName @ Slot, class'Helper'.static.ShouldLog() , 'TruePrimarySecondaries');
		}
	}

	if(CheckGameState == none)
	{
		return !bEvaluate;
	}

	`Log(GetFuncName() @ "Ignore" @ ItemTemplate.DataName, class'Helper'.static.ShouldLog() , 'TruePrimarySecondaries');

	return bEvaluate;
}

// Like X2SoldierClassTemplate.IsWeaponAllowedByClass but checks for primary slot specifically regardless of the slot of the template
static function bool IsWeaponAllowedByClass(
	X2SoldierClassTemplate ClassTemplate,
	X2WeaponTemplate WeaponTemplate,
	EInventorySlot Slot
)
{
	local int Index;
	
	if (WeaponTemplate == none)
	{
		return true;
	}

	for (Index = 0; Index < ClassTemplate.AllowedWeapons.Length; ++Index)
	{
		if (ClassTemplate.AllowedWeapons[Index].SlotType == Slot &&
			ClassTemplate.AllowedWeapons[Index].WeaponType == WeaponTemplate.WeaponCat)
		{
			`Log(GetFuncName() @ "Allow" @
				ClassTemplate.DataName @
				WeaponTemplate.DataName @
				ClassTemplate.AllowedWeapons[Index].SlotType @
				ClassTemplate.AllowedWeapons[Index].WeaponType,
				class'Helper'.static.ShouldLog(),
				'TruePrimarySecondaries'
			);
			return true;
		}
	}
	return false;
}

static function MatineeGetPawnFromSaveData(XComUnitPawn UnitPawn, XComGameState_Unit UnitState, XComGameState SearchState)
{
	class'ShellMapMatinee'.static.PatchAllLoadedMatinees(UnitPawn, UnitState, SearchState);
}

static event OnPostTemplatesCreated()
{
	//RemovePrimarySuffix();

	if (default.bUseVisualPistolUpgrades)
	{
		ReplacePistolArchetypes();
	}

	PatchAbilityTemplates();
	OnPostCharacterTemplatesCreated();
	AddAttachments();
}

static function RemovePrimarySuffix()
{
	local InventoryLoadout Loadout;
	local X2ItemTemplateManager ItemTemplateManager;
	local int Index;

	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();

	// Fix loadouts based on old primary secondaries mod
	for (Index = 0; Index < ItemTemplateManager.Loadouts.Length; Index++)
	{
		Loadout = ItemTemplateManager.Loadouts[Index];

		if (Loadout.Items.Length > 0 && InStr(Loadout.Items[0].Item, "_Primary") != INDEX_NONE)
		{
			Loadout.Items[0].Item = 
				name(Repl(Loadout.Items[0].Item, "_Primary", ""));
			
			ItemTemplateManager.Loadouts[Index] = Loadout;
			
			`LOG(GetFuncName() @
				ItemTemplateManager.Name @
				ItemTemplateManager.Loadouts[Index].LoadoutName @
				ItemTemplateManager.Loadouts[Index].Items[0].Item,
				class'Helper'.static.ShouldLog(),
				'TruePrimarySecondaries'
			);
		}
	}
}

static function OnPostCharacterTemplatesCreated()
{
	local X2CharacterTemplateManager CharacterTemplateMgr;
	local X2CharacterTemplate CharacterTemplate;
	local array<X2DataTemplate> DataTemplates;
	local int ScanTemplates, ScanAdditions;
	local array<name> AllTemplateNames;
	local name TemplateName;

	CharacterTemplateMgr = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
	
	CharacterTemplateMgr.GetTemplateNames(AllTemplateNames);

	foreach AllTemplateNames(TemplateName)
	{
		CharacterTemplateMgr.FindDataTemplateAllDifficulties(TemplateName, DataTemplates);

		for ( ScanTemplates = 0; ScanTemplates < DataTemplates.Length; ++ScanTemplates )
		{
			CharacterTemplate = X2CharacterTemplate(DataTemplates[ScanTemplates]);
			if (CharacterTemplate != none)
			{
				ScanAdditions = default.AnimSetAdditions.Find('CharacterGroup', CharacterTemplate.CharacterGroupName);
				if (ScanAdditions != INDEX_NONE)
				{
					CharacterTemplate.AdditionalAnimSets.AddItem(AnimSet(`CONTENT.RequestGameArchetype(default.AnimSetAdditions[ScanAdditions].AnimSet)));
					CharacterTemplate.AdditionalAnimSetsFemale.AddItem(AnimSet(`CONTENT.RequestGameArchetype(default.AnimSetAdditions[ScanAdditions].FemaleAnimSet)));
				}
			}
		}
	}
}

static function AddAttachments()
{
	local array<name> AttachmentTypes;
	local name AttachmentType;
	
	AttachmentTypes.AddItem('CritUpgrade_Bsc');
	AttachmentTypes.AddItem('CritUpgrade_Adv');
	AttachmentTypes.AddItem('CritUpgrade_Sup');
	AttachmentTypes.AddItem('AimUpgrade_Bsc');
	AttachmentTypes.AddItem('AimUpgrade_Adv');
	AttachmentTypes.AddItem('AimUpgrade_Sup');
	AttachmentTypes.AddItem('ClipSizeUpgrade_Bsc');
	AttachmentTypes.AddItem('ClipSizeUpgrade_Adv');
	AttachmentTypes.AddItem('ClipSizeUpgrade_Sup');
	AttachmentTypes.AddItem('FreeFireUpgrade_Bsc');
	AttachmentTypes.AddItem('FreeFireUpgrade_Adv');
	AttachmentTypes.AddItem('FreeFireUpgrade_Sup');
	AttachmentTypes.AddItem('ReloadUpgrade_Bsc');
	AttachmentTypes.AddItem('ReloadUpgrade_Adv');
	AttachmentTypes.AddItem('ReloadUpgrade_Sup');
	AttachmentTypes.AddItem('MissDamageUpgrade_Bsc');
	AttachmentTypes.AddItem('MissDamageUpgrade_Adv');
	AttachmentTypes.AddItem('MissDamageUpgrade_Sup');
	AttachmentTypes.AddItem('FreeKillUpgrade_Bsc');
	AttachmentTypes.AddItem('FreeKillUpgrade_Adv');
	AttachmentTypes.AddItem('FreeKillUpgrade_Sup');

	foreach AttachmentTypes(AttachmentType)
	{
		AddAttachment(AttachmentType, default.PistolAttachements);
	}
}

static function AddAttachment(name TemplateName, array<PistolWeaponAttachment> Attachments) 
{
	local X2ItemTemplateManager ItemTemplateManager;
	local X2WeaponUpgradeTemplate Template;
	local PistolWeaponAttachment Attachment;
	local delegate<X2TacticalGameRulesetDataStructures.CheckUpgradeStatus> CheckFN;
	
	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	Template = X2WeaponUpgradeTemplate(ItemTemplateManager.FindItemTemplate(TemplateName));
	
	foreach Attachments(Attachment)
	{
		if (InStr(string(TemplateName), Attachment.Type) != INDEX_NONE)
		{
			switch(Attachment.AttachmentFn) 
			{
				case ('NoReloadUpgradePresent'): 
					CheckFN = class'X2Item_DefaultUpgrades'.static.NoReloadUpgradePresent; 
					break;
				case ('ReloadUpgradePresent'): 
					CheckFN = class'X2Item_DefaultUpgrades'.static.ReloadUpgradePresent; 
					break;
				case ('NoClipSizeUpgradePresent'): 
					CheckFN = class'X2Item_DefaultUpgrades'.static.NoClipSizeUpgradePresent; 
					break;
				case ('ClipSizeUpgradePresent'): 
					CheckFN = class'X2Item_DefaultUpgrades'.static.ClipSizeUpgradePresent; 
					break;
				case ('NoFreeFireUpgradePresent'): 
					CheckFN = class'X2Item_DefaultUpgrades'.static.NoFreeFireUpgradePresent; 
					break;
				case ('FreeFireUpgradePresent'): 
					CheckFN = class'X2Item_DefaultUpgrades'.static.FreeFireUpgradePresent; 
					break;
				default:
					CheckFN = none;
					break;
			}
			Template.AddUpgradeAttachment(Attachment.AttachSocket, Attachment.UIArmoryCameraPointTag, Attachment.MeshName, Attachment.ProjectileName, Attachment.MatchWeaponTemplate, Attachment.AttachToPawn, Attachment.IconName, Attachment.InventoryIconName, Attachment.InventoryCategoryIcon, CheckFN);
			`LOG("Attachment for" @
				TemplateName @
				Attachment.AttachSocket @
				Attachment.UIArmoryCameraPointTag @
				Attachment.MeshName @
				Attachment.ProjectileName @
				Attachment.MatchWeaponTemplate @
				Attachment.AttachToPawn @
				Attachment.IconName @
				Attachment.InventoryIconName @
				Attachment.InventoryCategoryIcon,
				class'Helper'.static.ShouldLog(),
				'TruePrimarySecondaries'
			);
		}
	}
}

static function ReplacePistolArchetypes()
{
	local X2ItemTemplateManager ItemTemplateManager;
	local array<X2DataTemplate> DifficultyVariants;
	local X2DataTemplate ItemTemplate;
	local X2WeaponTemplate WeaponTemplate;
	local ArchetypeReplacement Replacement;

	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	
	foreach default.ArchetypeReplacements(Replacement)
	{
		ItemTemplateManager.FindDataTemplateAllDifficulties(Replacement.TemplateName, DifficultyVariants);
		// Iterate over all variants
		foreach DifficultyVariants(ItemTemplate)
		{
			WeaponTemplate = X2WeaponTemplate(ItemTemplate);
			if (WeaponTemplate != none)
			{
				WeaponTemplate.GameArchetype = Replacement.GameArchetype;
				WeaponTemplate.NumUpgradeSlots = Replacement.NumUpgradeSlots;
				WeaponTemplate.UIArmoryCameraPointTag = 'UIPawnLocation_WeaponUpgrade_Shotgun';

				ItemTemplateManager.AddItemTemplate(WeaponTemplate, true);
				`Log("Patching" @ ItemTemplate.DataName @ "with" @ Replacement.GameArchetype @ "and" @ Replacement.NumUpgradeSlots @ "upgrade slots", class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
			}
		}
	}

	ItemTemplateManager.LoadAllContent();
}

static function PatchAbilityTemplates()
{
	local X2AbilityTemplateManager						TemplateManager;
	local X2AbilityTemplate								Template;
	local X2AbilityCost_Ammo							NewAmmoCosts;
	local X2AbilityCost									CurrentAbilityCosts;
	local AmmoCost										AbilityAmmoCost;
	local bool											bHasAmmoCost;
	local array<X2AbilityTemplate>						AbilityTemplates;
	local array<name>									TemplateNames;
	local name											TemplateName;
	local X2AbilityCost_ActionPoints					ActionPointCost;
	local X2Condition_PrimaryMeleeDisorient				ShooterExclusionsCondition;
	local int i;
	
	TemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();

	foreach default.AmmoCosts(AbilityAmmoCost)
	{
		TemplateManager.FindAbilityTemplateAllDifficulties(AbilityAmmoCost.Ability, AbilityTemplates);
		foreach AbilityTemplates(Template)
		{
			if (Template != none)
			{
				bHasAmmoCost = false;
				foreach Template.AbilityCosts(CurrentAbilityCosts)
				{
					if (X2AbilityCost_Ammo(CurrentAbilityCosts) != none)
					{
						X2AbilityCost_Ammo(CurrentAbilityCosts).iAmmo =  AbilityAmmoCost.Ammo;
						bHasAmmoCost = true;
						break;
					}
				}
				if (!bHasAmmoCost)
				{
					NewAmmoCosts = new class'X2AbilityCost_Ammo';
					NewAmmoCosts.iAmmo = AbilityAmmoCost.Ammo;
					Template.AbilityCosts.AddItem(NewAmmoCosts);
				}

				`LOG("Patching Template" @ AbilityAmmoCost.Ability @ "adding" @ AbilityAmmoCost.Ammo @ "ammo cost", class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
			}
		}
	}

	TemplateNames.AddItem('PistolStandardShot');
	
	foreach TemplateNames(TemplateName)
	{
		Template = TemplateManager.FindAbilityTemplate(TemplateName);
		if (Template != none)
		{
			ActionPointCost = GetAbilityCostActionPoints(Template);
			if (ActionPointCost != none && ActionPointCost.DoNotConsumeAllSoldierAbilities.Find('QuickDrawPrimary') == INDEX_NONE)
			{
				ActionPointCost.DoNotConsumeAllSoldierAbilities.AddItem('QuickDrawPrimary');
				ActionPointCost.DoNotConsumeAllSoldierAbilities.AddItem('Quickdraw');
				`LOG("Patching Template" @ TemplateName @ "adding QuickDrawPrimary and Quickdraw to DoNotConsumeAllSoldierAbilities", class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
			}
		}
	}

	TemplateNames.Length = 0;
	TemplateNames.AddItem('Bladestorm');
	
	foreach TemplateNames(TemplateName)
	{
		Template = TemplateManager.FindAbilityTemplate(TemplateName);
		if (Template != none)
		{
			Template.AdditionalAbilities.AddItem('BladestormAttackPrimary');
		}
	}

	TemplateManager.FindAbilityTemplateAllDifficulties('SwordSlice', AbilityTemplates);
	foreach AbilityTemplates(Template)
	{
		for (i = 0; i < Template.AbilityShooterConditions.Length; i++)
		{
			if (X2Condition_UnitEffects(Template.AbilityShooterConditions[i]) != none)
			{
				//	The vanilla behavior for SwordSlice is to disallow using it if the owner unit is disoriented.
				//	Replace it with a different condition that will fail if the unit is disoriented ONLY if the ability is NOT attached to primary melee.
				//	So the SwordSlice will remain usable if it's attached to a primary melee, even if the owner unit is Disoriented.
				//	In all other cases the replacement condition will work exactly the same as original.

				ShooterExclusionsCondition = new class'X2Condition_PrimaryMeleeDisorient';
				//ShooterExclusionsCondition.AddExcludeEffect(class'X2AbilityTemplateManager'.default.DisorientedName, 'AA_UnitIsDisoriented');
				//ShooterExclusionsCondition.AddExcludeEffect(class'X2StatusEffects'.default.BurningName, 'AA_UnitIsBurning');
				ShooterExclusionsCondition.AddExcludeEffect(class'X2Ability_CarryUnit'.default.CarryUnitEffectName, 'AA_CarryingUnit');
				ShooterExclusionsCondition.AddExcludeEffect(class'X2AbilityTemplateManager'.default.BoundName, 'AA_UnitIsBound');
				ShooterExclusionsCondition.AddExcludeEffect(class'X2AbilityTemplateManager'.default.ConfusedName, 'AA_UnitIsConfused');
				ShooterExclusionsCondition.AddExcludeEffect(class'X2Effect_PersistentVoidConduit'.default.EffectName, 'AA_UnitIsBound');
				ShooterExclusionsCondition.AddExcludeEffect(class'X2AbilityTemplateManager'.default.StunnedName, 'AA_UnitIsStunned');
				ShooterExclusionsCondition.AddExcludeEffect(class'X2AbilityTemplateManager'.default.DazedName, 'AA_UnitIsStunned');
				ShooterExclusionsCondition.AddExcludeEffect('Freeze', 'AA_UnitIsFrozen');

				Template.AbilityShooterConditions[i] = ShooterExclusionsCondition;
				`LOG("Patching SwordSlice ability template so that it can be used even while disoriented if attached to primary melee weapon.", class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
				break;
			}
		}			
	}
}

static function X2AbilityCost_ActionPoints GetAbilityCostActionPoints(X2AbilityTemplate Template)
{
	local X2AbilityCost Cost;
	foreach Template.AbilityCosts(Cost)
	{
		if (X2AbilityCost_ActionPoints(Cost) != none)
		{
			return X2AbilityCost_ActionPoints(Cost);
		}
	}
	return none;
}

static function FinalizeUnitAbilitiesForInit(XComGameState_Unit UnitState, out array<AbilitySetupData> SetupData, optional XComGameState StartState, optional XComGameState_Player PlayerState, optional bool bMultiplayerDisplay)
{
	local int Index;
	
	// Associate all melee abilities with the primary weapon if primary melee weapons are equipped
	if (UnitState.IsSoldier() && !Api().HasDualMeleeEquipped(UnitState) && Api().HasPrimaryMeleeEquipped(UnitState))
	{
		for(Index = 0; Index < SetupData.Length; Index++)
		{
			if (SetupData[Index].Template != none && SetupData[Index].Template.IsMelee() && SetupData[Index].TemplateName != 'DualSlashSecondary')
			{
				SetupData[Index].SourceWeaponRef = UnitState.GetPrimaryWeapon().GetReference();
				`LOG(GetFuncName() @ UnitState.GetFullName() @ "setting" @ SetupData[Index].TemplateName @ "to" @ UnitState.GetPrimaryWeapon().GetMyTemplateName(), class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
			}
		}
	}
}

static function UpdateWeaponAttachments(out array<WeaponAttachment> Attachments, XComGameState_Item ItemState)
{
	local XComGameState_Unit UnitState;
	local int i;
	local name NewSocket;
	local vector Scale;
	local WeaponConfig IndividualWeaponConfigLocal;

	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ItemState.OwnerStateObject.ObjectID));

	if(UnitState != none && Api().HasDualMeleeEquipped(UnitState))
	{
		return;
	}

	if (default.WeaponCategoryBlacklist.Find(X2WeaponTemplate(ItemState.GetMyTemplate()).WeaponCat) != INDEX_NONE)
	{
		return;
	}

	FindIndividualWeaponConfig(ItemState, IndividualWeaponConfigLocal);
	if (!IndividualWeaponConfigLocal.bUseSideSheaths)
	{
		NewSocket = 'Sheath';
	}

	if(NewSocket == 'None' && Api().IsPrimaryMeleeItem(ItemState))
	{
		NewSocket = 'PrimaryMeleeLeftSheath';
	}

	if (NewSocket != '')
	{
		for (i = Attachments.Length - 1; i >= 0; i--)
		{
			if (Attachments[i].AttachToPawn && (Attachments[i].AttachSocket == 'Sheath' || Attachments[i].AttachSocket == 'PrimaryMeleeLeftSheath'))
			{
				Attachments[i].AttachSocket = NewSocket;
				if (UnitState.kAppearance.iGender == eGender_Female)
				{
					Scale.X = 0.85f;
					Scale.Y = 0.85f;
					Scale.Z = 0.85f;
					XGUnit(UnitState.GetVisualizer()).GetPawn().Mesh.GetSocketByName(NewSocket).RelativeScale = Scale;
				}
				`LOG(GetFuncName() @ UnitState.GetFullName() @ ItemState.GetMyTemplateName() @ NewSocket @ "bUseSideSheaths" @ IndividualWeaponConfigLocal.bUseSideSheaths, class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
			}
		}
	}
}

static function WeaponInitialized(XGWeapon WeaponArchetype, XComWeapon Weapon, optional XComGameState_Item ItemState=none)
{
	local X2WeaponTemplate WeaponTemplate;
	local XComGameState_Unit UnitState;
	local array<string> AnimSetPaths;
	local string AnimSetPath;
	local bool bResetAnimsets, bOverride;
	local WeaponConfig IndividualWeaponConfigLocal;
	local array<AnimSet> CustomUnitPawnAnimsets;
	local array<AnimSet> CustomUnitPawnAnimsetsFemale;
	local AnimSet Anim;

	bResetAnimsets = true;
	bOverride = true;

	if (ItemState == none)
	{
		return;
	}
	
	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ItemState.OwnerStateObject.ObjectID));

	if (!AllowUnitState(UnitState))
	{
		return;
	}

	WeaponTemplate = X2WeaponTemplate(ItemState.GetMyTemplate());

	if (default.WeaponCategoryBlacklist.Find(WeaponTemplate.WeaponCat) != INDEX_NONE)
	{
		return;
	}

	FindIndividualWeaponConfig(ItemState, IndividualWeaponConfigLocal);
	
	if (IndividualWeaponConfigLocal.bKeepPawnWeaponAnimation)
	{
		return;
	}

	//`LOG(GetFuncName() @ "Spawn" @ WeaponArchetype @ ItemState.GetMyTemplateName() @ Weapon.CustomUnitPawnAnimsets.Length, class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');

	if (IndividualWeaponConfigLocal.bUseEmptyHandSoldierAnimations)
	{
		if (Api().IsPrimaryMeleeItem(ItemState) && Api().HasPrimaryMeleeEquipped(UnitState))
		{
			if (InStr(WeaponTemplate.DataName, "SpecOpsKnife") == INDEX_NONE)
			{
				AnimSetPaths.AddItem("TruePrimarySecondaries_ANIM.Anims.AS_Melee");
			}
			else
			{
				AnimSetPaths.AddItem("TruePrimarySecondaries_ANIM.Anims.AS_KnifeMelee");
			}
		}
			
		if (Api().IsPrimaryPistolItem(ItemState) && Api().HasPrimaryPistolEquipped(UnitState))
		{
			if (WeaponTemplate.WeaponCat == 'sidearm')
			{
				AnimSetPaths.AddItem("TruePrimarySecondaries_ANIM.Anims.AS_AutoPistol");
			}
			else if (WeaponTemplate.WeaponCat == 'pistol')
			{
				AnimSetPaths.AddItem("TruePrimarySecondaries_ANIM.Anims.AS_PrimaryPistol");
			}
		}
	}
	else
	{
		if (Api().IsPrimaryMeleeItem(ItemState) && Api().HasPrimaryMeleeEquipped(UnitState))
		{
			Weapon.DefaultSocket = 'R_Hand';
		
			if (InStr(WeaponTemplate.DataName, "SpecOpsKnife") == INDEX_NONE)
			{
				// Patching the sequence name from FF_MeleeA to FF_Melee to support random sets via prefixes A,B,C etc
				Weapon.WeaponFireAnimSequenceName = IndividualWeaponConfigLocal.CustomFireAnim != 'None' ? IndividualWeaponConfigLocal.CustomFireAnim : 'FF_Melee';
				Weapon.WeaponFireKillAnimSequenceName = IndividualWeaponConfigLocal.CustomFireAnim != 'None' ? IndividualWeaponConfigLocal.CustomFireAnim : 'FF_MeleeKill';
				
				AnimSetPaths.AddItem("TruePrimarySecondaries_PrimaryMelee.Anims.AS_Sword");
			}
			else
			{
				AnimSetPaths.AddItem("TruePrimarySecondaries_ANIM.Anims.AS_KnifeMelee");
			}
		}
		else if (Api().IsPrimaryPistolItem(ItemState) && Api().HasPrimaryPistolEquipped(UnitState))
		{
			Weapon.DefaultSocket = 'R_Hand';
			`LOG(GetFuncName() @ ItemState.InventorySlot @ ItemState.GetMyTemplateName() @ "Setting DefaultSocket to R_Hand", class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');

			if (IndividualWeaponConfigLocal.CustomFireAnim != 'None')
			{
				Weapon.WeaponFireAnimSequenceName = IndividualWeaponConfigLocal.CustomFireAnim;
				Weapon.WeaponFireKillAnimSequenceName = IndividualWeaponConfigLocal.CustomFireAnim;
			}

			if (WeaponTemplate.WeaponCat == 'sidearm')
			{
				AnimSetPaths.AddItem("TruePrimarySecondaries_AutoPistol.Anims.AS_AutoPistol_Primary");
			}
			else if (WeaponTemplate.WeaponCat == 'pistol')
			{
				AnimSetPaths.AddItem("TruePrimarySecondaries_Pistol.Anims.AS_Pistol");

				if (WeaponTemplate.DataName == 'AlienHunterPistol_CV' || WeaponTemplate.DataName == 'AlienHunterPistol_MG')
				{
					AnimSetPaths.AddItem("TruePrimarySecondaries_Pistol.Anims.AS_Shadowkeeper");
				}

				if (WeaponTemplate.DataName == 'AlienHunterPistol_BM')
				{
					AnimSetPaths.AddItem("TruePrimarySecondaries_Pistol.Anims.AS_Shadowkeeper_BM");
				}

				if (WeaponTemplate.DataName == 'TLE_Pistol_BM')
				{
					AnimSetPaths.AddItem("TruePrimarySecondaries_Pistol.Anims.AS_PlasmaPistol");
				}
			}
		}
		else if (Api().IsSecondaryMeleeItem(ItemState) && Api().HasPrimaryPistolEquipped(UnitState))
		{
			AnimSetPaths.AddItem("TruePrimarySecondaries_Pistol.Anims.AS_SecondarySword");
		}
		else if (Api().IsSecondaryPistolItem(ItemState) && WeaponTemplate.WeaponCat == 'sidearm')
		{
			// Patching the default autopistol template here so other soldiers than templars can use it
			AnimSetPaths.AddItem("TruePrimarySecondaries_AutoPistol.Anims.AS_AutoPistol_Secondary");
		}
		if (Api().IsSecondaryPistolItem(ItemState) && Api().HasPrimaryMeleeEquipped(UnitState))
		{
			bResetAnimsets = false;
			AnimSetPaths.AddItem("TruePrimarySecondaries_PrimaryMelee.Anims.AS_SecondaryPistol");
		}

		if (default.DontOverridePawnAndWeaponAnimsetsWeaponCategories.Find(WeaponTemplate.WeaponCat) != INDEX_NONE)
		{
			bResetAnimsets = false;
			bOverride = false;
		}

		if (IndividualWeaponConfigLocal.CustomWeaponPawnAnimset != "")
		{
			AnimSetPaths.Length = 0;
			AnimSetPaths.AddItem(IndividualWeaponConfigLocal.CustomWeaponPawnAnimset);
		}

		if (AnimSetPaths.Length > 0)
		{
			if (!bOverride)
			{
				CustomUnitPawnAnimsets = Weapon.CustomUnitPawnAnimsets;
				CustomUnitPawnAnimsetsFemale = Weapon.CustomUnitPawnAnimsetsFemale;
			}

			if (bResetAnimsets || !bOverride)
			{
				Weapon.CustomUnitPawnAnimsets.Length = 0;
				Weapon.CustomUnitPawnAnimsetsFemale.Length = 0;
			}

			foreach AnimSetPaths(AnimSetPath)
			{
				Weapon.CustomUnitPawnAnimsets.AddItem(AnimSet(`CONTENT.RequestGameArchetype(AnimSetPath)));
				`LOG(GetFuncName() @ "----> Adding" @ AnimSetPath @ "to CustomUnitPawnAnimsets of" @ WeaponTemplate.DataName @ "Weapon.DefaultSocket" @ Weapon.DefaultSocket, class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
			}

			// Apply the original animations on top
			if (!bOverride)
			{
				foreach CustomUnitPawnAnimsets(Anim)
				{
					Weapon.CustomUnitPawnAnimsets.AddItem(Anim);
				}

				foreach CustomUnitPawnAnimsetsFemale(Anim)
				{
					Weapon.CustomUnitPawnAnimsetsFemale.AddItem(Anim);
				}
			}

			//foreach Weapon.CustomUnitPawnAnimsets(Anim)
			//{
			//	`LOG(Pathname(Anim), class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
			//}
		}
	}
}

static function UnitPawnPostInitAnimTree(XComGameState_Unit UnitState, XComUnitPawnNativeBase Pawn, SkeletalMeshComponent SkelComp)
{
	local AnimTree AnimTreeTemplate;

	if (!AllowUnitState(UnitState))
	{
		return;
	}

	if (Api().HasPrimaryPistolEquipped(UnitState))
	{
		AnimTreeTemplate = AnimTree(`CONTENT.RequestGameArchetype("TruePrimarySecondaries_AT.AT_Soldier", class'AnimTree'));
		SkelComp.SetAnimTreeTemplate(AnimTreeTemplate);
	}
}

static function UpdateAnimations(out array<AnimSet> CustomAnimSets, XComGameState_Unit UnitState, XComUnitPawn Pawn)
{
	local string AnimSetPath, FemaleSuffix;
	local AnimSet Anim;
	local int Index;
	local WeaponConfig IndividualWeaponConfigLocal;

	//`LOG(default.class @ GetFuncName(), class'Helper'.static.ShouldLog(), 'DLCSort');
	
	if (!AllowUnitState(UnitState))
	{
		return;
	}

	CustomAnimSets.AddItem(AnimSet(`CONTENT.RequestGameArchetype("TruePrimarySecondaries_Target.Anims.AS_Advent")));
	
	if (Api().HasPrimaryMeleeOrPistolEquipped(UnitState))
	{
		FindIndividualWeaponConfig(UnitState.GetPrimaryWeapon(), IndividualWeaponConfigLocal);
		
		if (IndividualWeaponConfigLocal.bUseEmptyHandSoldierAnimations)
		{
			UnitState.kAppearance.iAttitude = 0;
			UnitState.UpdatePersonalityTemplate();
			CustomAnimSets.AddItem(AnimSet(`CONTENT.RequestGameArchetype("TruePrimarySecondaries_Armory.Anims.AS_Armory_Unarmed")));
			AddAnimSet(Pawn, AnimSet(`CONTENT.RequestGameArchetype("TruePrimarySecondaries_ANIM.Anims.AS_Primary")), 4);
			return;
		}

		If (UnitState.kAppearance.iGender == eGender_Female)
		{
			FemaleSuffix = "_F";
		}

		if (Api().HasPrimaryPistolEquipped(UnitState))
		{
			if (X2WeaponTemplate(UnitState.GetItemInSlot(eInvSlot_PrimaryWeapon).GetMyTemplate()).WeaponCat == 'sidearm')
			{
				AnimSetPath = "TruePrimarySecondaries_AutoPistol.Anims.AS_Soldier";
				CustomAnimSets.AddItem(AnimSet(`CONTENT.RequestGameArchetype("TruePrimarySecondaries_AutoPistol.Anims.AS_Armory" $ FemaleSuffix)));
			}
			else
			{
				AnimSetPath = "TruePrimarySecondaries_Pistol.Anims.AS_Soldier";
				CustomAnimSets.AddItem(AnimSet(`CONTENT.RequestGameArchetype("TruePrimarySecondaries_Pistol.Anims.AS_Armory" $ FemaleSuffix)));
			}
		}
		else if (Api().HasPrimaryMeleeEquipped(UnitState))
		{
			AnimSetPath = "TruePrimarySecondaries_PrimaryMelee.Anims.AS_Soldier" $ FemaleSuffix;

			CustomAnimSets.AddItem(AnimSet(`CONTENT.RequestGameArchetype("TruePrimarySecondaries_PrimaryMelee.Anims.AS_Armory" $ FemaleSuffix)));
		}
		

		if (AnimSetPath != "")
		{
			//CustomAnimSets.AddItem(AnimSet(`CONTENT.RequestGameArchetype(AnimSetPath)));

			AddAnimSet(Pawn, AnimSet(`CONTENT.RequestGameArchetype(AnimSetPath)), Pawn.DefaultUnitPawnAnimsets.Length);

			`LOG(GetFuncName() @ "Adding" @ AnimSetPath @ "to" @ UnitState.GetFullName(), class'Helper'.static.ShouldLogAnimations(), 'TruePrimarySecondaries');
		}
		
		Index = 0;
		foreach Pawn.Mesh.AnimSets(Anim)
		{
			`LOG(GetFuncName() @ "Pawn.Mesh.AnimSets" @ Index @ Pathname(Anim), class'Helper'.static.ShouldLogAnimations(), 'TruePrimarySecondaries');
			Index++;
		}

		Index = 0;
		foreach Pawn.DefaultUnitPawnAnimsets(Anim)
		{
			`LOG(GetFuncName() @ "DefaultUnitPawnAnimsets" @ Index @ Pathname(Anim) @ Anim.ObjectArchetype @ Anim.Name, class'Helper'.static.ShouldLogAnimations(), 'TruePrimarySecondaries');
			Index++;
		}

		`LOG(GetFuncName() @ "--------------------------------------------------------------", class'Helper'.static.ShouldLogAnimations(), 'TruePrimarySecondaries');

		//Pawn.Mesh.UpdateAnimations();
	}
}

static function AddAnimSet(XComUnitPawn Pawn, AnimSet AnimSetToAdd, optional int Index = -1)
{
	if (Pawn.Mesh.AnimSets.Find(AnimSetToAdd) == INDEX_NONE)
	{
		if (Index != INDEX_NONE)
		{
			Pawn.Mesh.AnimSets.InsertItem(Index, AnimSetToAdd);
		}
		else
		{
			Pawn.Mesh.AnimSets.AddItem(AnimSetToAdd);
		}
		`LOG(GetFuncName() @ "adding" @ AnimSetToAdd @ "at Index" @ Index, class'Helper'.static.ShouldLogAnimations(), 'TruePrimarySecondaries');
	}
}

static function DLCAppendWeaponSockets(out array<SkeletalMeshSocket> NewSockets, XComWeapon Weapon, XComGameState_Item ItemState)
{
    local vector					RelativeLocation;
	local rotator					RelativeRotation;
    local SkeletalMeshSocket		Socket;
	local X2WeaponTemplate			Template;
	local array<name>				BoneNames;
	local name						Bone, BoneNameToUse;
	local XComGameState_Unit		UnitState;
	local WeaponConfig				IndividualWeaponConfigLocal;

	Template = X2WeaponTemplate(ItemState.GetMyTemplate());

	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ItemState.OwnerStateObject.ObjectID));

	if (!Api().HasPrimaryMeleeOrPistolEquipped(UnitState))
	{
		return;
	}

	if (default.WeaponCategoryBlacklist.Find(Template.WeaponCat) != INDEX_NONE)
	{
		return;
	}

	FindIndividualWeaponConfig(ItemState, IndividualWeaponConfigLocal);
	if (IndividualWeaponConfigLocal.bUseEmptyHandSoldierAnimations)
	{
		return;
	}

	if (Api().IsPrimaryPistolItem(ItemState) || Api().IsPrimaryMeleeItem(ItemState))
	{
		SkeletalMeshComponent(Weapon.Mesh).GetBoneNames(BoneNames);
		foreach BoneNames(Bone)
		{
			`LOG(GetFuncName() @ ItemState.GetMyTemplateName() @ "Bone" @ Bone, class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
			if (Instr(Locs(Bone), "root") != INDEX_NONE)
			{
				BoneNameToUse = Bone;
				break;
			}
		}

		if (BoneNameToUse == 'None')
		{
			BoneNameToUse = SkeletalMeshComponent(Weapon.Mesh).GetBoneName(0);
			`LOG(GetFuncName() @ ItemState.GetMyTemplateName() @ "No root Bone found. Using bone on index 0" @ BoneNameToUse, class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
		}

		if (Template.WeaponCat == 'sword')
		{
			RelativeLocation.X = -10;
			RelativeLocation.Y = -1;
			RelativeLocation.Z = -9;
		
			//RelativeRotation.Roll = int(-90 * DegToUnrRot);
			RelativeRotation.Pitch = int(-10 * DegToUnrRot);
			//RelativeRotation.Yaw = int(45 * DegToUnrRot);

			Socket = new class'SkeletalMeshSocket';
			Socket.SocketName = 'left_hand';
			Socket.BoneName = Bone;
			Socket.RelativeLocation = RelativeLocation;
			Socket.RelativeRotation = RelativeRotation;
			NewSockets.AddItem(Socket);

			`LOG(GetFuncName() @ ItemState.GetMyTemplateName() @ "Overriding" @ Socket.SocketName @ "socket on" @ Bone @ `showvar(RelativeLocation) @ `showvar(RelativeRotation), class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
		}

		if (Template.WeaponCat == 'pistol')
		{
			RelativeLocation.X = -6;
			RelativeLocation.Y = -3;
			RelativeLocation.Z = -6;
		
			RelativeRotation.Roll = int(-90 * DegToUnrRot);
			RelativeRotation.Pitch = int(0 * DegToUnrRot);
			RelativeRotation.Yaw = int(45 * DegToUnrRot);

			Socket = new class'SkeletalMeshSocket';
			Socket.SocketName = 'left_hand';
			Socket.BoneName = Bone;
			Socket.RelativeLocation = RelativeLocation;
			Socket.RelativeRotation = RelativeRotation;
			NewSockets.AddItem(Socket);

			`LOG(GetFuncName() @ ItemState.GetMyTemplateName() @ "Overriding" @ Socket.SocketName @ "socket on" @ Bone @ `showvar(RelativeLocation) @ `showvar(RelativeRotation), class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
		}

		if (Template.WeaponCat == 'sidearm')
		{
			RelativeLocation.X = -6.5;
			RelativeLocation.Y = -2.5;
			RelativeLocation.Z = -8;
		
			RelativeRotation.Roll = int(0 * DegToUnrRot);
			RelativeRotation.Pitch = int(0 * DegToUnrRot);
			RelativeRotation.Yaw = int(0 * DegToUnrRot);

			Socket = new class'SkeletalMeshSocket';
			Socket.SocketName = 'left_hand';
			Socket.BoneName = Bone;
			Socket.RelativeLocation = RelativeLocation;
			Socket.RelativeRotation = RelativeRotation;
			NewSockets.AddItem(Socket);

			`LOG(GetFuncName() @ ItemState.GetMyTemplateName() @ "Overriding" @ Socket.SocketName @ "socket on" @ Bone @ `showvar(RelativeLocation) @ `showvar(RelativeRotation), class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
		}
	}
}

static function string DLCAppendSockets(XComUnitPawn Pawn)
{
	local XComHumanPawn HumanPawn;
	local XComGameState_Unit UnitState;

	//`LOG("DLCAppendSockets" @ Pawn, class'Helper'.static.ShouldLog(), 'DualWieldMelee');

	HumanPawn = XComHumanPawn(Pawn);
	if (HumanPawn == none) { return ""; }

	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(HumanPawn.ObjectID));

	if (!AllowUnitState(UnitState)) { return ""; }

	if (Api().HasPrimaryMeleeEquipped(UnitState))
	{
		if (UnitState.kAppearance.iGender == eGender_Female)
		{
			return "TruePrimarySecondaries_Sockets.Meshes.PrimaryMelee_SocketsOverride_F";
		}
		else
		{
			return "TruePrimarySecondaries_Sockets.Meshes.PrimaryMelee_SocketsOverride";
		}
	}

	if (Api().HasPrimaryPistolEquipped(UnitState))
	{
		return "TruePrimarySecondaries_Sockets.Meshes.PrimaryPistol_SocketsOverride";
	}

	return "";
}

static function bool FindIndividualWeaponConfig(XComGameState_Item ItemState, out WeaponConfig FoundWeaponConfig)
{
	local WeaponConfig Conf;
	local string WeaponTemplateName, ConfigTemplateName;

	WeaponTemplateName = string(ItemState.GetMyTemplateName());

	foreach default.IndividualWeaponConfig(Conf)
	{
		// BC Support
		ConfigTemplateName = string(Conf.TemplateName);
		if (class'Helper'.static.HasAndReplacePrimarySuffix(ConfigTemplateName))
		{
			if (ConfigTemplateName == WeaponTemplateName)
			{
				FoundWeaponConfig = Conf;
				return true;
			}
		}
		else
		{
			if (Conf.TemplateName == name(WeaponTemplateName) &&
				Conf.ApplyToSlot == ItemState.InventorySlot)
			{
			
				FoundWeaponConfig = Conf;
				return true;
			}
		}
	}

	return false;
}


static function bool AllowUnitState(XComGameState_Unit UnitState)
{
	return UnitState != none && UnitState.IsSoldier();
}

static function bool IsLW2Installed()
{
	return IsModInstalled('X2DownloadableContentInfo_LW_Overhaul');
}

static function LoadoutApiInterface Api()
{
	return class'LoadoutApiFactory'.static.GetLoadoutApi();
}

static function bool IsModInstalled(name X2DCLName)
{
	local X2DownloadableContentInfo Mod;
	foreach `ONLINEEVENTMGR.m_cachedDLCInfos (Mod)
	{
		if (Mod.Class.Name == X2DCLName)
		{
			`Log("Mod installed:" @ Mod.Class, class'Helper'.static.ShouldLog());
			return true;
		}
	}

	return false;
}

static exec function PS_GiveItem(string ItemTemplateName, EInventorySlot Slot)
{
	local X2ItemTemplateManager ItemTemplateManager;
	local X2EquipmentTemplate ItemTemplate;
	local XComGameState NewGameState;
	local XComGameState_Unit Unit;
	local XGUnit Visualizer;
	local XComGameState_Item Item;
	local XComGameState_Item OldItem;
	local XComGameStateHistory History;
	local XGItem OldItemVisualizer;
	local XComGameState_Player kPlayer;

	local XComGameState_Ability ItemAbility;	
	local int AbilityIndex;
	local array<AbilitySetupData> AbilityData;
	local X2TacticalGameRuleset TacticalRules;
	local XComTacticalController TacticalController;

	History = `XCOMHISTORY;

	TacticalController = XComTacticalController(class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController());
	if (TacticalController == none)
	{
		return;
	}

	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	ItemTemplate = X2EquipmentTemplate(ItemTemplateManager.FindItemTemplate(name(ItemTemplateName)));
	if(ItemTemplate == none) return;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("CHEAT: Give Item '" $ ItemTemplateName $ "'");

	Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', TacticalController.GetActiveUnitStateRef().ObjectID));
	Visualizer = XGUnit(Unit.GetVisualizer());

	Item = ItemTemplate.CreateInstanceFromTemplate(NewGameState);

	//Take away the old item
	if (Slot == eInvSlot_PrimaryWeapon ||
		Slot == eInvSlot_SecondaryWeapon ||
		Slot == eInvSlot_HeavyWeapon)
	{
		OldItem = Unit.GetItemInSlot(Slot);
		Unit.RemoveItemFromInventory(OldItem, NewGameState);		

		//Remove abilities that were being granted by the old item
		for( AbilityIndex = Unit.Abilities.Length - 1; AbilityIndex > -1; --AbilityIndex )
		{
			ItemAbility = XComGameState_Ability(History.GetGameStateForObjectID(Unit.Abilities[AbilityIndex].ObjectID));
			if( ItemAbility.SourceWeapon.ObjectID == OldItem.ObjectID )
			{
				Unit.Abilities.Remove(AbilityIndex, 1);
			}
		}
	}

	Unit.bIgnoreItemEquipRestrictions = true; //Instruct the system that we don't care about item restrictions
	Unit.AddItemToInventory(Item, Slot, NewGameState);	

	//Give the unit any abilities that this weapon confers
	kPlayer = XComGameState_Player(History.GetGameStateForObjectID(Unit.ControllingPlayer.ObjectID));			
	AbilityData = Unit.GatherUnitAbilitiesForInit(NewGameState, kPlayer);
	TacticalRules = `TACTICALRULES;
	for (AbilityIndex = 0; AbilityIndex < AbilityData.Length; ++AbilityIndex)
	{
		if( AbilityData[AbilityIndex].SourceWeaponRef.ObjectID == Item.ObjectID )
		{
			TacticalRules.InitAbilityForUnit(AbilityData[AbilityIndex].Template, Unit, NewGameState, AbilityData[AbilityIndex].SourceWeaponRef);
		}
	}

	TacticalRules.SubmitGameState(NewGameState);

	if( OldItem.ObjectID > 0 )
	{
		//Destroy the visuals for the old item if we had one
		OldItemVisualizer = XGItem(History.GetVisualizer(OldItem.ObjectID));
		OldItemVisualizer.Destroy();
		History.SetVisualizer(OldItem.ObjectID, none);
	}
	
	//Create the visualizer for the new item, and attach it if needed
	Visualizer.ApplyLoadoutFromGameState(Unit, NewGameState);
}

exec function PS_ResetWeaponsToDefaultSockets()
{
	local XComTacticalController TacticalController;
	local XComGameState_Unit UnitState;
	//local XComUnitPawn Pawn;
	local XGUnit Unit;
	local XGInventory Inventory;

	TacticalController = XComTacticalController(class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController());
	if (TacticalController != none)
	{
		Unit = TacticalController.GetActiveUnit();
		//Unit.ResetWeaponsToDefaultSockets();

		//Pawn = TacticalController.GetActivePawn();
		//Pawn.CreateVisualInventoryAttachments();
		
		UnitState = XComGameState_Unit(
			`XCOMHISTORY.GetGameStateForObjectID(
				TacticalController.GetActiveUnitStateRef().ObjectID
			)
		);
		Inventory = Unit.Spawn(class'XGInventory', XGUnit(UnitState.GetVisualizer()).Owner);
		Inventory.PostInit();
		XGUnit(UnitState.GetVisualizer()).SetInventory(Inventory);
		UnitState.SyncVisualizer();
	}
}

exec function PS_DebugAnimSetList()
{
	local XComTacticalController TacticalController;
	local XComUnitPawn Pawn;
	local AnimSet Anim;
	local int Index;

	TacticalController = XComTacticalController(class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController());
	if (TacticalController != none)
	{
		Pawn = TacticalController.GetActivePawn();
		Index = 0;
		foreach Pawn.Mesh.AnimSets(Anim)
		{
			`LOG(GetFuncName() @ "Pawn.Mesh.AnimSets" @ Index @ Pathname(Anim), class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
			Index++;
		}
	}
}

exec function DebugLeftHandSocket(
	float X,
	float Y,
	float Z,
	int Roll,
	int Pitch,
	int Yaw
)
{
	local XComGameStateHistory History;
	local XComTacticalController TacticalController;
	local XComGameState_Unit UnitState;
	local XGWeapon WeaponVisualizer;
	local array<SkeletalMeshSocket> NewSockets;
	local vector					RelativeLocation;
	local rotator					RelativeRotation;
	local SkeletalMeshSocket		Socket;

	History = `XCOMHISTORY;

	TacticalController = XComTacticalController(class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController());
	if (TacticalController != none)
	{
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(TacticalController.GetActiveUnitStateRef().ObjectID));
		WeaponVisualizer = XGWeapon(UnitState.GetPrimaryWeapon().GetVisualizer());

		RelativeLocation.X = X;
		RelativeLocation.Y = Y;
		RelativeLocation.Z = Z;
		
		RelativeRotation.Roll = int(Roll * DegToUnrRot);
		RelativeRotation.Pitch = int(Pitch * DegToUnrRot);
		RelativeRotation.Yaw = int(Yaw * DegToUnrRot);

		Socket = new class'SkeletalMeshSocket';
		Socket.SocketName = 'left_hand';
		Socket.BoneName = 'root';
		Socket.RelativeLocation = RelativeLocation;
		Socket.RelativeRotation = RelativeRotation;
		NewSockets.AddItem(Socket);

		SkeletalMeshComponent(XComWeapon(WeaponVisualizer.m_kEntity).Mesh).AppendSockets(NewSockets, true);
	}
}

exec function CheckUniqueWeaponCategories()
{
	local X2ItemTemplateManager ItemTemplateManager;
	local name Category;

	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();

	foreach ItemTemplateManager.UniqueEquipCategories(Category)
	{
		`LOG('UniqueEquipCategories' @ Category, class'Helper'.static.ShouldLog(), 'TruePrimarySecondaries');
	}
}