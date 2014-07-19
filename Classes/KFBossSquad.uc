class KFBossSquad extends Mutator
    config(KFBossSquad);

var config array<string> LargeMaps;
var config int NumPlayersScaleLock; // Scales the health of monsters by up to X players.
var config bool bDebug;
var config string SpawnFx;
var config bool bEnableSpawnFx;
var config int WaveMaxMonsters;
var config bool bEnableDynamicMaxZombiesOnce;
var config int ZombiesOnceMin;
var config int ZombiesOnceMax;
var config int ZombiesOnceStep;

var config int BonusStageTime;
var config int BonusStageCash;
var config int BonusStageNumMonsters;
var config int BonusStageMaxMonsters;
var config string BonusStageSong;
var config string BonusStageSongPackage;
var config string BossTimeSong;
var config string BossTimeIntroSong;
var config bool bEnableGodMode;
var config bool bEnableLifeBoost;

var BSGameType GT;
var array<KFMonster> PendingMonsters;
var array<string> CustomMonstersSpawn;
var bool  bInitMaxMonsters;
var int   CachedNumEnemies;
var float CachedDifficultyDamageModifer;
var float CachedDifficultyHealthModifer;
var float CachedDifficultyHeadHealthModifer;
var float CachedDifficultyMovementSpeedModifer;
var transient array<name> AddedServerPackages;

const MaxSize = 255;
var transient string Monsters_0, Monsters_1, Monsters_2, Monsters_3, Monsters_4, Monsters_5, Monsters_6, Monsters_7, Monsters_8, Monsters_9, Monsters_10, Monsters_11, Monsters_12, Monsters_13, Monsters_14;
var transient int MonstersSize;
var transient bool bInitMonsters;

replication
{
    reliable if ( bNetInitial && Role == ROLE_Authority )
        MonstersSize, Monsters_0, Monsters_1, Monsters_2, Monsters_3, Monsters_4, Monsters_5, Monsters_6, Monsters_7, Monsters_8, Monsters_9, Monsters_10, Monsters_11, Monsters_12, Monsters_13, Monsters_14;
}	

function PostBeginPlay()
{
    local int i;

    if ( Role != ROLE_Authority )
        return;

    GT = BSGameType(Level.Game);
    if (GT == None) {
		Log("ERROR: Wrong GameType (requires BSGameType)", Class.Outer.Name);
        Destroy();
        return;
    }

	// Add the squads query handler
	Class'UTServerAdmin'.Default.QueryHandlerClasses[Class'UTServerAdmin'.Default.QueryHandlerClasses.Length] = "KFBossSquad.SumoSPxWebQueryDefaults";

	// Cached values
    CachedDifficultyDamageModifer = DifficultyDamageModifer();
    CachedDifficultyHealthModifer = DifficultyHealthModifer();
    CachedDifficultyHeadHealthModifer = DifficultyHeadHealthModifer();
	CachedDifficultyMovementSpeedModifer = DifficultyMovementSpeedModifer();

    // Init monster arrays
    InitMonsters();

    // Init spawn effects
	if (bEnableSpawnFx)
	    InitSpawnFx();

    // Add additional serverpackages
    for( i=0; i<AddedServerPackages.Length; i++ )
        AddToPackageMap(string(AddedServerPackages[i]));
    AddedServerPackages.Length = 0;

    // Start timer
    SetTimer(1, True);
}

function InitSpawnFx()
{
    local Class<SumoSpawnFx> SpawnFxClass;

    SpawnFxClass = Class<SumoSpawnFx>(DynamicLoadObject(Class'KFBossSquad'.Default.SpawnFx,Class'Class'));
	if( SpawnFxClass==None )
	{
		log("FATAL ERROR: SpawnFx '"$Class'KFBossSquad'.Default.SpawnFx$"' not found");
		log("Check KFBossSquad.ini -> [KFBossSquad.KFBossSquad] -> SpawnFx"); 
		ConsoleCommand("exit");
	}

    ImplementPackage(SpawnFxClass);
}

final function ImplementPackage( Object O )
{
    local int i;
    
    if( O==None )
        return;
    while( O.Outer!=None )
        O = O.Outer;
    if( O.Name=='KFMod' )
        return;
    for( i=(AddedServerPackages.Length-1); i>=0; --i )
        if( AddedServerPackages[i]==O.Name )
            return;
    AddedServerPackages[AddedServerPackages.Length] = O.Name;
}

