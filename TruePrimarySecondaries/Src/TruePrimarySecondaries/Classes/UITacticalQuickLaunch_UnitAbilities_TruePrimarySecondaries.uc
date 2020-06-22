//-----------------------------------------------------------
//	Class:	UITacticalQuickLaunch_UnitAbilities_TruePrimarySecondaries
//	Author: Musashi
//	
//-----------------------------------------------------------


class UITacticalQuickLaunch_UnitAbilities_TruePrimarySecondaries extends UITacticalQuickLaunch_UnitAbilities config(GameData);
var private X2SoldierClassTemplate  SoldierClassTemplate;
var private array<SCATProgression>  arrProgression;
var private array<ClassAgnosticAbility>  AWCAbilities;
var private UITacticalQuickLaunch_UnitSlot OriginatingSlot;
var private array<name>     m_arrTemplateNames;

var private int         m_ypos;
var private UIPanel   m_kListContainer;
var private UIList   m_kList;
var private UIText m_kTitle;
var private UIButton m_kSaveButton;
var private UIButton m_kCancelButton;
var private UIScrollbar m_kScrollbar;
var private UIMask m_kMask;
var private array<UICheckbox>   m_arrAbilityCheckboxes;

var config array<SoldierClassAbilityType> ExtraAbilities;

simulated function InitAbilities(UITacticalQuickLaunch_UnitSlot Slot)
{
	local UIPanel kBG;

	// Create Container
	m_kListContainer = Spawn(class'UIPanel', self);
	m_kListContainer.InitPanel();

	// Create BG
	kBG = Spawn(class'UIBGBox', m_kListContainer).InitBG('BG', 0, 0, 1240, 620);

	// Center Container using BG
	m_kListContainer.CenterWithin(kBG);

	// Create Title text
	m_kTitle = Spawn(class'UIText', m_kListContainer);
	m_kTitle.InitText('', Slot.m_FirstName @ Slot.m_NickName @ Slot.m_LastName, true);
	m_kTitle.SetPosition(500, 10).SetWidth(kBG.width);

	m_kSaveButton = Spawn(class'UIButton', m_kListContainer).InitButton('', "Save & Close", SaveButton, eUIButtonStyle_BUTTON_WHEN_MOUSE);
	m_kSaveButton.SetPosition(10, 10);
	m_kCancelButton = Spawn(class'UIButton', m_kListContainer).InitButton('', "Cancel", CancelButton, eUIButtonStyle_BUTTON_WHEN_MOUSE);
	m_kCancelButton.SetPosition(10, 42);

	// Create list
	m_kList = Spawn(class'UIList', m_kListContainer);
	m_kList.InitList('List', 0, 75, 1200, 530);

	OriginatingSlot = Slot;
	SoldierClassTemplate = class'X2SoldierClassTemplateManager'.static.GetSoldierClassTemplateManager().FindSoldierClassTemplate(Slot.m_nSoldierClassTemplate);
	arrProgression = Slot.m_arrSoldierProgression;
	AWCAbilities = UITacticalQuickLaunch_UnitSlot_TruePrimarySecondaries(Slot).m_AWCAbilities;

	BuildSoldierAbilities();
}

simulated function BuildSoldierAbilities()
{
	local X2AbilityTemplateManager AbilityTemplateManager;
	local X2StrategyElementTemplateManager StrategyElementTemplateManager;
	local UICheckbox AbilityBox;
	local SCATProgression Progression;
	local string Display;
	local int i, j;
	local array<bool> arrEarned;
	local array<SoldierClassAbilityType> AbilityTree;
	local X2AbilityTemplate AbilityTemplate;
	local SoldierClassAbilityType CrossClassAbility;
	local array<SoldierClassAbilityType> ExtraCrossClassAbilities;
	local ClassAgnosticAbility ExtraAbility;
	local array<X2StrategyElementTemplate> Unlocks;
	local X2StrategyElementTemplate StrategyElement;
	local X2SoldierAbilityUnlockTemplate SoldierAbilityUnlock;

	m_arrTemplateNames.Length = 0;
	m_ypos = 0;
	AbilityTree = OriginatingSlot.m_arrAbilityTree;
	for (j = 0; j < AbilityTree.Length; ++j)
	{
		if (AbilityTree[j].AbilityName != '')
		{
			m_arrTemplateNames.AddItem(AbilityTree[j].AbilityName);
			arrEarned.AddItem(false);
				
			foreach arrProgression(Progression)
			{
				if (Progression.iRank == 0 && Progression.iBranch == j)
				{
					arrEarned[arrEarned.Length - 1] = true;
					break;
				}
			}
		}
	}

	// Add GTS abilities
	StrategyElementTemplateManager = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	Unlocks = StrategyElementTemplateManager.GetAllTemplatesOfClass(class'X2SoldierAbilityUnlockTemplate');
	foreach Unlocks(StrategyElement)
	{
		SoldierAbilityUnlock = X2SoldierAbilityUnlockTemplate(StrategyElement);

		if (!SoldierAbilityUnlock.bAllClasses)
		{
			if (SoldierAbilityUnlock.AllowedClasses.Find(SoldierClassTemplate.DataName) == INDEX_NONE)
				continue;
		}

		m_arrTemplateNames.AddItem(SoldierAbilityUnlock.AbilityName);
		arrEarned.AddItem(false);

		foreach AWCAbilities(ExtraAbility)
		{
			if (ExtraAbility.AbilityType.AbilityName == SoldierAbilityUnlock.AbilityName)
			{
				arrEarned[arrEarned.Length - 1] = true;
				break;
			}
		}
	}

	// Add AWC-only abilities
	ExtraCrossClassAbilities = class'X2SoldierClassTemplateManager'.default.ExtraCrossClassAbilities;
	foreach ExtraCrossClassAbilities(CrossClassAbility)
	{
		m_arrTemplateNames.AddItem(CrossClassAbility.AbilityName);
		arrEarned.AddItem(false);

		foreach AWCAbilities(ExtraAbility)
		{
			if (ExtraAbility.AbilityType.AbilityName == CrossClassAbility.AbilityName)
			{
				arrEarned[arrEarned.Length - 1] = true;
				break;
			}
		}
	}

	// Add extra abilities
	ExtraCrossClassAbilities = ExtraAbilities;
	foreach ExtraCrossClassAbilities(CrossClassAbility)
	{
		m_arrTemplateNames.AddItem(CrossClassAbility.AbilityName);
		arrEarned.AddItem(false);

		foreach AWCAbilities(ExtraAbility)
		{
			if (ExtraAbility.AbilityType.AbilityName == CrossClassAbility.AbilityName)
			{
				arrEarned[arrEarned.Length - 1] = true;
				break;
			}
		}
	}

	//`assert(arrEarned.Length == m_arrTemplateNames.Length);
	//  Now m_arrTemplateNames is filled out, so populate the UI controls
	AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	for (i = 0; i < m_arrTemplateNames.Length; ++i)
	{
		AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(m_arrTemplateNames[i]);
		if (AbilityTemplate == none)
			Display = "MISSING TEMPLATE!" @ "(" $ string(m_arrTemplateNames[i]) $ ")";
		else
			Display = AbilityTemplate.LocFriendlyName @ "(" $ string(m_arrTemplateNames[i]) $ ")";

		AbilityBox = Spawn(class'UICheckbox', m_kList.ItemContainer).InitCheckbox('', Display, arrEarned[i]);
		AbilityBox.SetTextStyle(class'UICheckbox'.const.STYLE_TEXT_ON_THE_RIGHT).SetHeight(32);
		m_arrAbilityCheckboxes.AddItem(AbilityBox);
		m_ypos += 32;
	}

	m_kList.RealizeItems();
	m_kList.RealizeList();

	//`assert(m_arrAbilityCheckboxes.Length == m_arrTemplateNames.Length);
}

