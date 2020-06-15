class X2EventListener_PrimarySecondaries_Strategy extends X2EventListener;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateItemConstructionCompletedListenerTemplate());
	Templates.AddItem(CreateItemChangedListenerTemplate());
	Templates.AddItem(CreateOverrideShowItemInLockerListListenerTemplate());

	return Templates;
}

static function CHEventListenerTemplate CreateItemConstructionCompletedListenerTemplate()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'PrimarySecondariesItemConstructionCompleted');

	Template.RegisterInTactical = false;
	Template.RegisterInStrategy = true;

	Template.AddCHEvent('ItemConstructionCompleted', OnItemConstructionCompleted, ELD_OnStateSubmitted);
	`LOG("Register Event ItemConstructionCompleted",, 'TruePrimarySecondaries');

	return Template;
}

static function EventListenerReturn OnItemConstructionCompleted(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	// `LOG(default.class @ GetFuncName() @ XComGameState_Item(EventData).GetMyTemplateName(),, 'TruePrimarySecondaries');
	// class'X2DownloadableContentInfo_TruePrimarySecondaries'.static.UpdateStorageForItem(XComGameState_Item(EventData).GetMyTemplate(), true);
	return ELR_NoInterrupt;
}

static function CHEventListenerTemplate CreateItemChangedListenerTemplate()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'PrimarySecondariesItemChangedListener');

	Template.RegisterInTactical = false;
	Template.RegisterInStrategy = true;

	Template.AddCHEvent('AddItemToHQInventory', OnAddItemToHQInventory, ELD_Immediate);
	`LOG("Register Event AddItemToHQInventory",, 'TruePrimarySecondaries');
	Template.AddCHEvent('RemoveItemFromHQInventory', OnRemoveItemFromHQInventory, ELD_Immediate);
	`LOG("Register Event RemoveItemFromHQInventory",, 'TruePrimarySecondaries');

	return Template;
}

static function EventListenerReturn OnAddItemToHQInventory(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_Item ItemState;

	ItemState = XComGameState_Item(EventSource);

	`LOG(GetFuncName() @ ItemState.GetMyTemplateName() @ ItemState.Quantity,, 'TruePrimarySecondaries');
	
	return ELR_NoInterrupt;
}

static function EventListenerReturn OnRemoveItemFromHQInventory(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_Item ItemState;

	ItemState = XComGameState_Item(EventSource);

	`LOG(GetFuncName() @ ItemState.GetMyTemplateName() @ ItemState.Quantity,, 'TruePrimarySecondaries');
	
	return ELR_NoInterrupt;
}


static function CHEventListenerTemplate CreateOverrideShowItemInLockerListListenerTemplate()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'PrimarySecondariesShowItemInLockerListListener');

	Template.RegisterInTactical = false;
	Template.RegisterInStrategy = true;

	Template.AddCHEvent('OverrideShowItemInLockerList', OnOverrideShowItemInLockerList, ELD_Immediate);
	`LOG("Register Event ShowItemInLockerList",, 'TruePrimarySecondaries');

	return Template;
}

static function EventListenerReturn OnOverrideShowItemInLockerList(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_Item ItemState;
	local XComLWTuple Tuple;
	local EInventorySlot Slot;

	Tuple = XComLWTuple(EventData);
	ItemState = XComGameState_Item(EventSource);

	Slot = EInventorySlot(Tuple.Data[1].i);

	if (Slot != eInvSlot_PrimaryWeapon)
	{
		return ELR_NoInterrupt;
	}

	if (class'X2DownloadableContentInfo_TruePrimarySecondaries'.static.IsSecondaryPistolItem(ItemState, true) ||
		class'X2DownloadableContentInfo_TruePrimarySecondaries'.static.IsSecondaryMeleeItem(ItemState, true)
	)
	{
		`LOG(GetFuncName() @ "ShowInLockerList" @ ItemState.GetMyTemplateName() @ ItemState.Quantity,, 'TruePrimarySecondaries');

		Tuple.Data[0].b = true;
		EventData = Tuple;
	}
	
	return ELR_NoInterrupt;
}