function Timer()
{
    local Controller C;
    local int NumEnemies;

    For( C=Level.ControllerList; C!=None; C=C.NextController )
        if( C.bIsPlayer && C.Pawn!=None && C.Pawn.Health > 0 && C.Pawn.IsA('KFHumanPawn') )
            NumEnemies++;
    CachedNumEnemies = Min(NumEnemies,NumPlayersScaleLock);

	if( bEnableDynamicMaxZombiesOnce )
	{
		if( GT.bBossSquadRequested )
		{
			GT.MaxMonsters=BonusStageMaxMonsters;
		}
		else if( GT.bWaveInProgress || GT.bWaveBossInProgress )
		{
			GT.MaxMonsters=Clamp(ZombiesOnceMin+((CachedNumEnemies-1)*ZombiesOnceStep),ZombiesOnceMin,ZombiesOnceMax);
		}
		return;
	}

	if( GT.bBossSquadRequested )
	{
		GT.MaxMonsters=BonusStageMaxMonsters;
		bInitMaxMonsters=false;
	}
	else
	{
		if( !bInitMaxMonsters )
		{
			bInitMaxMonsters = true;
			GT.MaxMonsters=GT.MaxZombiesOnce;
		}
	}
}

function Tick( float DeltaTime )
{
	local int i;
	local KFMonster KFM;
	local string ShortName;
	local SumoSPMonster MO;
	local bool bFound;

	while( PendingMonsters.Length > 0 )
	{
		if( PendingMonsters[0]!=None )
		{
			KFM = PendingMonsters[0];
			KFM.Spawn(Class'SumoSPMonsterAudit', KFM);

			ShortName = locs(KFM.Name);
			bFound = False;
			for( i=0; i<CustomMonstersSpawn.Length; i++ )
			{
				MO = NewGetMonster( CustomMonstersSpawn[i] );
				if( MO.ShortName == ShortName )
				{
					CustomMonstersSpawn.Remove(i,1);
					bFound = True;
					break;
				}
			}
			if( !bFound )
				MO = NewGetMonster( ShortName );

			if( MO==None )
			{
				warn("Creating dummy configuration for"@ShortName@KFM.Class);
				MO = CreateMonster( ShortName );
				MO.MonsterClass = KFM.Class;
				MO.Init();
				MO.SaveConfig();
			}

			MonsterScaling(KFM, MO.SpeedScale,
								MO.HealthScale,
								MO.HeadHealthScale,
								MO.DamageScale,
								MO.MotionDetectorThreat);

			if( bDebug )
			{
				log("monster:"@KFM.Name);
				log("old: health="$KFM.default.Health$"/"$KFM.default.HeadHealth@"speed="$KFM.default.GroundSpeed@"damage="$KFM.default.MeleeDamage);
				log("new: health="$KFM.Health$"/"$KFM.HeadHealth@"speed="$KFM.GroundSpeed@"damage="$KFM.MeleeDamage);
			}
		}

		PendingMonsters.Remove(0,1);
	}

	super.Tick( DeltaTime );
}

function InitMonsters()
{
    local int i;
    local class<KFMonster> MC;
	local SumoSPMonster MO;
	local array<string> MonsterNames;
    local string MonstersString;

    log("*******************************************************************");
    log("MonsterConfig InitMonsters!");
    log("*******************************************************************");
	MonsterNames = GetPerObjectNames("KFBossSquad", string(class'SumoSPMonster'.Name));

    for (i=0; i<MonsterNames.Length; i++)
    {
		MO = NewGetMonster( MonsterNames[i] );
		MC = MO.MonsterClass;

        if( MC==None )
		{
            log("FATAL ERROR: MonsterClass not found while loading SumoSPMonster "$MonsterNames[i]);
            continue;
        }

		if( InStr(MonstersString, string(MC)$";") == -1 )
			MonstersString = string(MC) $ ";" $ MonstersString;

        ImplementPackage(MC);

        if( bDebug )
            log(MC@"Health:"@MC.default.Health * CachedDifficultyHealthModifer * MO.HealthScale
                            @MC.default.HeadHealth * CachedDifficultyHeadHealthModifer * MO.HeadHealthScale
                  @"Speed:"@MC.default.GroundSpeed * MO.SpeedScale
                  @"Damage:"@MC.default.MeleeDamage * CachedDifficultyDamageModifer * MO.DamageScale);

		MC = None;
    }

    MonsterConfigValidation();

    if ( Role == ROLE_Authority )
        SetMonstersString( Left(MonstersString,Len(MonstersString)-1) );
}

function bool CheckSquad(string Squad, optional out int NumMonsters, optional out float Health)
{
	local int i, q;
    local string monster, num;
	local array<string> Cfg;
	local SumoSPMonster MO;
    local class<KFMonster> MC;
	local bool bError;

	Split(Squad, " ", Cfg);

	for( i=0; i<Cfg.Length; i++ )
	{
		if ( !Divide(Cfg[i], ":" , num, monster) )
		{
			log("ERROR: sintax error parsing:"@Cfg[i]@"Squad:"@Squad);
			bError = true;
			continue;
		}
		q = int(num);
		if ( q == 0 )
		{
			log("ERROR: sintax error parsing:"@Cfg[i]@"Squad:"@Squad);
			bError = true;
			continue;
		}

		MO = NewGetMonster( monster );
		MC = MO.MonsterClass;

		if( MC==None )
		{
			log("FATAL ERROR: Monster '"$monster$"' not found",Class.Outer.Name);
			bError = true;
			continue;
		}

		if( bDebug )
		{
			NumMonsters += q;
			Health += (q * MC.default.Health * CachedDifficultyHealthModifer * MO.HealthScale);
		}
	}

	return bError;
}