simulated function SaveButton(UIButton kButton)
{
	local SCATProgression Progress;
	local array<SoldierClassAbilityType> AbilityTree;
	local int i, k, iChecked;
	local bool bProgressionAbility;
	local ClassAgnosticAbility ExtraAbility;
	local SoldierClassAbilityType CrossClassAbility;
	local array<SoldierClassAbilityType> ExtraCrossClassAbilities;

	arrProgression.Length = 0;
	AWCAbilities.Length = 0;
	iChecked = 0;

	for (i = 0; i < m_arrAbilityCheckboxes.Length; ++i)
	{
		if (m_arrAbilityCheckboxes[i].bChecked)
		{			
			iChecked += 1;
			bProgressionAbility = false;
			AbilityTree = OriginatingSlot.m_arrAbilityTree;
			for (k = 0; k < AbilityTree.Length; ++k)
			{
				if (AbilityTree[k].AbilityName == m_arrTemplateNames[i])
				{
					Progress.iRank = 0;
					Progress.iBranch = k;
					//  @TODO gameplay / UI - handle elite training on this screen
					arrProgression.AddItem(Progress);		
					bProgressionAbility = true;				
					break;
				}
			}

			if (!bProgressionAbility)
			{
				ExtraAbility.AbilityType.AbilityName = m_arrTemplateNames[i];
				ExtraAbility.iRank = 0;
				ExtraAbility.bUnlocked = true;

				ExtraCrossClassAbilities = class'X2SoldierClassTemplateManager'.default.ExtraCrossClassAbilities;
				foreach ExtraCrossClassAbilities(CrossClassAbility)
				{
					if (CrossClassAbility.AbilityName == m_arrTemplateNames[i])
					{
						ExtraAbility.AbilityType = CrossClassAbility;
						break;
					}
				}

				ExtraCrossClassAbilities = ExtraAbilities;
				foreach ExtraCrossClassAbilities(CrossClassAbility)
				{
					if (CrossClassAbility.AbilityName == m_arrTemplateNames[i])
					{
						ExtraAbility.AbilityType = CrossClassAbility;
						break;
					}
				}

				AWCAbilities.AddItem(ExtraAbility);
			}
		}
	}
	//`assert(iChecked == arrProgression.Length);
	OriginatingSlot.m_arrSoldierProgression = arrProgression;
	UITacticalQuickLaunch_UnitSlot_TruePrimarySecondaries(OriginatingSlot).m_AWCAbilities = AWCAbilities;

	Movie.Stack.Pop(self);
}

simulated function CancelButton(UIButton kButton)
{
	Movie.Stack.Pop(self);
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled;

	if ( !CheckInputIsReleaseOrDirectionRepeat(cmd, arg) )
		return false;

	bHandled = true;

	switch( cmd )
	{
		case class'UIUtilities_Input'.const.FXS_KEY_TAB:
		case class'UIUtilities_Input'.const.FXS_KEY_ENTER:
		case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR:
		case class'UIUtilities_Input'.const.FXS_BUTTON_A:
			SaveButton(none);
			break;
		case class'UIUtilities_Input'.const.FXS_BUTTON_B:
		case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE:
		case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN:
			CancelButton(none);
			break;
		default:
			bHandled = false;
			break;
	}

	return bHandled || super.OnUnrealCommand(cmd, arg);
}

defaultproperties
{
	bConsumeMouseEvents = true;
}