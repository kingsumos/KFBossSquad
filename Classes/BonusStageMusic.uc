Class BonusStageMusic extends Actor;

var bool bInit;
var	sound mySong;

simulated function PostBeginPlay()
{
	Super.PostBeginPlay();
    SetTimer(3,False);
}

simulated function Timer()
{
	if( !bInit )
	{
		bInit = true;
        if(Class'KFBossSquad'.Default.BonusStageSongPackage != "")
        {
            mySong = Sound(DynamicLoadObject(Class'KFBossSquad'.Default.BonusStageSongPackage, class'Sound', True));
            AmbientSound = mySong;
        }
        SetTimer(1,True);
		return;
	}

    if( KFGameType(Level.Game).bWaveInProgress == True )
        return;

    Destroy();
}

defaultproperties
{
	bFullVolume=True
	SoundVolume=255
	SoundRadius=50000
    TransientSoundVolume=0
    SoundOcclusion=None
	bNetNotify=true
	bNoDelete=False
    bHidden=True
}