function bool CheckBoss(string Boss)
{
	local SumoSPMonster MO;
	MO = NewGetMonster( Boss );
	if( MO.MonsterClass==None )
	{
		log("FATAL ERROR: configuration for Boss Monster '"$Boss$"' not found",Class.Outer.Name);
		return True;
	}
	return False;
}

function MonsterConfigValidation()
{
    local SumoWaveSetup WaveSetup;
	local SumoMidBossSetup MidBossSetup;
	local SumoEndBossSetup EndBossSetup;
    local int i, WaveNum, NumMonsters, BossNum;
    local float Health;
	local int Errors;

    for( WaveNum=0; WaveNum<10; WaveNum++ )
    {
		// Check normal and special squads
        WaveSetup = GetWaveSetup(WaveNum);
        NumMonsters = 0;
        Health = 0;
		if( WaveSetup.Squads.Length == 0 )
			elog("ERROR: missing [Wave"$WaveNum$" SumoWaveSetup] configuration", Errors);
        for( i=0; i<WaveSetup.Squads.Length; i++ )
        {
			if( WaveSetup.Squads[i]=="" || CheckSquad(WaveSetup.Squads[i], NumMonsters, Health) )
				elog("ERROR: check the [Wave"$WaveNum$" SumoWaveSetup] Squads configuration", Errors);
        }
		if( WaveSetup.SpecialSquad!="" && CheckSquad(WaveSetup.SpecialSquad, NumMonsters, Health) )
			elog("ERROR: check the [Wave"$WaveNum$" SumoWaveSetup] SpecialSquad configuration", Errors);

        if( bDebug )
            Log("Wave"$WaveNum$" Monsters:"$NumMonsters$" Health:"$Health);

		// Check mid boss squads
		MidBossSetup = New(None, "Wave"$WaveNum) class'SumoLargeMidBossSetup';
		if( MidBossSetup.BossSquad!="" && CheckSquad(MidBossSetup.BossSquad, NumMonsters, Health) )
			elog("ERROR: check the [Boss"$WaveNum$" SumoLargeMidBossSetup] BossSquad configuration", Errors);
		MidBossSetup = New(None, "Wave"$WaveNum) class'SumoSmallMidBossSetup';
		if( MidBossSetup.BossSquad!="" && CheckSquad(MidBossSetup.BossSquad, NumMonsters, Health) )
			elog("ERROR: check the [Boss"$WaveNum$" SumoSmallMidBossSetup] BossSquad configuration", Errors);
    }

	for( BossNum=0; BossNum<50; BossNum++ )
	{
		EndBossSetup = New(None, "Boss"$BossNum) class'SumoEndBossSetup';
		if( EndBossSetup.EndGameBoss=="" )
		{
			if( BossNum != 0 )
				break;
			// First Boss is mandatory
			elog("ERROR: check the [Boss"$BossNum$" SumoEndBossSetup] EndGameBoss configuration", Errors);
		}
		if( CheckBoss(EndBossSetup.EndGameBoss) )
			elog("ERROR: check the [Boss"$BossNum$" SumoEndBossSetup] EndGameBoss configuration", Errors);
		for( i=0; i<3; i++ )
			if( EndBossSetup.FinalSquads[i]!="" && CheckSquad(EndBossSetup.FinalSquads[i], NumMonsters, Health) )
				elog("ERROR: check the [Boss"$BossNum$" SumoEndBossSetup] FinalSquads configuration", Errors);
	}

	if( Errors>0 )
	{
		log("--------------------------------------------------");
		log("");
		log("EEEEE RRRR  RRRR   OOO  RRRR ");
		log("E     R   R R   R O   O R   R");
		log("E     R   R R   R O   O R   R");
		log("EEE   RRRR  RRRR  O   O RRRR ");
		log("E     R R   R R   O   O R R  ");
		log("E     R  R  R  R  O   O R  R ");
		log("EEEEE R   R R   R  OOO  R   R");
		log("");
		log("Aborting due to "$Errors$" configuration errors...");
		log("--------------------------------------------------");
		ConsoleCommand("exit");
	}
}

function elog( string logline, out int Errors )
{
	log( logline );
	Errors++;
}

