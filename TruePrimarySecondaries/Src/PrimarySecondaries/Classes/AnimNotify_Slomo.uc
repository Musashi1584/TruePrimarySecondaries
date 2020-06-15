class AnimNotify_Slomo extends AnimNotify_Scripted;

var() editinline float Speed;

event Notify(Actor Owner, AnimNodeSequence AnimSeqInstigator)
{
	if (class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bUseSlomoInAnimations)
	{
		`CHEATMGR.Slomo(Speed);
	}
}

defaultproperties
{
	Speed = 1
}