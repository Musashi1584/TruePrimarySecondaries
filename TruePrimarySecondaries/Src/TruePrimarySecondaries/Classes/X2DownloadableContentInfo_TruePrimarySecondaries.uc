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
var config array<name> DontOverrideMeleeCategories;
var config array<WeaponConfig> IndividualWeaponConfig;

var array<name> SkipWeapons;

var config array<int> MIDSHORT_CONVENTIONAL_RANGE;
var config int PRIMARY_PISTOLS_CLIP_SIZE;
var config int PRIMARY_SAWEDOFF_CLIP_SIZE;
var config int PRIMARY_PISTOLS_DAMAGE_MODIFER;
var config bool bPrimaryPistolsInfiniteAmmo;
var config bool bUseVisualPistolUpgrades;
var config bool bLog;
var config bool bLogAnimations;
var config bool bUseSlomoInAnimations;

static function bool CanAddItemToInventory_CH_Improved(out int bCanAddItem, const EInventorySlot Slot, const X2ItemTemplate ItemTemplate, int Quantity, XComGameState_Unit UnitState, optional XComGameState CheckGameState, optional out string DisabledReason, optional XComGameState_Item ItemState)
{
	local bool bEvaluate;

	if (IsSecondaryPistolItem(ItemState, true) || IsSecondaryMeleeItem(ItemState, true))
	{
		bCanAddItem = 1;
		DisabledReason = "";
		bEvaluate = true;
	}

	if(CheckGameState == none)
		return !bEvaluate;

	return bEvaluate;

}

static function MatineeGetPawnFromSaveData(XComUnitPawn UnitPawn, XComGameState_Unit UnitState, XComGameState SearchState)
{
	class'ShellMapMatinee'.static.PatchAllLoadedMatinees(UnitPawn, UnitState, SearchState);
}