function int NewGetSquad( string Squad, out array <SumoSPMonster> CustomMonsters, optional float Scale )
{
    local int i, q, n;
    local array<string> Cfg;
    local string monster, num;
	local SumoSPMonster MO;

    Split(Squad, " ", Cfg);

	for( i=0; i<Cfg.Length; i++ )
	{
		if( !Divide(Cfg[i], ":" , num, monster) )
		{
			log("Error: sintax error parsing squad:"@Squad);
			continue;
		}
		q = int(num);
		if( q == 0 )
		{
			log("Error: sintax error parsing squad:"@Squad);
			continue;
		}
		if( Scale != 0 )
			q = int(float(q)*Scale);

		MO = NewGetMonster( monster );
		if( MO==None || MO.MonsterClass==None )
		{
			log("ERROR: monster configuration not found:"@monster);
			continue;
		}
		
		while( (q--)>0 )
		{
			CustomMonsters[CustomMonsters.Length] = MO;
			n++;
		}
	}

	return n;
}

function SumoWaveSetup GetWaveSetup(int WaveNum)
{
	local Object O;

	O = FindObject("Package.Wave"$WaveNum, class'SumoWaveSetup');
	if( O!=None )
		return SumoWaveSetup(O);

    return New(None, "Wave"$WaveNum) class'SumoWaveSetup';
}

function SumoMidBossSetup GetMidBossSetup(int WaveNum)
{
	local int i;
    local bool bLargeMap;

    for( i=0; i<LargeMaps.Length; i++ )
        if( LargeMaps[i]~=string(Outer.Name) )
        {
            bLargeMap = True;
            break;
        }

    if( bLargeMap )
		return GetLargeMidBossSetup(WaveNum);
	else
		return GetSmallMidBossSetup(WaveNum);
}

function SumoMidBossSetup GetSmallMidBossSetup(int WaveNum)
{
	local Object O;

	O = FindObject("Package.Wave"$WaveNum, class'SumoSmallMidBossSetup');
	if( O!=None )
		return SumoSmallMidBossSetup(O);

	return New(None, "Wave"$WaveNum) class'SumoSmallMidBossSetup';
}

function SumoMidBossSetup GetLargeMidBossSetup(int WaveNum)
{
	local Object O;

	O = FindObject("Package.Wave"$WaveNum, class'SumoLargeMidBossSetup');
	if( O!=None )
		return SumoLargeMidBossSetup(O);

	return New(None, "Wave"$WaveNum) class'SumoLargeMidBossSetup';
}

function SumoEndBossSetup GetEndBossSetup(int BossNum)
{
	local Object O;

	O = FindObject("Package.Boss"$BossNum, class'SumoEndBossSetup');
	if( O!=None )
		return SumoEndBossSetup(O);

	return New(None, "Boss"$BossNum) class'SumoEndBossSetup';
}

function SumoSPMonster NewGetMonster(string M)
{
	local Object O;

	O = FindObject("Package."$M, class'SumoSPMonster');
	if( O!=None )
		return SumoSPMonster(O);

	O = New(None, M) class'SumoSPMonster';
	if( SumoSPMonster(O).Init() )
		return SumoSPMonster(O);
	else
		return None;
}

function SumoSPMonster CreateMonster(string M)
{
    return New(None, M) class'SumoSPMonster';
}

function AddCustomMonster(string M)
{
	CustomMonstersSpawn[CustomMonstersSpawn.Length] = locs(M);
}

function bool CheckReplacement(Actor Other, out byte bSuperRelevant)
{
    local KFMonster KFM;
    KFM = KFMonster(Other);
    if( KFM != None )
    {
        KFM.bDiffAdjusted = True; // Difficulty adjustment will be made in Tick()...
		PendingMonsters[PendingMonsters.Length] = KFM;
    }
    return True;
}

function MonsterScaling (KFMonster M, float SpeedScale, float HealthScale, float HeadHealthScale, float DamageScale, float MotionDetectorThreat)
{
    local float RandomGroundSpeedScale;
	local float HealthModifer;
	local float SpeedModifer;
	local float DamageModifer;

    // Difficulty Scaling
    if (Level.Game != none)
    {
		// Adjust the walk speed (HiddenGroundSpeed is used when the monster isn't relevant)
        M.HiddenGroundSpeed = M.default.HiddenGroundSpeed * (1 + (0.10f*CachedNumEnemies));

        // Some randomization to their walk speeds.
        RandomGroundSpeedScale = 1.0 + ((1.0 - (FRand() * 2.0)) * 0.1); // +/- 10%
        M.GroundSpeed = M.default.GroundSpeed * RandomGroundSpeedScale;

		// Scale speed
		SpeedModifer = CachedDifficultyMovementSpeedModifer * SpeedScale;
        M.GroundSpeed *= SpeedModifer;
        M.AirSpeed *= SpeedModifer;
        M.WaterSpeed *= SpeedModifer;
        M.OriginalGroundSpeed = M.GroundSpeed;

        // Scale health by difficulty/number of players
		HealthModifer = CachedDifficultyHealthModifer * NumPlayersHealthModifer(M) * HealthScale;
        M.Health = M.default.Health * HealthModifer;
        M.HealthMax = M.default.HealthMax * HealthModifer;
        M.HeadHealth = M.default.HeadHealth * CachedDifficultyHeadHealthModifer * NumPlayersHeadHealthModifer(M) * HeadHealthScale;
		if( ZombieBoss(M)!=None )
			ZombieBoss(M).HealingAmount = ZombieBoss(M).default.HealingAmount * HealthModifer;

		// Scale damage
		DamageModifer = CachedDifficultyDamageModifer * DamageScale;
        M.MeleeDamage = Max((DamageModifer * M.default.MeleeDamage),1);
        M.SpinDamConst = Max((DamageModifer * M.default.SpinDamConst),1);
        M.SpinDamRand = Max((DamageModifer * M.default.SpinDamRand),1);
        M.ScreamDamage = Max((DamageModifer * M.default.ScreamDamage),1);

        if( MotionDetectorThreat != 0 )
            M.MotionDetectorThreat = MotionDetectorThreat;

        if( ZombieHuskBase(M) != None )
            HuskMonsterScaling( ZombieHuskBase(M) );
    }
}

