class AnimNotify_FireOffHandPistol extends AnimNotify_Scripted;

var() editinline AnimNotify_FireWeaponVolley WrappedVolley;

event Notify(Actor Owner, AnimNodeSequence AnimSeqInstigator)
{
	local XComUnitPawn Pawn;
	local XGUnitNativeBase OwnerUnit;
	local XGWeapon PrimaryWeapon, SecondaryWeapon;
	local XComWeapon OffHandPistol, Sword;

	Pawn = XComUnitPawn(Owner);
	if (Pawn != none)
	{
		OwnerUnit = Pawn.GetGameUnit();
		if (OwnerUnit != none)
		{
			PrimaryWeapon = XGWeapon(OwnerUnit.GetVisualizedGameState().GetPrimaryWeapon().GetVisualizer());
			SecondaryWeapon = XGWeapon(OwnerUnit.GetVisualizedGameState().GetSecondaryWeapon().GetVisualizer());
			if (PrimaryWeapon != none && SecondaryWeapon != none)
			{
				OffHandPistol = XComWeapon(Pawn.Weapon) == XComWeapon(PrimaryWeapon.m_kEntity) ? XComWeapon(SecondaryWeapon.m_kEntity) : XComWeapon(PrimaryWeapon.m_kEntity);

				// Push the new weapon, call the notify, pop
				Sword = XComWeapon(Pawn.Weapon) == XComWeapon(PrimaryWeapon.m_kEntity) ? XComWeapon(PrimaryWeapon.m_kEntity) : XComWeapon(SecondaryWeapon.m_kEntity);
				Pawn.SetCurrentWeapon(OffHandPistol);
				OwnerUnit.OnFireWeaponVolley(WrappedVolley);
				Pawn.SetCurrentWeapon(Sword);
			}
		}
	}
}