static event OnPostTemplatesCreated()
{
	`LOG(default.class @ GetFuncName(),, 'DLCSort');
	ScriptTrace();
	PatchAbilityTemplates();
	AddAttachments();
	//AddPrimarySecondaries();
	//CheckUniqueWeaponCategories();
	if (default.bUseVisualPistolUpgrades)
	{
		ReplacePistolArchetypes();
	}
	OnPostCharacterTemplatesCreated();
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

static function PatchWeaponTemplates()
{
	local X2ItemTemplateManager ItemTemplateManager;
	local array<X2DataTemplate> DifficultyVariants;
	local array<name> TemplateNames;
	local name TemplateName;
	local X2DataTemplate ItemTemplate;
	local X2WeaponTemplate WeaponTemplate;
	local array<name> EnemyWeaponTemplates;

	EnemyWeaponTemplates = GetEnemyWeaponTemplates();
	
	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();


	ItemTemplateManager.GetTemplateNames(TemplateNames);

	foreach TemplateNames(TemplateName)
	{
		if (default.SkipWeapons.Find(TemplateName) != INDEX_NONE) continue;
		if (EnemyWeaponTemplates.Find(TemplateName) != INDEX_NONE) continue;

		ItemTemplateManager.FindDataTemplateAllDifficulties(TemplateName, DifficultyVariants);
		// Iterate over all variants
		
		foreach DifficultyVariants(ItemTemplate)
		{
			WeaponTemplate = X2WeaponTemplate(ItemTemplate);

			if (WeaponTemplate == none)
				continue;

			if (IsSecondaryPistolWeaponTemplate(WeaponTemplate))
			{
				if (WeaponTemplate.WeaponCat == 'sawedoffshotgun')
				{
					WeaponTemplate.iClipSize = default.PRIMARY_SAWEDOFF_CLIP_SIZE;
					//WeaponTemplate.Abilities.AddItem('Reload');
				}
				else
				{
					WeaponTemplate.iClipSize = default.PRIMARY_PISTOLS_CLIP_SIZE;
				}
			}
		}
	}
}

static function array<name> GetEnemyWeaponTemplates()
{
	local X2CharacterTemplateManager CharacterTemplateMgr;
	local X2CharacterTemplate Template;
	local array<X2DataTemplate> DataTemplates;
	local int Index;
	local array<name> TemplateNames;
	local name TemplateName;
	local X2ItemTemplateManager ItemTemplateManager;
	local InventoryLoadout Loadout;
	local InventoryLoadoutItem LoadoutItem;
	local X2WeaponTemplate WeaponTemplate;
	local array<name> EnemyWeaponTemplates;

	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();

	CharacterTemplateMgr = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
	CharacterTemplateMgr.GetTemplateNames(TemplateNames);

	foreach TemplateNames(TemplateName)
	{
		CharacterTemplateMgr.FindDataTemplateAllDifficulties(TemplateName, DataTemplates);
		for (Index = 0; Index < DataTemplates.Length; ++Index)
		{
			Template = X2CharacterTemplate(DataTemplates[Index]);
			
			if (Template == none) {continue;}
			if (Template.bIsSoldier) {continue;}
			if (Template.bIsCosmetic) {continue;}
			if (Template.bNeverSelectable) {continue;}
			if (Template.bIsScientist) {continue;}
			if (Template.bIsResistanceHero) {continue;}
			
			if (Template.bIsCivilian && !Template.bIsHostileCivilian) {continue;}
			if (Template.CharacterGroupName == 'CivilianMilitia') {continue;}


			foreach ItemTemplateManager.Loadouts(Loadout)
			{
				if(Loadout.LoadoutName == Template.DefaultLoadout)
				{
					foreach Loadout.Items(LoadoutItem)
					{
						WeaponTemplate = X2WeaponTemplate(ItemTemplateManager.FindItemTemplate(LoadoutItem.Item));

						if(WeaponTemplate != none && 
						   EnemyWeaponTemplates.Find(WeaponTemplate.DataName) == INDEX_NONE &&
						   (IsSecondaryPistolWeaponTemplate(WeaponTemplate) || IsSecondaryMeleeWeaponTemplate(WeaponTemplate))
						)
						{
							EnemyWeaponTemplates.AddItem(WeaponTemplate.DataName);
							`LOG(GetFuncName() @ WeaponTemplate.DataName, class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, 'TruePrimarySecondaries');
						}
					}
				}
			}
		}
	}

	return EnemyWeaponTemplates;
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
			`LOG("Attachment for "@TemplateName @Attachment.AttachSocket @Attachment.UIArmoryCameraPointTag @Attachment.MeshName @Attachment.ProjectileName @Attachment.MatchWeaponTemplate @Attachment.AttachToPawn @Attachment.IconName @Attachment.InventoryIconName @Attachment.InventoryCategoryIcon, class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, 'TruePrimarySecondaries');
		}
	}
}

static function CheckUniqueWeaponCategories()
{
	local X2ItemTemplateManager ItemTemplateManager;
	local name Category;

	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();

	foreach ItemTemplateManager.UniqueEquipCategories(Category)
	{
		`LOG('UniqueEquipCategories' @ Category, class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, 'TruePrimarySecondaries');
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
				`Log("Patching " @ ItemTemplate.DataName @ "with" @ Replacement.GameArchetype @ "and" @ Replacement.NumUpgradeSlots @ "upgrade slots", class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, 'TruePrimarySecondaries');
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

				`LOG("Patching Template" @ AbilityAmmoCost.Ability @ "adding" @ AbilityAmmoCost.Ammo @ "ammo cost", class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, 'TruePrimarySecondaries');
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
				`LOG("Patching Template" @ TemplateName @ "adding QuickDrawPrimary and Quickdraw to DoNotConsumeAllSoldierAbilities", class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, 'TruePrimarySecondaries');
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
				`LOG("Patching SwordSlice ability template so that it can be used even while disoriented if attached to primary melee weapon.", class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, 'TruePrimarySecondaries');
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
	//local XComGameState_Item SecondaryItemState;
	//local array<SoldierClassAbilityType> EarnedSoldierAbilities;
	local int Index;

	`LOG(GetFuncName(), class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, 'TruePrimarySecondaries');
	
	// Associate all melee abilities with the primary weapon if primary melee weapons are equipped
	if (UnitState.IsSoldier() && !HasDualMeleeEquipped(UnitState) && HasPrimaryMeleeEquipped(UnitState))
	{
		for(Index = 0; Index < SetupData.Length; Index++)
		{
			if (SetupData[Index].Template != none && SetupData[Index].Template.IsMelee() && SetupData[Index].TemplateName != 'DualSlashSecondary')
			{
				SetupData[Index].SourceWeaponRef = UnitState.GetPrimaryWeapon().GetReference();
				`LOG(GetFuncName() @ UnitState.GetFullName() @ "setting" @ SetupData[Index].TemplateName @ "to" @ UnitState.GetPrimaryWeapon().GetMyTemplateName(), class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, 'TruePrimarySecondaries');
			}
		}
	}

	// Associate all pistol abilities with the primary weapon if primary pistol weapons are equipped
	//if (UnitState.IsSoldier() && !HasDualPistolEquipped(UnitState) && HasPrimaryPistol(UnitState))
	//{
	//	EarnedSoldierAbilities = UnitState.GetEarnedSoldierAbilities();
	//	SecondaryItemState = UnitState.GetSecondaryWeapon();
	//	for(Index = 0; Index <= SetupData.Length; Index++)
	//	{
	//		if (!SetupData[Index].Template.IsMelee() &&
	//			!SetupData[Index].Template.IsPassive &&
	//			EarnedSoldierAbilities.Find('AbilityName', SetupData[Index].TemplateName) != INDEX_NONE)
	//		{
	//			if (SecondaryItemState.ObjectID == SetupData[Index].SourceWeaponRef.ObjectID)
	//			{
	//				SetupData[Index].SourceWeaponRef = UnitState.GetPrimaryWeapon().GetReference();
	//				`LOG(GetFuncName() @ UnitState.GetFullName() @ "setting" @ SetupData[Index].TemplateName @ "to" @ UnitState.GetPrimaryWeapon().GetMyTemplateName(), class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, 'TruePrimarySecondaries');
	//			}
	//		}
	//	}
	//}
}