function HuskMonsterScaling(ZombieHuskBase Z)
{
    if( Level.Game.GameDifficulty < 2.0 )
    {
        Z.ProjectileFireInterval = Z.default.ProjectileFireInterval * 1.25;
        Z.BurnDamageScale = Z.default.BurnDamageScale * 2.0;
    }
    else if( Level.Game.GameDifficulty < 4.0 )
    {
        Z.ProjectileFireInterval = Z.default.ProjectileFireInterval * 1.0;
        Z.BurnDamageScale = Z.default.BurnDamageScale * 1.0;
    }
    else if( Level.Game.GameDifficulty < 7.0 )
    {
        Z.ProjectileFireInterval = Z.default.ProjectileFireInterval * 0.75;
        Z.BurnDamageScale = Z.default.BurnDamageScale * 0.75;
    }
    else // Hardest difficulty
    {
        Z.ProjectileFireInterval = Z.default.ProjectileFireInterval * 0.60;
        Z.BurnDamageScale = Z.default.BurnDamageScale * 0.5;
    }
}

// Scales the health this Zed has by number of players
function float NumPlayersHealthModifer(KFMonster M)
{
    local float AdjustedModifier;

    AdjustedModifier = 1.0;

    if( CachedNumEnemies > 1 )
        AdjustedModifier += (CachedNumEnemies - 1) * M.PlayerCountHealthScale;

    return AdjustedModifier;
}

// Scales the head health this Zed has by number of players
function float NumPlayersHeadHealthModifer(KFMonster M)
{
    local float AdjustedModifier;

    AdjustedModifier = 1.0;

    if( CachedNumEnemies > 1 )
        AdjustedModifier += (CachedNumEnemies - 1) * M.PlayerNumHeadHealthScale;

    return AdjustedModifier;
}

// Scales the damage this Zed deals by the difficulty level
function float DifficultyDamageModifer()
{
    local float AdjustedDamageModifier;

    if ( Level.Game.GameDifficulty >= 7.0 ) // Hell on Earth
    {
        AdjustedDamageModifier = 1.75;
    }
    else if ( Level.Game.GameDifficulty >= 5.0 ) // Suicidal
    {
        AdjustedDamageModifier = 1.50;
    }
    else if ( Level.Game.GameDifficulty >= 4.0 ) // Hard
    {
        AdjustedDamageModifier = 1.25;
    }
    else if ( Level.Game.GameDifficulty >= 2.0 ) // Normal
    {
        AdjustedDamageModifier = 1.0;
    }
    else //if ( GameDifficulty == 1.0 ) // Beginner
    {
        AdjustedDamageModifier = 0.3;
    }

    return AdjustedDamageModifier;
}

// Scales the health this Zed has by the difficulty level
function float DifficultyHealthModifer()
{
    local float AdjustedModifier;

    if ( Level.Game.GameDifficulty >= 7.0 ) // Hell on Earth
    {
        AdjustedModifier = 1.75;
    }
    else if ( Level.Game.GameDifficulty >= 5.0 ) // Suicidal
    {
        AdjustedModifier = 1.55;
    }
    else if ( Level.Game.GameDifficulty >= 4.0 ) // Hard
    {
        AdjustedModifier = 1.35;
    }
    else if ( Level.Game.GameDifficulty >= 2.0 ) // Normal
    {
        AdjustedModifier = 1.0;
    }
    else //if ( GameDifficulty == 1.0 ) // Beginner
    {
        AdjustedModifier = 0.5;
    }

    return AdjustedModifier;
}

