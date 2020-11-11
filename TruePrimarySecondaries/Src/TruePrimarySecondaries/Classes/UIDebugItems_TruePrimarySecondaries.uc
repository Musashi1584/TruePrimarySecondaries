//-----------------------------------------------------------
//	Class:	UIDebugItems_TruePrimarySecondaries
//	Author: Musashi
//	
//-----------------------------------------------------------


class UIDebugItems_TruePrimarySecondaries extends UIDebugItems;

var UIPanel GeneralContainerR;
var UIBGBox BackgroundPanelR;
var UIButton CloseButtonR;
var UIButton GiveItemButtonR;
var UIButton GiveUpgradeButtonR;
var UIButton ClearUpgradesButtonR;
var UIDropdown TypeDropdownR;
var UIDropdown ItemDropdownR;
var UIDropdown UpgradeDropdownR;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{	
	super(UIScreen).InitScreen(InitController, InitMovie, InitName);

	bStoredMouseIsActive = Movie.IsMouseActive();
	Movie.ActivateMouse();

	StoredInputState = XComTacticalController(GetALocalPlayerController()).GetInputState();
	XComTacticalController(GetALocalPlayerController()).SetInputState('InTransition');

	GeneralContainerR = Spawn(class'UIPanel', self);
	GeneralContainerR.SetPosition(0, 0);
	//GeneralContainer.SetAnchor(class'UIUtilities'.const.ANCHOR_TOP_LEFT);	

	BackgroundPanelR = Spawn(class'UIBGBox', self);
	BackgroundPanelR.InitBG('', 10, 300, 1280, 400);
	
	UpgradeDropdownR = Spawn(class'UIDropdown', self).InitDropdown('', "", DropdownSelectionChange);
	UpgradeDropdownR.SetPosition(50, 520);	
	PopulateUpgradeDropdown(UpgradeDropdownR);

	ItemDropdownR = Spawn(class'UIDropdown', self).InitDropdown('', "", DropdownSelectionChange);
	ItemDropdownR.SetPosition(50, 460);		
	PopulateItemDropdown(ItemDropdownR, eInvSlot_PrimaryWeapon);	

	TypeDropdownR = Spawn(class'UIDropdown', self).InitDropdown('', "", DropdownSelectionChange);
	TypeDropdownR.SetPosition(50, 400);	
	PopulateTypeDropdown(TypeDropdownR);	

	// Close Button
	CloseButtonR = Spawn(class'UIButton', self);
	CloseButtonR.InitButton('closeButton', "CLOSE", OnCloseButtonClicked, eUIButtonStyle_HOTLINK_BUTTON);		
	CloseButtonR.SetPosition(50, 310);

	GiveItemButtonR = Spawn(class'UIButton', self);
	GiveItemButtonR.InitButton('giveItemButton', "GIVE ITEM", OnGiveItemButtonClicked, eUIButtonStyle_HOTLINK_BUTTON);		
	GiveItemButtonR.SetPosition(400, 450);	

	GiveUpgradeButtonR = Spawn(class'UIButton', self);
	GiveUpgradeButtonR.InitButton('giveUpgradeButton', "GIVE UPGRADE", OnGiveUpgradeButtonClicked, eUIButtonStyle_HOTLINK_BUTTON);		
	GiveUpgradeButtonR.SetPosition(400, 510);	

	ClearUpgradesButtonR = Spawn(class'UIButton', self);
	ClearUpgradesButtonR.InitButton('clearUpgradeButton', "CLEAR UPGRADES", OnClearUpgradesButtonClicked, eUIButtonStyle_HOTLINK_BUTTON);		
	ClearUpgradesButtonR.SetPosition(400, 560);	
}