static function UpdateWeaponAttachments(out array<WeaponAttachment> Attachments, XComGameState_Item ItemState)
{
	local XComGameState_Unit UnitState;
	local int i;
	local name NewSocket;
	local vector Scale;
	local WeaponConfig IndividualWeaponConfigLocal;

	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ItemState.OwnerStateObject.ObjectID));

	if(UnitState != none && HasDualMeleeEquipped(UnitState))
	{
		return;
	}

	if (default.WeaponCategoryBlacklist.Find(X2WeaponTemplate(ItemState.GetMyTemplate()).WeaponCat) != INDEX_NONE)
	{
		return;
	}

	FindIndividualWeaponConfig(ItemState.GetMyTemplateName(), IndividualWeaponConfigLocal);
	if (!IndividualWeaponConfigLocal.bUseSideSheaths)
	{
		NewSocket = 'Sheath';
	}

	if(NewSocket == 'None' && IsPrimaryMeleeItem(ItemState))
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
				`LOG(GetFuncName() @ UnitState.GetFullName() @ ItemState.GetMyTemplateName() @ NewSocket @ "bUseSideSheaths" @ IndividualWeaponConfigLocal.bUseSideSheaths, class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, 'TruePrimarySecondaries');
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

	FindIndividualWeaponConfig(WeaponTemplate.DataName, IndividualWeaponConfigLocal);
	
	if (IndividualWeaponConfigLocal.bKeepPawnWeaponAnimation)
	{
		return;
	}

	//`LOG(GetFuncName() @ "Spawn" @ WeaponArchetype @ ItemState.GetMyTemplateName() @ Weapon.CustomUnitPawnAnimsets.Length, class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, 'TruePrimarySecondaries');

	if (IndividualWeaponConfigLocal.bUseEmptyHandSoldierAnimations)
	{
		if (IsPrimaryMeleeItem(ItemState) && HasPrimaryMeleeEquipped(UnitState))
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
			
		if (IsPrimaryPistolItem(ItemState) && HasPrimaryPistolEquipped(UnitState))
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
		if (IsPrimaryMeleeItem(ItemState) && HasPrimaryMeleeEquipped(UnitState))
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
		else if (IsPrimaryPistolItem(ItemState) && HasPrimaryPistolEquipped(UnitState))
		{
			Weapon.DefaultSocket = 'R_Hand';

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
		else if (IsSecondaryMeleeItem(ItemState) && HasPrimaryPistolEquipped(UnitState))
		{
			AnimSetPaths.AddItem("TruePrimarySecondaries_Pistol.Anims.AS_SecondarySword");
		}
		else if (IsSecondaryPistolItem(ItemState) && WeaponTemplate.WeaponCat == 'sidearm')
		{
			// Patching the default autopistol template here so other soldiers than templars can use it
			AnimSetPaths.AddItem("TruePrimarySecondaries_AutoPistol.Anims.AS_AutoPistol_Secondary");
		}
		if (IsSecondaryPistolItem(ItemState) && HasPrimaryMeleeEquipped(UnitState))
		{
			bResetAnimsets = false;
			AnimSetPaths.AddItem("TruePrimarySecondaries_PrimaryMelee.Anims.AS_SecondaryPistol");
		}

		if (default.DontOverrideMeleeCategories.Find(WeaponTemplate.WeaponCat) != INDEX_NONE)
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
				`LOG(GetFuncName() @ "----> Adding" @ AnimSetPath @ "to CustomUnitPawnAnimsets of" @ WeaponTemplate.DataName @ "Weapon.DefaultSocket" @ Weapon.DefaultSocket, class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, 'TruePrimarySecondaries');
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
			//	`LOG(Pathname(Anim), class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, 'TruePrimarySecondaries');
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

	if (HasPrimaryPistolEquipped(UnitState))
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

	//`LOG(default.class @ GetFuncName(),, 'DLCSort');
	
	if (!AllowUnitState(UnitState))
	{
		return;
	}

	CustomAnimSets.AddItem(AnimSet(`CONTENT.RequestGameArchetype("TruePrimarySecondaries_Target.Anims.AS_Advent")));
	
	if (HasPrimaryMeleeOrPistolEquipped(UnitState))
	{
		FindIndividualWeaponConfig(UnitState.GetPrimaryWeapon().GetMyTemplateName(), IndividualWeaponConfigLocal);
		
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

		if (HasPrimaryPistolEquipped(UnitState))
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
		else if (HasPrimaryMeleeEquipped(UnitState))
		{
			AnimSetPath = "TruePrimarySecondaries_PrimaryMelee.Anims.AS_Soldier" $ FemaleSuffix;

			CustomAnimSets.AddItem(AnimSet(`CONTENT.RequestGameArchetype("TruePrimarySecondaries_PrimaryMelee.Anims.AS_Armory" $ FemaleSuffix)));
		}
		

		if (AnimSetPath != "")
		{
			//CustomAnimSets.AddItem(AnimSet(`CONTENT.RequestGameArchetype(AnimSetPath)));

			AddAnimSet(Pawn, AnimSet(`CONTENT.RequestGameArchetype(AnimSetPath)), Pawn.DefaultUnitPawnAnimsets.Length);

			`LOG(GetFuncName() @ "Adding" @ AnimSetPath @ "to" @ UnitState.GetFullName(), class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLogAnimations, 'TruePrimarySecondaries');
		}
		
		Index = 0;
		foreach Pawn.Mesh.AnimSets(Anim)
		{
			`LOG(GetFuncName() @ "Pawn.Mesh.AnimSets" @ Index @ Pathname(Anim), class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLogAnimations, 'TruePrimarySecondaries');
			Index++;
		}

		Index = 0;
		foreach Pawn.DefaultUnitPawnAnimsets(Anim)
		{
			`LOG(GetFuncName() @ "DefaultUnitPawnAnimsets" @ Index @ Pathname(Anim) @ Anim.ObjectArchetype @ Anim.Name, class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLogAnimations, 'TruePrimarySecondaries');
			Index++;
		}

		`LOG(GetFuncName() @ "--------------------------------------------------------------", class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLogAnimations, 'TruePrimarySecondaries');

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
		`LOG(GetFuncName() @ "adding" @ AnimSetToAdd @ "at Index" @ Index, class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLogAnimations, 'TruePrimarySecondaries');
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

	if (!HasPrimaryMeleeOrPistolEquipped(UnitState))
	{
		return;
	}

	if (default.WeaponCategoryBlacklist.Find(Template.WeaponCat) != INDEX_NONE)
	{
		return;
	}

	FindIndividualWeaponConfig(Template.DataName, IndividualWeaponConfigLocal);
	if (IndividualWeaponConfigLocal.bUseEmptyHandSoldierAnimations)
	{
		return;
	}

	if (IsPrimaryPistolItem(ItemState) || IsPrimaryMeleeItem(ItemState))
	{
		SkeletalMeshComponent(Weapon.Mesh).GetBoneNames(BoneNames);
		foreach BoneNames(Bone)
		{
			`LOG(GetFuncName() @ ItemState.GetMyTemplateName() @ "Bone" @ Bone, class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, 'TruePrimarySecondaries');
			if (Instr(Locs(Bone), "root") != INDEX_NONE)
			{
				BoneNameToUse = Bone;
				break;
			}
		}

		if (BoneNameToUse == 'None')
		{
			BoneNameToUse = SkeletalMeshComponent(Weapon.Mesh).GetBoneName(0);
			`LOG(GetFuncName() @ ItemState.GetMyTemplateName() @ "No root Bone found. Using bone on index 0" @ BoneNameToUse, class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, 'TruePrimarySecondaries');
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

			`LOG(GetFuncName() @ ItemState.GetMyTemplateName() @ "Overriding" @ Socket.SocketName @ "socket on" @ Bone @ `showvar(RelativeLocation) @ `showvar(RelativeRotation), class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, 'TruePrimarySecondaries');
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

			`LOG(GetFuncName() @ ItemState.GetMyTemplateName() @ "Overriding" @ Socket.SocketName @ "socket on" @ Bone @ `showvar(RelativeLocation) @ `showvar(RelativeRotation), class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, 'TruePrimarySecondaries');
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

			`LOG(GetFuncName() @ ItemState.GetMyTemplateName() @ "Overriding" @ Socket.SocketName @ "socket on" @ Bone @ `showvar(RelativeLocation) @ `showvar(RelativeRotation), class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, 'TruePrimarySecondaries');
		}
	}
}

static function string DLCAppendSockets(XComUnitPawn Pawn)
{
	local XComHumanPawn HumanPawn;
	local XComGameState_Unit UnitState;

	//`LOG("DLCAppendSockets" @ Pawn,, 'DualWieldMelee');

	HumanPawn = XComHumanPawn(Pawn);
	if (HumanPawn == none) { return ""; }

	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(HumanPawn.ObjectID));

	if (!AllowUnitState(UnitState)) { return ""; }

	if (HasPrimaryMeleeEquipped(UnitState))
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

	if (HasPrimaryPistolEquipped(UnitState))
	{
		return "TruePrimarySecondaries_Sockets.Meshes.PrimaryPistol_SocketsOverride";
	}

	return "";
}

static function bool HasPrimaryMeleeOrPistolEquipped(XComGameState_Unit UnitState, optional XComGameState CheckGameState)
{
	return HasPrimaryMeleeEquipped(UnitState, CheckGameState) || HasPrimaryPistolEquipped(UnitState, CheckGameState);
}

static function bool HasMeleeAndPistolEquipped(XComGameState_Unit UnitState, optional XComGameState CheckGameState)
{
	return (HasPrimaryMeleeEquipped(UnitState, CheckGameState) && HasSecondaryPistolEquipped(UnitState, CheckGameState)) ||
		   (HasPrimaryPistolEquipped(UnitState, CheckGameState) && HasSecondaryMeleeEquipped(UnitState, CheckGameState));
}

static function bool HasPrimaryMeleeEquipped(XComGameState_Unit UnitState, optional XComGameState CheckGameState)
{
	local XComGameState_Item PrimaryWeapon;

	if (UnitState == none)
	{
		return false;
	}

	PrimaryWeapon = UnitState.GetItemInSlot(eInvSlot_PrimaryWeapon, CheckGameState);

	return PrimaryWeapon != none && IsPrimaryMeleeItem(PrimaryWeapon) &&
		!HasDualMeleeEquipped(UnitState, CheckGameState) &&
		!HasShieldEquipped(UnitState, CheckGameState);
}

static function bool HasPrimaryPistolEquipped(XComGameState_Unit UnitState, optional XComGameState CheckGameState)
{
	local XComGameState_Item PrimaryWeapon;

	if (UnitState == none)
	{
		return false;
	}

	PrimaryWeapon = UnitState.GetItemInSlot(eInvSlot_PrimaryWeapon, CheckGameState);

	return PrimaryWeapon != none && IsPrimaryPistolItem(PrimaryWeapon) &&
		!HasDualPistolEquipped(UnitState, CheckGameState) &&
		!HasShieldEquipped(UnitState, CheckGameState);
}

static function bool HasSecondaryMeleeEquipped(XComGameState_Unit UnitState, optional XComGameState CheckGameState)
{
	local XComGameState_Item SecondaryWeapon;

	if (UnitState == none)
	{
		return false;
	}

	SecondaryWeapon = UnitState.GetItemInSlot(eInvSlot_SecondaryWeapon, CheckGameState);

	return SecondaryWeapon != none && IsSecondaryMeleeItem(SecondaryWeapon);
}

static function bool HasSecondaryPistolEquipped(XComGameState_Unit UnitState, optional XComGameState CheckGameState)
{
	local XComGameState_Item SecondaryWeapon;

	if (UnitState == none)
	{
		return false;
	}

	SecondaryWeapon = UnitState.GetItemInSlot(eInvSlot_SecondaryWeapon, CheckGameState);

	return SecondaryWeapon != none && IsSecondaryPistolItem(SecondaryWeapon);
}

static function bool HasShieldEquipped(XComGameState_Unit UnitState, optional XComGameState CheckGameState)
{
	local XComGameState_Item SecondaryWeapon;
	local X2WeaponTemplate SecondaryWeaponTemplate;

	if (UnitState == none)
	{
		return false;
	}

	SecondaryWeapon = UnitState.GetItemInSlot(eInvSlot_SecondaryWeapon, CheckGameState);
	if (SecondaryWeapon != none)
	{
		SecondaryWeaponTemplate = X2WeaponTemplate(SecondaryWeapon.GetMyTemplate());
		return SecondaryWeaponTemplate != none && SecondaryWeaponTemplate.WeaponCat == 'shield' && default.SkipWeapons.Find(SecondaryWeaponTemplate.DataName) == INDEX_NONE;
	}
	return false;
}

static function bool HasDualPistolEquipped(XComGameState_Unit UnitState, optional XComGameState CheckGameState)
{
	local XComGameState_Item PrimaryWeapon, SecondaryWeapon;

	if (UnitState == none)
	{
		return false;
	}

	if (UnitState == none)
	{
		return false;
	}

	PrimaryWeapon = UnitState.GetItemInSlot(eInvSlot_PrimaryWeapon, CheckGameState);
	SecondaryWeapon = UnitState.GetItemInSlot(eInvSlot_SecondaryWeapon, CheckGameState);

	return PrimaryWeapon != none && IsPrimaryPistolItem(PrimaryWeapon) &&
		SecondaryWeapon != none && IsSecondaryPistolItem(SecondaryWeapon);
}

static function bool HasDualMeleeEquipped(XComGameState_Unit UnitState, optional XComGameState CheckGameState)
{
	local XComGameState_Item PrimaryWeapon, SecondaryWeapon;

	if (UnitState == none)
	{
		return false;
	}

	PrimaryWeapon = UnitState.GetItemInSlot(eInvSlot_PrimaryWeapon, CheckGameState);
	SecondaryWeapon = UnitState.GetItemInSlot(eInvSlot_SecondaryWeapon, CheckGameState);

	return PrimaryWeapon != none && IsPrimaryMeleeItem(PrimaryWeapon) &&
		SecondaryWeapon != none && IsSecondaryMeleeItem(SecondaryWeapon);
}

static function bool IsPrimaryPistolItem(XComGameState_Item ItemState)
{
	local X2WeaponTemplate WeaponTemplate;

	if (ItemState == none)
	{
		return false;
	}

	WeaponTemplate = X2WeaponTemplate(ItemState.GetMyTemplate());

	return WeaponTemplate != none &&
		default.SkipWeapons.Find(WeaponTemplate.DataName) == INDEX_NONE &&
		ItemState.InventorySlot == eInvSlot_PrimaryWeapon &&
		default.PistolCategories.Find(WeaponTemplate.WeaponCat) != INDEX_NONE &&
		default.WeaponCategoryBlacklist.Find(WeaponTemplate.WeaponCat) == INDEX_NONE;
}

static function bool IsPrimaryMeleeItem(XComGameState_Item ItemState)
{
	local X2WeaponTemplate WeaponTemplate;

	if (ItemState == none)
	{
		return false;
	}

	WeaponTemplate = X2WeaponTemplate(ItemState.GetMyTemplate());

	return WeaponTemplate != none &&
		default.SkipWeapons.Find(WeaponTemplate.DataName) == INDEX_NONE &&
		ItemState.InventorySlot == eInvSlot_PrimaryWeapon &&
		WeaponTemplate.iRange == 0 &&
		WeaponTemplate.WeaponCat != 'wristblade' &&
		WeaponTemplate.WeaponCat != 'shield' &&
		WeaponTemplate.WeaponCat != 'gauntlet' &&
		default.WeaponCategoryBlacklist.Find(WeaponTemplate.WeaponCat) == INDEX_NONE;
}

static function bool IsSecondaryPistolItem(XComGameState_Item ItemState, optional bool bUseTemplateForSlotCheck = false)
{
	local X2WeaponTemplate WeaponTemplate;
	local bool bIsSecondarySlot;

	if (ItemState == none)
	{
		return false;
	}

	WeaponTemplate = X2WeaponTemplate(ItemState.GetMyTemplate());

	if (WeaponTemplate == none)
	{
		return false;
	}

	if (bUseTemplateForSlotCheck)
	{
		bIsSecondarySlot = WeaponTemplate.InventorySlot == eInvSlot_SecondaryWeapon;
	}
	else
	{
		bIsSecondarySlot = ItemState.InventorySlot == eInvSlot_SecondaryWeapon;
	}

	return default.SkipWeapons.Find(WeaponTemplate.DataName) == INDEX_NONE &&
		bIsSecondarySlot &&
		default.PistolCategories.Find(WeaponTemplate.WeaponCat) != INDEX_NONE &&
		InStr(WeaponTemplate.DataName, "_TMP_") == INDEX_NONE && // Filter RF Templar Weapons
		default.WeaponCategoryBlacklist.Find(WeaponTemplate.WeaponCat) == INDEX_NONE;
}

static function bool IsSecondaryMeleeItem(XComGameState_Item ItemState, optional bool bUseTemplateForSlotCheck = false)
{
	local X2WeaponTemplate WeaponTemplate;
	local bool bIsSecondarySlot;

	if (ItemState == none)
	{
		return false;
	}

	WeaponTemplate = X2WeaponTemplate(ItemState.GetMyTemplate());

	if (WeaponTemplate == none)
	{
		return false;
	}

	if (bUseTemplateForSlotCheck)
	{
		bIsSecondarySlot = WeaponTemplate.InventorySlot == eInvSlot_SecondaryWeapon;
	}
	else
	{
		bIsSecondarySlot = ItemState.InventorySlot == eInvSlot_SecondaryWeapon;
	}

	return default.SkipWeapons.Find(WeaponTemplate.DataName) == INDEX_NONE &&
		bIsSecondarySlot &&
		WeaponTemplate.iRange == 0 &&
		WeaponTemplate.WeaponCat != 'wristblade' &&
		WeaponTemplate.WeaponCat != 'shield' &&
		WeaponTemplate.WeaponCat != 'gauntlet' &&
		default.WeaponCategoryBlacklist.Find(WeaponTemplate.WeaponCat) == INDEX_NONE;
}

static function bool IsSecondaryMeleeWeaponTemplate(X2WeaponTemplate WeaponTemplate)
{
	return WeaponTemplate != none &&
		default.SkipWeapons.Find(WeaponTemplate.DataName) == INDEX_NONE &&
		WeaponTemplate.InventorySlot == eInvSlot_SecondaryWeapon &&
		WeaponTemplate.iRange == 0 &&
		WeaponTemplate.WeaponCat != 'wristblade' &&
		WeaponTemplate.WeaponCat != 'shield' &&
		WeaponTemplate.WeaponCat != 'gauntlet' &&
		default.WeaponCategoryBlacklist.Find(WeaponTemplate.WeaponCat) == INDEX_NONE;
}

static function bool IsSecondaryPistolWeaponTemplate(X2WeaponTemplate WeaponTemplate)
{
	return WeaponTemplate != none &&
		default.SkipWeapons.Find(WeaponTemplate.DataName) == INDEX_NONE &&
		WeaponTemplate.InventorySlot == eInvSlot_SecondaryWeapon &&
		default.PistolCategories.Find(WeaponTemplate.WeaponCat) != INDEX_NONE &&
		InStr(WeaponTemplate.DataName, "_TMP_") == INDEX_NONE && // Filter RF Templar Weapons
		default.WeaponCategoryBlacklist.Find(WeaponTemplate.WeaponCat) == INDEX_NONE;
}


static function bool FindIndividualWeaponConfig(name TemplateName, out WeaponConfig FoundWeaponConfig)
{
	local int Index;

	Index = default.IndividualWeaponConfig.Find('TemplateName', TemplateName);
	if (Index != INDEX_NONE)
	{
		FoundWeaponConfig = default.IndividualWeaponConfig[Index];
		return true;
	}

	return false;
}


static function bool AllowUnitState(XComGameState_Unit UnitState)
{
	return UnitState != none && (UnitState.IsSoldier() || (UnitState.IsAdvent() && (HasPrimaryPistolEquipped(UnitState) || HasDualPistolEquipped(UnitState))));
}

static function bool IsLW2Installed()
{
	return IsModInstalled('X2DownloadableContentInfo_LW_Overhaul');
}

static function bool IsModInstalled(name X2DCLName)
{
	local X2DownloadableContentInfo Mod;
	foreach `ONLINEEVENTMGR.m_cachedDLCInfos (Mod)
	{
		if (Mod.Class.Name == X2DCLName)
		{
			`Log("Mod installed:" @ Mod.Class, class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog);
			return true;
		}
	}

	return false;
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
			`LOG(GetFuncName() @ "Pawn.Mesh.AnimSets" @ Index @ Pathname(Anim), class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, 'TruePrimarySecondaries');
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