// Scales the head health this Zed has by the difficulty level
function float DifficultyHeadHealthModifer()
{
    local float AdjustedModifier;

    if ( Level.Game.GameDifficulty >= 7.0 ) // Hell on Earth
    {
        AdjustedModifier = 1.75;
    }
    else if ( Level.Game.GameDifficulty >= 5.0 ) // Suicidal
    {
        AdjustedModifier = 1.55;
    }
    else if ( Level.Game.GameDifficulty >= 4.0 ) // Hard
    {
        AdjustedModifier = 1.35;
    }
    else if ( Level.Game.GameDifficulty >= 2.0 ) // Normal
    {
        AdjustedModifier = 1.0;
    }
    else //if ( GameDifficulty == 1.0 ) // Beginner
    {
        AdjustedModifier = 0.5;
    }

    return AdjustedModifier;
}

// Scales the speed this Zed has by the difficulty level
function float DifficultyMovementSpeedModifer()
{
    local float AdjustedModifier;

	if( Level.Game.GameDifficulty < 2.0 )
	{
		AdjustedModifier = 0.95;
	}
	else if( Level.Game.GameDifficulty < 4.0 )
	{
		AdjustedModifier = 1.0;
	}
	else if( Level.Game.GameDifficulty < 5.0 )
	{
		AdjustedModifier = 1.15;
	}
	else if( Level.Game.GameDifficulty < 7.0 )
	{
		AdjustedModifier = 1.22;
	}
	else // Hardest difficulty
	{
		AdjustedModifier = 1.3;
	}

    return AdjustedModifier;
}

function Mutate( string MutateString, PlayerController Sender )
{
    // Allow admin or listen server host execute these commands.
    if( Sender.PlayerReplicationInfo.bAdmin || Sender.PlayerReplicationInfo.bSilentAdmin || Viewport(Sender.Player)!=None )
    {
        if( MutateString~="Help" )
        {
            Sender.ClientMessage("=== KFBossSquad commands ===");
            Sender.ClientMessage("ListMonsters <optional-filter>: list of monster ID's");
            Sender.ClientMessage("SpawnMonster <id-number>: spawn monster by ID");
            Sender.ClientMessage("MakeBig: ");
            Sender.ClientMessage("MakeLarge: ");
        }
        else if( Left(MutateString,13)~="ListMonsters " )
        {
            ZVListZeds(Sender,Mid(MutateString,13));
            return;
        }
        else if( MutateString~="ListMonsters" )
        {
            ZVListZeds(Sender, "");
            return;
        }
        else if( Left(MutateString,13)~="SpawnMonster " )
        {
            ZVSummon(Sender,int(Mid(MutateString,13)));
            return;
        }
        else if( MutateString~="MakeBig" || MutateString~="MakeLarge" )
        {
            if( Level.NetMode==NM_StandAlone || Sender.PlayerReplicationInfo.bAdmin || Sender.PlayerReplicationInfo.bSilentAdmin )
            {
                MakeBigMap();
                Sender.ClientMessage(string(Outer.Name)@"has been made large map.");
            }
            return;
        }
        else if( MutateString~="MakeSmall" )
        {
            if( Level.NetMode==NM_StandAlone || Sender.PlayerReplicationInfo.bAdmin || Sender.PlayerReplicationInfo.bSilentAdmin)
            {
                MakeSmallMap();
                Sender.ClientMessage(string(Outer.Name)@"has been made small map.");
            }
            return;
        }
    }
    if( NextMutator!=None )
        NextMutator.Mutate(MutateString, Sender);
}

final function ZVListZeds( PlayerController P, string Filter )
{
	local int i;
	local SumoSPMonster MO;
	local array<string> MonsterNames;

    P.ClientMessage("== List of Zeds ==");
	MonsterNames = GetPerObjectNames("KFBossSquad", string(class'SumoSPMonster'.Name));

    if( Filter == "" )
	{
		for (i=0; i<MonsterNames.Length; i++)
		{
			MO = NewGetMonster( MonsterNames[i] );
			P.ClientMessage("#"$i$": "$MonsterNames[i]@MO.MonsterClass);
		}
	}
	else
	{
		for (i=0; i<MonsterNames.Length; i++)
		{
			MO = NewGetMonster( MonsterNames[i] );
			if( InStr(caps(MO.MonsterClass),caps(Filter))>0 || InStr(caps(MonsterNames[i]),caps(Filter))>0 )
				P.ClientMessage("#"$i$": "$MonsterNames[i]@MO.MonsterClass);
		}
	}
}

function bool GetMonsterByID(int ID, out Class<KFMonster> M, optional out SumoSPMonster MO)
{
	local int i;
	local array<string> MonsterNames;

	MonsterNames = GetPerObjectNames("KFBossSquad", string(class'SumoSPMonster'.Name));

	for (i=0; i<MonsterNames.Length; i++)
	{
		if( ID==i )
		{
			MO = NewGetMonster( MonsterNames[i] );
			M = MO.MonsterClass;
			return true;
		}
	}

	return false;
}

final function MakeBigMap()
{
	local int i;

	for( i=(LargeMaps.Length-1); i>=0; --i )
		if( LargeMaps[i]~=string(Outer.Name) )
			return;
	LargeMaps[LargeMaps.Length] = string(Outer.Name);
	SaveConfig();
}

