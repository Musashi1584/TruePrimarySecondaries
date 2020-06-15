class ShellMapMatinee extends Object;

var string AnimSequencePrefix;
var string PatchAnimsetPathPrimaryMelee;
var string PatchAnimsetPathPrimaryPistol;
var string PatchAnimsetPathPrimaryAutoPistol;

static function PatchAllLoadedMatinees(XComUnitPawn UnitPawn, XComGameState_Unit UnitState, XComGameState SearchState)
{
	local array<SequenceObject> FoundMatinees;
	local array<string> PackageNames;
	local SequenceObject MatineeObject;
	local Sequence GameSeq;

	if (UnitState == none) return;
 
	GameSeq = class'WorldInfo'.static.GetWorldInfo().GetGameSequence();
	GameSeq.FindSeqObjectsByClass(class'SeqAct_Interp', true, FoundMatinees);
 
	foreach FoundMatinees(MatineeObject)
	{
		ParseStringIntoArray(PathName(MatineeObject), PackageNames, ".", true);

		if (MatineeObject.ObjComment == "XCOMSoldier" || MatineeObject.ObjComment == "XCOMSoldierPreview")
		{
			`LOG("Package" @ PackageNames[0] @ MatineeObject.ObjComment, class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, name("TruePrimarySecondaries" @ default.Class.name));
			PatchSingleMatinee(SeqAct_Interp(MatineeObject), UnitPawn, UnitState, SearchState);
		}
	}
}

static function PatchSingleMatinee(SeqAct_Interp SeqInterp, 
									XComUnitPawn UnitPawn, 
									XComGameState_Unit UnitState, 
									XComGameState SearchState)
{
	local InterpData Data;
	local InterpGroup Group;
	local InterpTrack Track;
	local InterpTrackAnimControl AnimControl;
	local int KeyIndex;
	local array<name> PatchSequenceNames;
	local AnimSet PatchAnimset;
	local AnimSequence Sequence;
	local string FemaleSuffix;

	If (UnitState.kAppearance.iGender == eGender_Female)
	{
		FemaleSuffix = "_F";
	}

	if(class'X2DownloadableContentInfo_TruePrimarySecondaries'.static.HasPrimaryMeleeEquipped(UnitState, SearchState))
	{
		PatchAnimset = AnimSet(`CONTENT.RequestGameArchetype(default.PatchAnimsetPathPrimaryMelee $ FemaleSuffix));
		`LOG(UnitState.GetFirstName @ "has primary melee eqipped. Adding" @ default.PatchAnimsetPathPrimaryMelee $ FemaleSuffix, class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, name("TruePrimarySecondaries" @ default.Class.name));
	}

	if(class'X2DownloadableContentInfo_TruePrimarySecondaries'.static.HasPrimaryPistolEquipped(UnitState, SearchState))
	{
		if (X2WeaponTemplate(UnitState.GetItemInSlot(eInvSlot_PrimaryWeapon, SearchState).GetMyTemplate()).WeaponCat == 'pistol')
		{
			`LOG(UnitState.GetFirstName @ "has primary pistol eqipped. Adding" @ default.PatchAnimsetPathPrimaryPistol $ FemaleSuffix, class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, name("TruePrimarySecondaries" @ default.Class.name));
			PatchAnimset = AnimSet(`CONTENT.RequestGameArchetype(default.PatchAnimsetPathPrimaryPistol $ FemaleSuffix));
		}
		else if (X2WeaponTemplate(UnitState.GetItemInSlot(eInvSlot_PrimaryWeapon, SearchState).GetMyTemplate()).WeaponCat == 'sidearm')
		{
			`LOG(UnitState.GetFirstName @ "has primary autopistol eqipped. Adding" @ default.PatchAnimsetPathPrimaryPistol $ FemaleSuffix, class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, name("TruePrimarySecondaries" @ default.Class.name));
			PatchAnimset = AnimSet(`CONTENT.RequestGameArchetype(default.PatchAnimsetPathPrimaryAutoPistol $ FemaleSuffix));
		}
	}

	if (PatchAnimset == none) return;

	foreach PatchAnimset.Sequences(Sequence)
	{
		PatchSequenceNames.AddItem(name(Repl(Sequence.SequenceName, default.AnimSequencePrefix, "")));
		`LOG("Adding sequence " @ name(Repl(Sequence.SequenceName, default.AnimSequencePrefix, "")), class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, name("TruePrimarySecondaries" @ default.Class.name));
	}


	Data = InterpData(SeqInterp.VariableLinks[0].LinkedVariables[0]);
	
	foreach Data.InterpGroups(Group)
	{
		if (Group.GroupName == 'Burnout')
		{
			if(!class'X2DownloadableContentInfo_TruePrimarySecondaries'.static.HasPrimaryMeleeOrPistolEquipped(UnitState, SearchState))
			{
				`LOG(UnitState.GetItemInSlot(eInvSlot_PrimaryWeapon, SearchState) @ UnitState.GetItemInSlot(eInvSlot_SecondaryWeapon, SearchState), class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, name("TruePrimarySecondaries" @ default.Class.name));
				`LOG(UnitState.GetFullName() @ "!HasPrimaryMeleeOrPistolEquipped, skipping patching", class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, name("TruePrimarySecondaries" @ default.Class.name));
				continue;
			}

			if (Group.GroupAnimSets.Find(PatchAnimset) == INDEX_NONE)
			{
				Group.GroupAnimSets.AddItem(PatchAnimset);
				`LOG("Add animset" @ PatchAnimset @ "to" @ Group.GroupName @ Group.GroupAnimSets.Length, class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, name("TruePrimarySecondaries" @ default.Class.name));
			}

			foreach Group.InterpTracks(Track)
			{
				AnimControl = InterpTrackAnimControl(Track);
				if (AnimControl != none)
				{
					for (KeyIndex = 0; KeyIndex < AnimControl.AnimSeqs.Length; KeyIndex++)
					{
						if (PatchSequenceNames.Find(AnimControl.AnimSeqs[KeyIndex].AnimSeqName) != INDEX_NONE)
						{
							`LOG("Found animsequence" @ Group.GroupName @ AnimControl.AnimSeqs[KeyIndex].AnimSeqName, class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, name("TruePrimarySecondaries" @ default.Class.name));
							AnimControl.AnimSeqs[KeyIndex].AnimSeqName = name(default.AnimSequencePrefix $ AnimControl.AnimSeqs[KeyIndex].AnimSeqName);
							`LOG("Patching" @ Group.GroupName @ UnitState.GetFullName() @ AnimControl.AnimSeqs[KeyIndex].AnimSeqName, class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, name("TruePrimarySecondaries" @ default.Class.name));
						}
						else
						{
							`LOG("Could NOT find" @ Group.GroupName @ AnimControl.AnimSeqs[KeyIndex].AnimSeqName @ "in patch list", class'X2DownloadableContentInfo_TruePrimarySecondaries'.default.bLog, name("TruePrimarySecondaries" @ default.Class.name));
						}
					}
				}
			}
		}
	}
}

defaultproperties
{
	AnimSequencePrefix="PS_"
	PatchAnimsetPathPrimaryMelee="TruePrimarySecondaries_PrimaryMelee.Anims.AS_ShellScreen"
	PatchAnimsetPathPrimaryPistol="TruePrimarySecondaries_Pistol.Anims.AS_ShellScreen"
	PatchAnimsetPathPrimaryAutoPistol="TruePrimarySecondaries_AutoPistol.Anims.AS_ShellScreen"
}