simulated function ApplyWeaponUpgradeAbilities(XComGameState NewGameState, XComGameState_Unit UnitState, XComGameState_Item WeaponState, X2WeaponUpgradeTemplate UpgradeTemplate)
{
	local X2AbilityTemplate AbilityTemplate;
	local X2AbilityTemplateManager AbilityMgr;
	local name AbilityName;

	AbilityMgr = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();

	foreach UpgradeTemplate.BonusAbilities(AbilityName)
	{
		AbilityTemplate = AbilityMgr.FindAbilityTemplate(AbilityName);

		if (AbilityTemplate != none)
		{
			`TACTICALRULES.InitAbilityForUnit(AbilityTemplate, UnitState, NewGameState, WeaponState.GetReference());
		}
	}
}

simulated function OnGiveUpgrade()
{	
	local XComGameStateHistory History;
	local XComGameState_Item WeaponStateObject;	
	local XComGameStateContext_ChangeContainer ChangeContainer;
	local XComGameState ChangeState;
	local X2WeaponUpgradeTemplate UpgradeTemplate;
	local StateObjectReference ActiveUnitRef;
	local XComGameState_Unit UnitState;
	local XGWeapon WeaponVisualizer;
	local XGUnit UnitVisualizer;	

	History = `XCOMHISTORY;
	
	ActiveUnitRef = XComTacticalController(PC).GetActiveUnitStateRef();
	if( ActiveUnitRef.ObjectID > 0 && UpgradeDropdownR.SelectedItem > -1 )
	{
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(ActiveUnitRef.ObjectID));
		WeaponStateObject = UnitState.GetItemInSlot( eInvSlot_PrimaryWeapon );	
		
		UpgradeTemplate = X2WeaponUpgradeTemplate(class'X2ItemTemplateManager'.static.GetItemTemplateManager().FindItemTemplate(name(UpgradeDropdownR.GetSelectedItemData())));
		if (bClearUpgradeMode || (UpgradeTemplate != none && UpgradeTemplate.CanApplyUpgradeToWeapon(WeaponStateObject)))
		{
			// Create change context
			ChangeContainer = class'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("Weapon Upgrade");
			ChangeState = History.CreateNewGameState(true, ChangeContainer);

			// Apply upgrade to weapon
			WeaponStateObject = XComGameState_Item(ChangeState.ModifyStateObject(class'XComGameState_Item', WeaponStateObject.ObjectID));
			if( bClearUpgradeMode )
			{
				WeaponStateObject.WipeUpgradeTemplates();
			}
			else
			{
				WeaponStateObject.ApplyWeaponUpgradeTemplate(UpgradeTemplate);
			}

			`GAMERULES.SubmitGameState(ChangeState);

			UnitVisualizer = XGUnit(History.GetVisualizer(UnitState.ObjectID));
			WeaponVisualizer = XGWeapon(History.GetVisualizer(WeaponStateObject.ObjectID));
			if( WeaponVisualizer != none )
			{
				//Kill the weapon's visualizer then recreate it
				WeaponVisualizer.Destroy();
				History.SetVisualizer(WeaponStateObject.ObjectID, none);
				UnitVisualizer.ApplyLoadoutFromGameState(UnitState, ChangeState);								
			}
		}
	}

	PopulateUpgradeDropdown(UpgradeDropdownR);
}

simulated function OnGiveUpgradeButtonClicked(UIButton button)
{	
	local X2WeaponUpgradeTemplate UpgradeTemplate;
	local array<X2WeaponUpgradeTemplate> PreUpgrades, PostUpgrades;
	local XComGameState_Item WeaponStateObject;	
	local XComGameState_Unit UnitState;
	local XComGameStateHistory History;
	local StateObjectReference ActiveUnitRef;
	local XComGameState NewGameState;

	History = `XCOMHISTORY;
	
	ActiveUnitRef = XComTacticalController(PC).GetActiveUnitStateRef();
	UnitState = XComGameState_Unit(History.GetGameStateForObjectID(ActiveUnitRef.ObjectID));
	WeaponStateObject = UnitState.GetItemInSlot( eInvSlot_PrimaryWeapon );

	PreUpgrades = WeaponStateObject.GetMyWeaponUpgradeTemplates();

	OnGiveUpgrade();
	
	UnitState = XComGameState_Unit(History.GetGameStateForObjectID(ActiveUnitRef.ObjectID));
	WeaponStateObject = UnitState.GetItemInSlot( eInvSlot_PrimaryWeapon );
	PostUpgrades = WeaponStateObject.GetMyWeaponUpgradeTemplates();

	foreach PreUpgrades(UpgradeTemplate)
	{
		if (PostUpgrades.Find(UpgradeTemplate) != INDEX_NONE)
			PostUpgrades.RemoveItem(UpgradeTemplate);
	}
	if (PostUpgrades.Length > 0)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("CHEAT: Update weapon upgrade bonus abilities.");
		foreach PostUpgrades(UpgradeTemplate)
		{
			ApplyWeaponUpgradeAbilities(NewGameState, UnitState, WeaponStateObject, UpgradeTemplate);
		}
		`TACTICALRULES.SubmitGameState(NewGameState);
	}
}

simulated function PopulateItemDropdown(UIDropdown kDropdown, EInventorySlot eEquipmentType)
{
	local X2DataTemplate kEquipmentTemplate;
	local XComGameState_Unit UnitState;
	local XComGameState_Item SlotItem;
	local StateObjectReference ActiveUnitRef;	
	local XComGameStateHistory History;	

	local TPOV CameraView;
	local Rotator CameraRotation;
	local Vector OffsetVector;
	local XGUnit UnitVisualizer;
	local XComUnitPawn Pawn;
	local XGWeapon WeaponVisualizer;
	local XComWeapon WeaponModel;
	local Vector WeaponAttachLocation;
	local Rotator WeaponAttachRotation;

	kDropdown.Clear(); // empty dropdown	

	History = `XCOMHISTORY;

	ActiveUnitRef = XComTacticalController(PC).GetActiveUnitStateRef();
	if( ActiveUnitRef.ObjectID > 0 && 
		(eEquipmentType != eInvSlot_Backpack && eEquipmentType != eInvSlot_Utility) )
	{
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(ActiveUnitRef.ObjectID));
		SlotItem = UnitState.GetItemInSlot( EInventorySlot(eEquipmentType) );		
		
		UnitVisualizer = XGUnit(History.GetVisualizer(ActiveUnitRef.ObjectID));
		WeaponVisualizer = XGWeapon(History.GetVisualizer(SlotItem.ObjectID));
		if( UnitVisualizer != none && WeaponVisualizer != none )
		{
			if( LookatWeapon != none )
			{
				// Pop the existing camera so it won't get stucked unreferenced.
				`CAMERASTACK.RemoveCamera(LookatWeapon);
			}
			LookatWeapon = new class'X2Camera_Fixed';					

			Pawn = UnitVisualizer.GetPawn();

			CameraRotation = Pawn.Rotation;
			CameraRotation.Pitch = 0;
			CameraRotation.Yaw += DegToUnrRot * 220;
			
			OffsetVector = Vector(CameraRotation) * -1.0f;			
			CameraView.Location = Pawn.Location + (OffsetVector * 70.0f);
			WeaponModel = XComWeapon(WeaponVisualizer.m_kEntity);
			if( WeaponModel != none && WeaponModel.DefaultSocket != '' )
			{
				Pawn.Mesh.GetSocketWorldLocationAndRotation(WeaponModel.DefaultSocket, WeaponAttachLocation, WeaponAttachRotation);
				CameraView.Location.Z = WeaponAttachLocation.Z;
			}
			else
			{
				CameraView.Location.Z += 20.0f;
			}
			CameraView.Rotation = CameraRotation;			

			LookatWeapon.SetCameraView( CameraView );
			LookatWeapon.Priority = eCameraPriority_Cinematic;
			`CAMERASTACK.AddCamera(LookatWeapon);
		}
	}

	foreach class'X2ItemTemplateManager'.static.GetItemTemplateManager().IterateTemplates(kEquipmentTemplate, none)
	{
		if( (X2EquipmentTemplate(kEquipmentTemplate) != none &&
			X2EquipmentTemplate(kEquipmentTemplate).iItemSize > 0 &&  // xpad is only item with size 0, that is always equipped
			X2EquipmentTemplate(kEquipmentTemplate).InventorySlot == eEquipmentType) ||
			class'Helper'.static.IsPrimarySecondaryTemplate(X2WeaponTemplate(kEquipmentTemplate), eEquipmentType)
		)
		{
			kDropdown.AddItem(string(kEquipmentTemplate.DataName), string(kEquipmentTemplate.DataName));

			if (kEquipmentTemplate.DataName == SlotItem.GetMyTemplateName())
				kDropdown.SetSelected(kDropdown.items.Length - 1);
		}
	}

	if( kDropdown.SelectedItem < 0 )
	{
		kDropdown.SetSelected(0);
	}
}

simulated function OnGiveItemButtonClicked(UIButton button)
{
	class'X2DownloadableContentInfo_TruePrimarySecondaries'.static.PS_GiveItem(ItemDropdownR.GetSelectedItemText(), EInventorySlot(TypeDropdown.SelectedItem));

	PopulateUpgradeDropdown(UpgradeDropdownR);
}

simulated function DropdownSelectionChange(UIDropdown kDropdown)
{
	switch(kDropdown)
	{
	case TypeDropdownR:
		PopulateItemDropdown(ItemDropdownR, EInventorySlot(TypeDropdownR.SelectedItem));
		break;
	case ItemDropdownR:			
		break;
	}
}