final function MakeSmallMap()
{
	local int i;

	for( i=(LargeMaps.Length-1); i>=0; --i )
		if( LargeMaps[i]~=string(Outer.Name) )
		{
			LargeMaps.Remove(i,1);
			SaveConfig();
			return;
		}
}

final function ZVSummon( PlayerController P, int ID )
{
    local Class<KFMonster> M;
	local SumoSPMonster MO;

    if( !GetMonsterByID(ID, M, MO) || MO==None || MO.MonsterClass==None )
    {
        P.ClientMessage("== Invalid ZED ID ==");
        return;
    }

    GT.SpawnMidBoss(MO, False);
}

simulated function PostNetReceive()
{
    super.PostNetReceive();

    if ( Role < ROLE_Authority )
    {
        if( !bInitMonsters && MonstersSize > 0 && MonstersSize == GetMonstersStringSize() )
        {
            MyUpdatePrecacheMaterials();
            bInitMonsters = true;
        }
    }
}

simulated function MyUpdatePrecacheMaterials()
{
    local int i,j;
    local class<Actor> A;
    local class<KFMonster> MC;
    local array<string> MA;
    local string Monsters;

    Monsters = Monsters_0 $ Monsters_1 $ Monsters_2 $ Monsters_3 $ Monsters_4 $ Monsters_5 $ Monsters_6 $ Monsters_7 $ Monsters_8 $ Monsters_9 $ Monsters_10 $ Monsters_11 $ Monsters_12 $ Monsters_13 $ Monsters_14;
    Split(Monsters, ";", MA);

    Log("*************************************");
    Log("UpdatePrecacheMaterials called len="$MA.Length);
    Log("*************************************");
    for( i=0; i<MA.Length; ++i )
    {
        MC = Class<KFMonster>(DynamicLoadObject(MA[i],Class'Class'));
        if( MC==None ) {
            log("FATAL CLIENT ERROR: Monster '"$MA[i]$"' not found",Class.Outer.Name);
            continue;
        }

        A = MC;
        log("Loading"@A@"...");

        MC.static.PreCacheAssets(Level);
        for( j=0; j<A.Default.Skins.Length; ++j )
            if( A.Default.Skins[j]!=None )
                Level.AddPrecacheMaterial( A.Default.Skins[j] );
    }
}

function SetMonstersString(string value, optional int idx)
{
    local string tmp;

	if ( len(value) < MaxSize ) {
        tmp = value;
        MonstersSize = Len(value) + idx*MaxSize;
    } else {
		tmp = Left(value, MaxSize);
		SetMonstersString(Right(value, len(value)-MaxSize), idx+1);
	}

    switch(idx)
    {
        case 0: Monsters_0 = tmp; break;
        case 1: Monsters_1 = tmp; break;
        case 2: Monsters_2 = tmp; break;
        case 3: Monsters_3 = tmp; break;
        case 4: Monsters_4 = tmp; break;
        case 5: Monsters_5 = tmp; break;
        case 6: Monsters_6 = tmp; break;
        case 7: Monsters_7 = tmp; break;
        case 8: Monsters_8 = tmp; break;
        case 9: Monsters_9 = tmp; break;
        case 10: Monsters_10 = tmp; break;
        case 11: Monsters_11 = tmp; break;
        case 12: Monsters_12 = tmp; break;
        case 13: Monsters_13 = tmp; break;
        case 14: Monsters_14 = tmp; break;
    };
}

simulated function int GetMonstersStringSize()
{
    return Len(Monsters_0) + Len(Monsters_1) + Len(Monsters_2) + Len(Monsters_3) + Len(Monsters_4) + Len(Monsters_5) + Len(Monsters_6) + Len(Monsters_7) + Len(Monsters_8) + Len(Monsters_9) + Len(Monsters_10) + Len(Monsters_11) + Len(Monsters_12) + Len(Monsters_13) + Len(Monsters_14);
}



