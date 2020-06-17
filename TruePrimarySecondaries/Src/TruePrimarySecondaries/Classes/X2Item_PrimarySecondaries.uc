class X2Item_PrimarySecondaries extends X2Item;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Weapons;

	Weapons.AddItem(EmptySecondary());

	return Weapons;
}

static function X2DataTemplate EmptySecondary()
{
	local X2WeaponTemplate Template;

	`CREATE_X2TEMPLATE(class'X2WeaponTemplate', Template, 'EmptySecondary');
	Template.WeaponPanelImage = "_Sword";                       // used by the UI. Probably determines iconview of the weapon.

	Template.ItemCat = 'weapon';
	Template.WeaponCat = 'empty';
	Template.WeaponTech = 'conventional';
	Template.strImage = "img:///TruePrimarySecondaries_UI.Textures.Inv_EmptySecondary";
	Template.EquipSound = "Sword_Equip_Conventional";
	Template.InventorySlot = eInvSlot_SecondaryWeapon;
	Template.StowedLocation = eSlot_RightBack;
	// This all the resources; sounds, animations, models, physics, the works.
	Template.GameArchetype = "";
	Template.Tier = 0;

	Template.iRadius = 1;
	Template.NumUpgradeSlots = 0;

	Template.iRange = 1;
	
	Template.Abilities.AddItem('EmptySecondaryMobilityBonus');

	Template.StartingItem = true;
	Template.CanBeBuilt = false;
	Template.bInfiniteItem = true;

	return Template;
}