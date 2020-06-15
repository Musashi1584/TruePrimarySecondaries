class X2Ability_PrimarySecondaries extends X2Ability
	dependson (XComGameStateContext_Ability) config(TruePrimarySecondaries);

var config int PISTOL_MOVEMENT_BONUS;
var config int PISTOL_DETECTIONRADIUS_MODIFER;
var config float EMPTY_SECONDARY_MOBILITY_BONUS;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(EmptySecondaryMobilityBonus());
	Templates.AddItem(BladestormAttackPrimary());
	Templates.AddItem(QuickDrawPrimary());
	Templates.AddItem(PrimaryPistolsBonus('PrimaryPistolsBonus', default.PISTOL_MOVEMENT_BONUS, default.PISTOL_DETECTIONRADIUS_MODIFER));

	return Templates;
}

static function X2AbilityTemplate EmptySecondaryMobilityBonus()
{
	local X2AbilityTemplate Template;
	local X2Effect_PersistentStatChange Effect;

	Template = PurePassive('EmptySecondaryMobilityBonus', "Texture2D'UILibrary_PerkIcons.UIPerk_stickandmove'", false, 'eAbilitySource_Perk', false);

	Effect = new class'X2Effect_PersistentStatChange';
	Effect.AddPersistentStatChange(eStat_Mobility, default.EMPTY_SECONDARY_MOBILITY_BONUS, MODOP_PostMultiplication);
	Effect.SetDisplayInfo(ePerkBuff_Bonus, Template.LocFriendlyName, Template.LocLongDescription, Template.IconImage, true,, Template.AbilitySourceName);
	Template.AddTargetEffect(Effect);
	//Template.SetUIStatMarkup(class'XLocalizedData'.default.MobilityLabel, eStat_Mobility, default.EMPTY_SECONDARY_MOBILITY_BONUS);
	
	return Template;
}

static function X2AbilityTemplate BladestormAttackPrimary()
{
	local X2AbilityTemplate			Template;

	Template = class'X2Ability_RangerAbilitySet'.static.BladestormAttack('BladestormAttackPrimary');
	Template.CustomFireAnim = 'FF_MeleeC';
	Template.CustomFireKillAnim = 'FF_MeleeC';
	Template.CustomMovingFireAnim = 'FF_MeleeC';
	Template.CustomMovingFireKillAnim = 'FF_MeleeC';
	Template.CustomMovingTurnLeftFireAnim = 'FF_MeleeC';
	Template.CustomMovingTurnLeftFireKillAnim = 'FF_MeleeC';
	Template.CustomMovingTurnRightFireAnim = 'FF_MeleeC';
	Template.CustomMovingTurnRightFireKillAnim= 'FF_MeleeC';

	Template.OverrideAbilities.AddItem('BladestormAttack');

	Template.AbilityShooterConditions.AddItem(new class'X2Condition_PrimaryMelee');

	Template.DefaultSourceItemSlot = eInvSlot_PrimaryWeapon;

	return Template;
}

static function X2AbilityTemplate QuickDrawPrimary()
{
	local X2AbilityTemplate			Template;

	Template = PurePassive('QuickDrawPrimary', "img:///UILibrary_PerkIcons.UIPerk_quickdraw");

	return Template;
}

static function X2AbilityTemplate PrimaryPistolsBonus(name TemplateName, int Bonus, float DetectionModifier)
{
	local X2AbilityTemplate					Template;	
	local X2Effect_PersistentStatChange		PersistentStatChangeEffect;
	local X2Effect_BonusWeaponDamage		BonusDamageEffect;

	`CREATE_X2ABILITY_TEMPLATE(Template, TemplateName);
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_item_nanofibervest";

	Template.AbilitySourceName = 'eAbilitySource_Item';
	Template.eAbilityIconBehaviorHUD = EAbilityIconBehavior_NeverShow;
	Template.Hostility = eHostility_Neutral;
	Template.bDisplayInUITacticalText = false;
	
	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	Template.AbilityTriggers.AddItem(default.UnitPostBeginPlayTrigger);

	PersistentStatChangeEffect = new class'X2Effect_PersistentStatChange';
	PersistentStatChangeEffect.BuildPersistentEffect(1, true, false, false);
	PersistentStatChangeEffect.SetDisplayInfo(ePerkBuff_Passive, Template.LocFriendlyName, Template.GetMyLongDescription(), Template.IconImage, false, , Template.AbilitySourceName);
	PersistentStatChangeEffect.AddPersistentStatChange(eStat_Mobility, Bonus);
	PersistentStatChangeEffect.AddPersistentStatChange(eStat_DetectionModifier, DetectionModifier);
	Template.SetUIStatMarkup(class'XLocalizedData'.default.MobilityLabel, eStat_Mobility, Bonus);
	Template.AddTargetEffect(PersistentStatChangeEffect);
	
	
	BonusDamageEffect = new class'X2Effect_BonusWeaponDamage';
	BonusDamageEffect.BonusDmg = class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.PRIMARY_PISTOLS_DAMAGE_MODIFER;
	Template.AddTargetEffect(BonusDamageEffect);

	Template.AbilityTargetConditions.AddItem(new class'TruePrimarySecondaries.X2Condition_NotDualPistols');

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	
	return Template;
}