static function FillPlayInfo(PlayInfo PlayInfo)
{
    Super.FillPlayInfo(PlayInfo);
    PlayInfo.AddSetting(default.GroupName,"bEnableSpawnFx","Boss Time monster teleport (enabling requires restart)",1,0,"Check");
    PlayInfo.AddSetting(default.GroupName,"bDebug","Verbose logging",1,0,"Check");
    PlayInfo.AddSetting(default.GroupName,"NumPlayersScaleLock","Number of players limit used for monster scaling",1,0,"Text","3;3:32");
    PlayInfo.AddSetting(default.GroupName,"WaveMaxMonsters","Maximum number of monsters per wave",1,0,"Text","5;0:10000");
    PlayInfo.AddSetting(default.GroupName,"bEnableDynamicMaxZombiesOnce","Enable Dynamic MaxZombiesOnce",1,0,"Check");
    PlayInfo.AddSetting(default.GroupName,"ZombiesOnceMin","Dynamic MaxZombiesOnce: minimum value",1,0,"Text","3;1:256");
    PlayInfo.AddSetting(default.GroupName,"ZombiesOnceMax","Dynamic MaxZombiesOnce: maximum value",1,0,"Text","3;1:256");
    PlayInfo.AddSetting(default.GroupName,"ZombiesOnceStep","Dynamic MaxZombiesOnce: per player increasing value",1,0,"Text","3;0:256");
    PlayInfo.AddSetting(default.GroupName,"BonusStageTime","Bonus Stage time",1,0,"Text","3;10:999");
    PlayInfo.AddSetting(default.GroupName,"BonusStageCash","Bonus Stage award cash",1,0,"Text","6;0:100000");
    PlayInfo.AddSetting(default.GroupName,"BonusStageNumMonsters","Bonus Stage number of monsters",1,0,"Text","5;0:10000");
    PlayInfo.AddSetting(default.GroupName,"BonusStageMaxMonsters","Bonus Stage max monsters at once",1,0,"Text","3;0:100");
    PlayInfo.AddSetting(default.GroupName,"BonusStageSong","Bonus Stage music",1,0,"Text","128");
    PlayInfo.AddSetting(default.GroupName,"BonusStageSongPackage","Bonus Stage music package",1,0,"Text","128");
    PlayInfo.AddSetting(default.GroupName,"BossTimeSong","Bonus Time music",1,0,"Text","128");
    PlayInfo.AddSetting(default.GroupName,"BossTimeIntroSong","Bonus Time intro music",1,0,"Text","128");
    PlayInfo.AddSetting(default.GroupName,"bEnableGodMode","Bonus stage god mode",1,0,"Check");
    PlayInfo.AddSetting(default.GroupName,"bEnableLifeBoost","Bonus stage life boost",1,0,"Check");
}

static event string GetDescriptionText(string PropName)
{
    switch (PropName)
    {
        case "bEnableSpawnFx":         return "Monsters are teleported next to players during Boss Time (files from Doom3 mutator are required).";
        case "bDebug":                 return "You can enable verbose logging to help troubleshoot technical problems";
        case "NumPlayersScaleLock":    return "Monsters are scaled (health/difficulty/speed) by up to this amount of number of players.";
        case "WaveMaxMonsters":        return "Maximum number of monsters per wave.";
        case "bEnableDynamicMaxZombiesOnce": return "Enable dynamic MaxZombiesOnce.";
        case "ZombiesOnceMin":         return "If there is only one alive player the MaxZombiesOnce will be set to this value.";
        case "ZombiesOnceMax":         return "This is the maximum value MaxZombiesOnce can reach.";
        case "ZombiesOnceStep":        return "For each alive player the MaxZombiesOnce is increased by this value.";
        case "BonusStageTime":         return "Maximum duration time of the bonus stage (can end early if all speciments are killed).";
        case "BonusStageCash":         return "Bonus Stage award cash for the top killer.";
        case "BonusStageNumMonsters":  return "Total number of specimens during bonus stage.";
        case "BonusStageMaxMonsters":  return "How many specimens will be active at any one time.";
        case "BonusStageSong":         return "Which .ogg music file will be played during Bonus Stage (filename without extension, see Music folder).";
        case "BonusStageSongPackage":  return "Use a sound package to customize the Bonus Stage music (i.e. 'PackageName.MusicName' - the server will upload the music to the clients).";
        case "BossTimeSong":           return "Which .ogg music file will be played during Boss Time.";
        case "BossTimeIntroSong":      return "Intro music file (first 15 seconds of the Boss Time).";
        case "bEnableGodMode":         return "God Mode is enabled during Bonus Stage.";
        case "bEnableLifeBoost":       return "Life boost is enabled during Bonus Stage.";
    }
    return Super.GetDescriptionText(PropName);
}

defaultproperties
{
    bDebug=False
    NumPlayersScaleLock=10
    SpawnFx="KFBossSquadSpawnFx.BossDemonSpawnEx"
    bEnableSpawnFx=False
    WaveMaxMonsters=800

    bEnableDynamicMaxZombiesOnce=False
    ZombiesOnceMin=32
    ZombiesOnceMax=64
    ZombiesOnceStep=4

    BonusStageTime=120
    BonusStageCash=10000
    BonusStageNumMonsters=600
    BonusStageMaxMonsters=64
    BonusStageSong="KF_My_AK"
    BonusStageSongPackage=""
    BossTimeSong="KF_Abandon"
    BossTimeIntroSong="KF_SurfaceTension"
    bEnableGodMode=true
    bEnableLifeBoost=true

    GroupName="KFBossSquad"
    FriendlyName="KFBossSquad"
    Description="KFBossSquad"

    bAlwaysRelevant=True
    bAddToServerPackages=True
    RemoteRole=ROLE_SimulatedProxy
    bNetNotify=True
}

