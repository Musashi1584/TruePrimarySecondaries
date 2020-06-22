class X2EventListener_PrimarySecondaries_Tactical extends X2EventListener;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateOverrideClipSizeListener());
	Templates.AddItem(CreateOverrideHasInfiniteAmmoListener());

	return Templates;
}

static function CHEventListenerTemplate CreateOverrideClipSizeListener()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'PrimarySecondariesOverrideClipSizeListener');

	Template.AddCHEvent('OverrideClipSize', OnOverrideClipSize, ELD_Immediate);

	Template.RegisterInTactical = true;

	return Template;
}

static function EventListenerReturn OnOverrideClipSize(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_Item ItemState;
	local XComLWTuple Tuple;

	Tuple = XComLWTuple(EventData);
	ItemState = XComGameState_Item(EventSource);

	if (ItemState == none)
	{
		return ELR_NoInterrupt;
	}

	if (class'LoadoutApiFactory'.static.GetLoadoutApi().IsSecondaryPistolItem(ItemState))
	{
		Tuple.Data[0].i = 99;
	}
	else if (class'LoadoutApiFactory'.static.GetLoadoutApi().IsPrimaryPistolItem(ItemState))
	{
		Tuple.Data[0].i = class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.PRIMARY_PISTOLS_CLIP_SIZE;
	}

	return ELR_NoInterrupt;
}


static function CHEventListenerTemplate CreateOverrideHasInfiniteAmmoListener()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'PrimarySecondariesOverrideHasInfiniteAmmoListener');

	Template.AddCHEvent('OverrideHasInfiniteAmmo', OnOverrideHasInfiniteAmmo, ELD_Immediate);

	Template.RegisterInTactical = true;

	return Template;
}

static function EventListenerReturn OnOverrideHasInfiniteAmmo(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_Item ItemState;
	local XComLWTuple Tuple;

	Tuple = XComLWTuple(EventData);
	ItemState = XComGameState_Item(EventSource);

	if (class'LoadoutApiFactory'.static.GetLoadoutApi().IsPrimaryPistolItem(ItemState))
	{
		Tuple.Data[0].b = false;
	}
	else if (class'LoadoutApiFactory'.static.GetLoadoutApi().IsSecondaryPistolItem(ItemState))
	{
		Tuple.Data[0].b = true;
	}

	return ELR_NoInterrupt;
}