Class BSGameType extends KFGameType;

struct WaveSquads {
    var config array<int> Index;
};

struct BSScore {
    var int PlayerID;
    var int Kills;
};

var int BossSpawnMaxFails;
var bool bBossSquadRequested;
var float CanKillGuardTime;
var float BonusStageEndTime;
var float BonusStageEndWarnTime;
var float BonusStageStartTime;
var array<BSScore> SScore;
var Font BSMessageFont[2];
var SumoWaveSetup WaveSetup;
var SumoMidBossSetup MidBossSetup;
var SumoEndBossSetup EndBossSetup;
var KFBossSquad MonsterConfigMut;
var bool bHaveAdditionalBoss;
var int BossNum;

struct NewSquadsList
{
    var array< SumoSPMonster > MOS;
};
var array<NewSquadsList> InitNewSquads;

var array < SumoSPMonster > NextNewSpawnSquad;
var array < SumoSPMonster > InitSpecialSquad;
var array < SumoSPMonster > InitMidBossSquad;
var config array<string> ShopBugMaps;

// Force slomo for a longer period of time when the boss dies
function DoBossDeath()
{
    local Controller C;
    local Controller nextC;
    local int num;

    bZEDTimeActive =  true;
    bSpeedingBackUp = false;
    LastZedTimeEvent = Level.TimeSeconds;
    //CurrentZEDTimeDuration = ZEDTimeDuration*2;
    //SetGameSpeed(ZedTimeSlomoScale);
    CurrentZEDTimeDuration = 10;
    SetGameSpeed(0.10f);

	if( bHaveAdditionalBoss )
	{
		// kill all zeds since the aim is bugged after boss kill (TODO: fix)
		// (aim is restored when the next boss spawns)
		ForceWaveEnd();
		return;
	}

    num = NumMonsters;

    c = Level.ControllerList;

    // turn off all the other zeds so they don't attack the player
    while (c != none && num > 0)
    {
        nextC = c.NextController;
        if (KFMonsterController(C)!=None)
        {
            C.GotoState('GameEnded');
            --num;
        }
        c = nextC;
    }

}

function LoadUpMonsterList()
{
	// Do nothing
}

function NotifyGameEvent(int EventNumIn)
{
	// Do nothing
}

simulated function PrepareSpecialSquads()
{
	// Do nothing
}

State MatchInProgress
{
	function bool BootShopPlayers()
    {
        local int i;
        for( i=0; i<ShopBugMaps.Length; i++ )
            if( ShopBugMaps[i]~=string(Outer.Name) )
                return false;
        return super.BootShopPlayers();
    }

    function CloseShops()
    {
        local int i;
        local Controller C;
        local Pickup Pickup;
        local CrossbuzzsawBlade CrossbuzzsawBlade;

        bTradingDoorsOpen = False;
        for( i=0; i<ShopList.Length; i++ )
        {
            if( ShopList[i].bCurrentlyOpen )
                ShopList[i].CloseShop();
        }

        SelectShop();

        foreach AllActors(class'Pickup', Pickup)
        {
            if (Pickup == None)
                continue;
            if ( Pickup.bDropped &&
                 ( Pickup.IsA('KnifePickup') || Pickup.IsA('WelderPickup') || Pickup.IsA('WelderExPickup') || Pickup.IsA('SyringePickup') ) )
            {
                Pickup.Destroy();
            }
        }
        foreach AllActors(class'CrossbuzzsawBlade', CrossbuzzsawBlade)
        {
            if( CrossbuzzsawBlade.ImpactActor!=none )
            {
                CrossbuzzsawBlade.Destroy();
            }
        }        

        // Tell all players to stop showing the path to the trader
        for ( C = Level.ControllerList; C != none; C = C.NextController )
        {
            if ( C.Pawn != none && C.Pawn.Health > 0 )
            {
                // Restore pawn collision during trader time
                C.Pawn.bBlockActors = C.Pawn.default.bBlockActors;

                if ( KFPlayerController(C) != none )
                {
                    KFPlayerController(C).SetShowPathToTrader(false);
                    KFPlayerController(C).ClientForceCollectGarbage();

                    if ( WaveNum < FinalWave - 1 )
                    {
                        // Have Trader tell players that the Shop's Closed
                        KFPlayerController(C).ClientLocationalVoiceMessage(C.PlayerReplicationInfo, none, 'TRADER', 6);
                    }
                }
            }
        }
    }

    function Timer()
    {
        local Controller C, nextC;
        local int i, j;
        local BSScore S;
        local KFDoorMover KFDM;
        local SumoSPMonsterAudit MA;
        local bool bOneMessage;
		local bool bFixSpawnErrors;
        local Bot B;

        Global.Timer();

        if ( Level.TimeSeconds > HintTime_1 && bTradingDoorsOpen && bShowHint_2 )
        {
            for ( C = Level.ControllerList; C != None; C = C.NextController )
            {
                if( C.Pawn != none && C.Pawn.Health > 0 )
                {
                    KFPlayerController(C).CheckForHint(32);
                    HintTime_2 = Level.TimeSeconds + 11;
                }
            }

            bShowHint_2 = false;
        }

        if ( Level.TimeSeconds > HintTime_2 && bTradingDoorsOpen && bShowHint_3 )
        {
            for ( C = Level.ControllerList; C != None; C = C.NextController )
            {
                if( C.Pawn != None && C.Pawn.Health > 0 )
                {
                    KFPlayerController(C).CheckForHint(33);
                }
            }

            bShowHint_3 = false;
        }

        if ( !bFinalStartup )
        {
            bFinalStartup = true;
            PlayStartupMessage();
        }
        if ( NeedPlayers() && AddBot() && (RemainingBots > 0) )
            RemainingBots--;
        ElapsedTime++;
        GameReplicationInfo.ElapsedTime = ElapsedTime;
        if( !UpdateMonsterCount() )
        {
            EndGame(None,"TimeLimit");
            Return;
        }

        if( bUpdateViewTargs )
            UpdateViews();

        if (!bNoBots && !bBotsAdded)
        {
            if(KFGameReplicationInfo(GameReplicationInfo) != none)

            if((NumPlayers + NumBots) < MaxPlayers && KFGameReplicationInfo(GameReplicationInfo).PendingBots > 0 )
            {
                AddBots(1);
                KFGameReplicationInfo(GameReplicationInfo).PendingBots --;
            }

            if (KFGameReplicationInfo(GameReplicationInfo).PendingBots == 0)
            {
                bBotsAdded = true;
                return;
            }
        }

        if( bWaveBossInProgress )
        {
            // Close Trader doors
            if( bTradingDoorsOpen )
            {
                CloseShops();
                TraderProblemLevel = 0;
            }
            if( TraderProblemLevel<4 )
            {
                if( BootShopPlayers() )
                    TraderProblemLevel = 0;
                else TraderProblemLevel++;
            }
            if( !bHasSetViewYet && TotalMaxMonsters<=0 && NumMonsters>0 )
            {
                bHasSetViewYet = True;
                for ( C = Level.ControllerList; C != None; C = C.NextController )
                    if ( C.Pawn!=None && KFMonster(C.Pawn)!=None && KFMonster(C.Pawn).MakeGrandEntry() )
                    {
                        ViewingBoss = KFMonster(C.Pawn);
                        Break;
                    }
                if( ViewingBoss!=None )
                {
                    ViewingBoss.bAlwaysRelevant = True;
                    for ( C = Level.ControllerList; C != None; C = C.NextController )
                    {
                        if( PlayerController(C)!=None )
                        {
                            PlayerController(C).SetViewTarget(ViewingBoss);
                            PlayerController(C).ClientSetViewTarget(ViewingBoss);
                            PlayerController(C).bBehindView = True;
                            PlayerController(C).ClientSetBehindView(True);
                            PlayerController(C).ClientSetMusic(BossBattleSong,MTRAN_FastFade);
                        }
                        if ( C.PlayerReplicationInfo!=None && bRespawnOnBoss )
                        {
                            C.PlayerReplicationInfo.bOutOfLives = false;
                            C.PlayerReplicationInfo.NumLives = 0;
                            if ( (C.Pawn == None) && !C.PlayerReplicationInfo.bOnlySpectator && PlayerController(C)!=None )
                                C.GotoState('PlayerWaiting');
                        }
                    }
                }
            }
            else if( ViewingBoss!=None && !ViewingBoss.bShotAnim )
            {
                ViewingBoss = None;
                for ( C = Level.ControllerList; C != None; C = C.NextController )
                    if( PlayerController(C)!=None )
                    {
                        if( C.Pawn==None && !C.PlayerReplicationInfo.bOnlySpectator && bRespawnOnBoss )
                            C.ServerReStartPlayer();
                        if( C.Pawn!=None )
                        {
                            PlayerController(C).SetViewTarget(C.Pawn);
                            PlayerController(C).ClientSetViewTarget(C.Pawn);
                        }
                        else
                        {
                            PlayerController(C).SetViewTarget(C);
                            PlayerController(C).ClientSetViewTarget(C);
                        }
                        PlayerController(C).bBehindView = False;
                        PlayerController(C).ClientSetBehindView(False);
                    }
            }
            if( TotalMaxMonsters<=0 || (Level.TimeSeconds>WaveEndTime) )
            {
                // if everyone's spawned and they're all dead
                if ( NumMonsters <= 0 )
				{
					if( bHaveAdditionalBoss )
						StopGameMusic();
                    DoWaveEnd();
				}
            }
            else AddBoss();
        }
        else if(bWaveInProgress)
        {
            WaveTimeElapsed += 1.0;

            // Close Trader doors
            if (bTradingDoorsOpen)
            {
                CloseShops();
                TraderProblemLevel = 0;
            }
            if( TraderProblemLevel<4 )
            {
                if( BootShopPlayers() )
                    TraderProblemLevel = 0;
                else TraderProblemLevel++;
            }
            if(!MusicPlaying)
                StartGameMusic(True);

            if( bBossSquadRequested )
            {
                if( MidBossSetup.BonusStage )
                {
                    // disable dramatic events during bonus stage
                    LastZedTimeEvent = Level.TimeSeconds;

                    if( Level.TimeSeconds > BonusStageStartTime-15 )
                        BroadcastLocalizedMessage(class'BossSquadMessage', 1);
                    if( Level.TimeSeconds > BonusStageStartTime-5 )
                        BonusStageStartTime += 9999;

                    if( Level.TimeSeconds > BonusStageEndWarnTime )
                    {
                        BroadcastLocalizedMessage(class'BossSquadMessage', 2);
                        BonusStageEndWarnTime += 9999;
                    }

                    if( Level.TimeSeconds > BonusStageEndTime )
                    {
                        i = NumMonsters;
                        C = Level.ControllerList;
                        while (C != None && i > 0)
                        {
                            nextC = C.NextController;
                            if (KillZed(C))
                                --i;
                            C = nextC;
                        }
                        TotalMaxMonsters = 0;
                        bBossSquadRequested = false;
                        BSAwards();
                        // Stop music
                        //for ( C = Level.ControllerList; C != None; C = C.NextController )
                        //    if( KFPlayerController(C) != None )
                        //            KFPlayerController(C).NetStopMusic(5.0f);
						StopGameMusic();
                        DoWaveEnd();
                        return;
                    }
                }
                else
                {
                    if( Level.TimeSeconds > BonusStageStartTime-15 )
                        BroadcastLocalizedMessage(class'BossSquadMessage', 0);
                    if( Level.TimeSeconds > BonusStageStartTime-5 )
                    {
                        BonusStageStartTime += 9999;
                        for ( C = Level.ControllerList; C != None; C = C.NextController )
                            if( KFPlayerController(C) != None )
                                KFPlayerController(C).ClientSetMusic(Class'KFBossSquad'.Default.BossTimeSong,MTRAN_FastFade);
                    }                
                }
            }

            if( TotalMaxMonsters<=0 )
            {
                if ( NumMonsters <= 32 )
                {
                    foreach DynamicActors(class'KFDoorMover', KFDM)
                        if( KFDM.bZedHittingDoor )
                            CanKillGuardTime = Level.TimeSeconds + 60;

                    foreach DynamicActors(class'SumoSPMonsterAudit', MA)
                        if( MA.Monster != None && MA.CanKillMeYet() && Level.TimeSeconds>CanKillGuardTime )
                        {
                            MA.Monster.KilledBy( MA.Monster );
                            break;
                        }
                }

                // if everyone's spawned and they're all dead
                if ( NumMonsters <= 0 )
                {
                    if ( !bBossSquadRequested )
                    {
                        bBossSquadRequested = true;

                        if( MidBossSetup.BossSquad != "" )
                        {
                            // We have a boss squad for this wave
                            j = ZedSpawnList.Length;
                            for( i=0; i<j; i++ )
                                ZedSpawnList[i].Reset();
                            WaveEndTime = Level.TimeSeconds+300;
							NextNewSpawnSquad.Length = 0;
                            NextMonsterTime = Level.TimeSeconds + 15;
                            BonusStageStartTime = NextMonsterTime;
                            BonusStageEndTime = NextMonsterTime + Class'KFBossSquad'.Default.BonusStageTime;
                            BonusStageEndWarnTime = BonusStageEndTime - 10;
                            BossSpawnMaxFails = 0;

							// Load Boss Squads
							LoadMidBossSquad();

                            if( MidBossSetup.BonusStage )
							{
                                SScore.Remove(0, SScore.Length);
                                TotalMaxMonsters = Class'KFBossSquad'.Default.BonusStageNumMonsters;
							}
                            else
                            {
								SetMidBossSquad();
                                TotalMaxMonsters = NextNewSpawnSquad.Length;
                            }
                            KFGameReplicationInfo(Level.Game.GameReplicationInfo).MaxMonsters = TotalMaxMonsters;

                            if ( TotalMaxMonsters > 0 )
                            {
                                if( MidBossSetup.BonusStage && Class'KFBossSquad'.Default.BonusStageSongPackage != "" )
                                {
                                    Spawn(class'BonusStageMusic');
                                    Spawn(class'BonusStageMusic');    // Hack: 2x AmbientSound volume
                                }

                                // Notify Players
                                for ( C = Level.ControllerList; C != None; C = C.NextController )
                                {
                                    if( KFPlayerController(C) != None )
                                    {
                                        if( MidBossSetup.BonusStage )
                                        {
                                            //Save the scores before BS starts
                                            S.PlayerID = C.PlayerReplicationInfo.PlayerID;
                                            S.Kills = C.PlayerReplicationInfo.Kills;
                                            SScore[SScore.Length] = S;
                                            if(Class'KFBossSquad'.Default.BonusStageSong == "")
                                                KFPlayerController(C).NetStopMusic(5.0f);
                                            else
                                                KFPlayerController(C).ClientSetMusic(Class'KFBossSquad'.Default.BonusStageSong,MTRAN_FastFade);
                                            KFPlayerController(C).ReceiveLocalizedMessage(Class'BossSquadMessage',1);
                                            C.Pawn.Spawn(Class'BonusStageClient',C.Pawn);
                                        }
                                        else
                                        {
                                            KFPlayerController(C).ClientSetMusic(Class'KFBossSquad'.Default.BossTimeIntroSong,MTRAN_Instant);
                                            KFPlayerController(C).ReceiveLocalizedMessage(Class'BossSquadMessage',0);
                                        }
                                    }
                                }
                                return;
                            }    
                        }
                    }

                    if( MidBossSetup.BonusStage )
                        BSAwards();

                    bBossSquadRequested = false;

                    // Stop music
                    //for ( C = Level.ControllerList; C != None; C = C.NextController )
                    //    if( KFPlayerController(C) != None )
                    //            KFPlayerController(C).NetStopMusic(5.0f);
					StopGameMusic();

                    DoWaveEnd();
                }
            }  // all monsters spawned
            else if ( bBossSquadRequested )
            {
                WaveEndTime = Level.TimeSeconds+160;

				if( Level.TimeSeconds > NextMonsterTime )
				{
					if( MidBossSetup.BonusStage == false )
					{
						/* Boss Time */
						if (NextNewSpawnSquad.Length > 0 && NumMonsters<MaxMonsters)
							MidBossAddSquad();
						NextMonsterTime = Level.TimeSeconds + 0.4;
					}
					else
					{
						/* Bonus Stage */
						if (NumMonsters <= MaxMonsters)
						{
							/* Create the next squad */
							bFixSpawnErrors = (NextNewSpawnSquad.Length != 0);
							SetMidBossSquad();
							NewAddSquad(bFixSpawnErrors, True);
						}
						NextMonsterTime = 0;
					}
				}
            }
            else if ( (Level.TimeSeconds > NextMonsterTime) && ( (NumMonsters == 0) || (NumMonsters+Min(NextNewSpawnSquad.Length,12) <= MaxMonsters) ) )
            {
                WaveEndTime = Level.TimeSeconds+160;
                if( !bDisableZedSpawning )
                {
                    NewAddSquad(True);
                }

                if(NextNewSpawnSquad.length>0)
                {
                    NextMonsterTime = 0;
                }
                else
                {
                    NextMonsterTime = Level.TimeSeconds + CalcNextSquadSpawnTime();
                }
            }
        }
        else if ( NumMonsters <= 0 )
        {
            if ( WaveNum == FinalWave && !bUseEndGameBoss )
            {
                if( bDebugMoney )
                {
                    log("$$$$$$$$$$$$$$$$ Final TotalPossibleMatchMoney = "$TotalPossibleMatchMoney,'Debug');
                }

                EndGame(None,"TimeLimit");
                return;
            }
            else if( WaveNum >= (FinalWave + 1) && bUseEndGameBoss && !bHaveAdditionalBoss )
            {
                if( bDebugMoney )
                {
                    log("$$$$$$$$$$$$$$$$ Final TotalPossibleMatchMoney = "$TotalPossibleMatchMoney,'Debug');
                }

                EndGame(None,"TimeLimit");
                return;
            }

            WaveCountDown--;
            if ( !CalmMusicPlaying )
            {
                InitMapWaveCfg();
                StartGameMusic(False);
            }

            // Open Trader doors
            if ( WaveNum != InitialWave && !bTradingDoorsOpen )
            {
                OpenShops();
            }

            // Select a shop if one isn't open
            if (    KFGameReplicationInfo(GameReplicationInfo).CurrentShop == none )
            {
                SelectShop();
            }

            KFGameReplicationInfo(GameReplicationInfo).TimeToNextWave = WaveCountDown;
            if ( WaveCountDown == 30 )
            {
                for ( C = Level.ControllerList; C != None; C = C.NextController )
                {
                    if ( KFPlayerController(C) != None )
                    {
                        // Have Trader tell players that they've got 30 seconds
                        KFPlayerController(C).ClientLocationalVoiceMessage(C.PlayerReplicationInfo, none, 'TRADER', 4);
                    }
                }
            }
            else if ( WaveCountDown == 10 )
            {
                for ( C = Level.ControllerList; C != None; C = C.NextController )
                {
                    if ( KFPlayerController(C) != None )
                    {
                        // Have Trader tell players that they've got 10 seconds
                        KFPlayerController(C).ClientLocationalVoiceMessage(C.PlayerReplicationInfo, none, 'TRADER', 5);
                    }
                }
            }
            else if ( WaveCountDown == 5 )
            {
                KFGameReplicationInfo(Level.Game.GameReplicationInfo).MaxMonstersOn=false;
                InvasionGameReplicationInfo(GameReplicationInfo).WaveNumber = WaveNum;
            }
            else if ( (WaveCountDown > 0) && (WaveCountDown < 5) )
            {
                if( WaveNum >= FinalWave && bUseEndGameBoss && !bHaveAdditionalBoss )
                {
                    BroadcastLocalizedMessage(class'KFMod.WaitingMessage', 3);
                }
                else
                {
                    BroadcastLocalizedMessage(class'KFMod.WaitingMessage', 1);
                }
            }
            else if ( WaveCountDown <= 1 )
            {
                bWaveInProgress = true;
                KFGameReplicationInfo(GameReplicationInfo).bWaveInProgress = true;

                // Randomize the ammo pickups again
                if( WaveNum > 0 )
                {
                    SetupPickups();
                }

                if( WaveNum >= FinalWave && bUseEndGameBoss )
                {
                    StartWaveBoss();
                }
                else
                {
                    SetupWave();

                    for ( C = Level.ControllerList; C != none; C = C.NextController )
                    {
                        if ( PlayerController(C) != none )
                        {
                            PlayerController(C).LastPlaySpeech = 0;

                            if ( KFPlayerController(C) != none )
                            {
                                KFPlayerController(C).bHasHeardTraderWelcomeMessage = false;
                            }
                        }

                        if ( Bot(C) != none )
                        {
                            B = Bot(C);
                            InvasionBot(B).bDamagedMessage = false;
                            B.bInitLifeMessage = false;

                            if ( !bOneMessage && (FRand() < 0.65) )
                            {
                                bOneMessage = true;

                                if ( (B.Squad.SquadLeader != None) && B.Squad.CloseToLeader(C.Pawn) )
                                {
                                    B.SendMessage(B.Squad.SquadLeader.PlayerReplicationInfo, 'OTHER', B.GetMessageIndex('INPOSITION'), 20, 'TEAM');
                                    B.bInitLifeMessage = false;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function StartWaveBoss()
    {
        local int i,l;
		local SumoEndBossSetup NextEndBossSetup;

        l = ZedSpawnList.Length;
        for( i=0; i<l; i++ )
            ZedSpawnList[i].Reset();
        bHasSetViewYet = False;
        WaveEndTime = Level.TimeSeconds+60;
        NextNewSpawnSquad.Length = 1;

		EndBossSetup = MonsterConfigMut.GetEndBossSetup(BossNum++);
		NextNewSpawnSquad[0] = MonsterConfigMut.NewGetMonster( EndBossSetup.EndGameBoss );
		NextNewSpawnSquad[0].MonsterClass.static.PreCacheAssets(Level);

        KFGameReplicationInfo(Level.Game.GameReplicationInfo).MaxMonsters = 1;
        TotalMaxMonsters = 1;
        bWaveBossInProgress = True;

		NextEndBossSetup = MonsterConfigMut.GetEndBossSetup(BossNum);
		if( NextEndBossSetup.EndGameBoss != "" )
			bHaveAdditionalBoss = True;
		else
			bHaveAdditionalBoss = False;
    }

    // Setup the random ammo pickups
    function SetupPickups()
    {
        local int NumWeaponPickups, NumAmmoPickups, Random, i, j;
        local int m;

        // Randomize Available Ammo Pickups
        if ( GameDifficulty >= 5.0 ) // Suicidal and Hell on Earth
        {
            NumWeaponPickups = WeaponPickups.Length * 0.1;
            NumAmmoPickups = AmmoPickups.Length * 0.1;
        }
        else if ( GameDifficulty >= 4.0 ) // Hard
        {
            NumWeaponPickups = WeaponPickups.Length * 0.2;
            NumAmmoPickups = AmmoPickups.Length * 0.35;
        }
        else if ( GameDifficulty >= 2.0 ) // Normal
        {
            NumWeaponPickups = WeaponPickups.Length * 0.3;
            NumAmmoPickups = AmmoPickups.Length * 0.5;
        }
        else // Beginner
        {
            NumWeaponPickups = WeaponPickups.Length * 0.5;
            NumAmmoPickups = AmmoPickups.Length * 0.65;
		}

        if( WeaponPickups.Length > 0 )
		    NumWeaponPickups = Max(1, NumWeaponPickups);
        else
            NumWeaponPickups = 0;
        if( AmmoPickups.Length > 0 )
		    NumAmmoPickups = Max(1, NumAmmoPickups);
        else
            NumAmmoPickups = 0;

        // reset all the of the pickups
        for ( m = 0; m < WeaponPickups.Length ; m++ )
        {
            if( WeaponPickups[m] != None )
       		    WeaponPickups[m].DisableMe();
        }

        for ( m = 0; m < AmmoPickups.Length ; m++ )
        {
            if( AmmoPickups[m] != None )
       		    AmmoPickups[m].GotoState('Sleeping', 'Begin');
        }

        // Ramdomly select which pickups to spawn
        for ( i = 0; i < NumWeaponPickups && j < 10000; i++ )
        {
            Random = Rand(WeaponPickups.Length);

            if( WeaponPickups[Random] != None )
            {
            	if( !WeaponPickups[Random].bIsEnabledNow )
            	{
            		WeaponPickups[Random].EnableMe();
            	}
            	else
            	{
            		i--;
            	}
            }

            j++;
        }

        for ( i = 0; i < NumAmmoPickups && j < 10000; i++ )
        {
            Random = Rand(AmmoPickups.Length);

            if( AmmoPickups[Random] != None )
            {
            	if(  AmmoPickups[Random].bSleeping )
            	{
            		AmmoPickups[Random].GotoState('Pickup');
            	}
            	else
            	{
            		i--;
            	}
            }

            j++;
        }
    }
}

function SetupWave()
{
    local int i,j;
    local float NewMaxMonsters;
    //local int m;
    local float DifficultyMod, NumPlayersMod;
    local int UsedNumPlayers;

    // Get the wave configuration
    WaveSetup = MonsterConfigMut.GetWaveSetup(WaveNum);
	MidBossSetup = MonsterConfigMut.GetMidBossSetup(WaveNum);

	if ( WaveNum > 10 )
	{
        SetupRandomWave();
        return;
    }

    TraderProblemLevel = 0;
    rewardFlag=false;
    ZombiesKilled=0;
    WaveMonsters = 0;
    WaveNumClasses = 0;
	NewMaxMonsters = WaveSetup.WaveMaxMonsters;

    // scale number of zombies by difficulty
    if ( GameDifficulty >= 7.0 ) // Hell on Earth
    {
        DifficultyMod=1.7;
    }
    else if ( GameDifficulty >= 5.0 ) // Suicidal
    {
        DifficultyMod=1.5;
    }
    else if ( GameDifficulty >= 4.0 ) // Hard
    {
        DifficultyMod=1.3;
    }
    else if ( GameDifficulty >= 2.0 ) // Normal
    {
        DifficultyMod=1.0;
    }
    else //if ( GameDifficulty == 1.0 ) // Beginner
    {
        DifficultyMod=0.7;
    }

    UsedNumPlayers = NumPlayers + NumBots;

    // Scale the number of zombies by the number of players. Don't want to
    // do this exactly linear, or it just gets to be too many zombies and too
    // long of waves at higher levels - Ramm
    switch ( UsedNumPlayers )
    {
        case 1:
            NumPlayersMod=1;
            break;
        case 2:
            NumPlayersMod=2;
            break;
        case 3:
            NumPlayersMod=2.75;
            break;
        case 4:
            NumPlayersMod=3.5;
            break;
        case 5:
            NumPlayersMod=4;
            break;
        case 6:
            NumPlayersMod=4.5;
            break;
        default:
            NumPlayersMod=UsedNumPlayers*0.8; // in case someone makes a mutator with > 6 players
    }

    NewMaxMonsters = NewMaxMonsters * DifficultyMod * NumPlayersMod;

    TotalMaxMonsters = Clamp(NewMaxMonsters,1,Class'KFBossSquad'.Default.WaveMaxMonsters);

    MaxMonsters = Clamp(TotalMaxMonsters,5,MaxZombiesOnce);
    //log("****** "$MaxMonsters$" Max at once!");

    KFGameReplicationInfo(Level.Game.GameReplicationInfo).MaxMonsters=TotalMaxMonsters;
    KFGameReplicationInfo(Level.Game.GameReplicationInfo).MaxMonstersOn=true;
	WaveEndTime = Level.TimeSeconds + 160;
	AdjustedDifficulty = GameDifficulty;

    LoadSquads();

    j = ZedSpawnList.Length;
    for( i=0; i<j; i++ )
        ZedSpawnList[i].Reset();
    j = 1;
    SquadsToUse.Length = 0;

    for( i=0; i<InitNewSquads.Length; i++ )
        SquadsToUse[SquadsToUse.Length] = i;

    // Save this for use elsewhere
    InitialSquadsToUseSize = SquadsToUse.Length;
    bUsedSpecialSquad=false;
    SpecialListCounter=1;

    //Now build the first squad to use
	NextNewSpawnSquad.Length = 0;
    BuildNextSquad();
}

function BuildNextSquad()
{
	local int i, RandNum;

    // Reinitialize the SquadsToUse after all the squads have been used up
    if( SquadsToUse.Length == 0 )
	{
        for( i=0; i<InitNewSquads.Length; i++ )
            SquadsToUse[SquadsToUse.Length] = i;
         
        if( SquadsToUse.Length==0 )
        {
            Warn("No squads to initilize with.");
            Return;
        }

        // Save this for use elsewhere
        InitialSquadsToUseSize = SquadsToUse.Length;
        SpecialListCounter++;
        bUsedSpecialSquad=false;
    }

	if( WaveSetup.bSequential )
	{
		NextNewSpawnSquad = InitNewSquads[SquadsToUse[0]].MOS;
		SquadsToUse.Remove(0,1);
	}
	else
	{
		RandNum = Rand(SquadsToUse.Length);
		NextNewSpawnSquad = InitNewSquads[SquadsToUse[RandNum]].MOS;
		SquadsToUse.Remove(RandNum,1);
	}
}

function AddSpecialSquad()
{
    NextNewSpawnSquad = InitSpecialSquad;
    bUsedSpecialSquad = true;
}

function NewAddSquad(bool bFixSpawnErrors, optional bool bAlwaysFindNewZombieVolume )
{
	local int i, j, numspawned, ZombiesAtOnceLeft;

	if( NextNewSpawnSquad.Length==0 )
	{
		// Throw in the special squad if the time is right
		if( !bUsedSpecialSquad && InitSpecialSquad.Length > 0
			&& (SpecialListCounter%2 == 1))
			AddSpecialSquad();
		else
			BuildNextSquad();
	}

	if( NextSpawnSquad.Length>0 )
	{
		log("ERROR: somebody is messing with NextSpawnSquad!");
		for( i=0;i<NextSpawnSquad.Length;i++ )
			log("Monster:"@NextSpawnSquad[i]);
	}

	// Init the NextSpawnSquad
	NextSpawnSquad.Length = 0;
	for( i=0;i<NextNewSpawnSquad.Length;i++ )
		NextSpawnSquad[NextSpawnSquad.Length] = NextNewSpawnSquad[i].MonsterClass;

	if( LastZVol == None || bAlwaysFindNewZombieVolume )
	{
		LastZVol = FindSpawningVolume();
		if( LastZVol == None )
		{
			NextSpawnSquad.Length = 0;
			NextNewSpawnSquad.Length = 0;
			return;
		}
		else
			LastSpawningVolume = LastZVol;
	}

	// How many zombies can we have left to spawn at once
	ZombiesAtOnceLeft = MaxMonsters - NumMonsters;

	if( LastZVol.SpawnInHere(NextSpawnSquad,,numspawned,TotalMaxMonsters,ZombiesAtOnceLeft) )
	{
		if( (LastZVol.ZEDList.length > 0) && (LastZVol.ZEDList.length >= numspawned) )
		{
			for( i=LastZVol.ZEDList.length-1; i>=LastZVol.ZEDList.length-numspawned; i-- )
			{
				for( j=0; j<NextNewSpawnSquad.Length; j++ )
					if( NextNewSpawnSquad[j].MonsterClass == LastZVol.ZEDList[i].Class )
					{
						if( NextNewSpawnSquad[j].bCustom )
							MonsterConfigMut.AddCustomMonster( string(NextNewSpawnSquad[j].Name) );
						NextNewSpawnSquad.Remove(j--, 1);
						break;
					}
			}
		}

		NumMonsters += numspawned;
		WaveMonsters+= numspawned;
	}

	if( !bFixSpawnErrors )
	{
		NextSpawnSquad.Length = 0;
		NextNewSpawnSquad.Length = 0;
		return;
	}

	if( NextNewSpawnSquad.Length>0 )
	{
		NextSpawnSquad.Length = 0;
		for( i=0;i<NextNewSpawnSquad.Length;i++ )
			NextSpawnSquad[NextSpawnSquad.Length] = NextNewSpawnSquad[i].MonsterClass;
		TryToSpawnInAnotherVolume();
	}

	NextSpawnSquad.Length = 0;
}

function bool AddBoss()
{
    local int ZombiesAtOnceLeft;
    local int numspawned;
    local int i;
	local SumoSPMonster MO;

    FinalSquadNum = 0;

    // Force this to the final boss class
	MO = MonsterConfigMut.NewGetMonster( EndBossSetup.EndGameBoss );
	NextSpawnSquad[0] = MO.MonsterClass;
	NextSpawnSquad[0].static.PreCacheAssets(Level);

    if( LastZVol==none )
    {
        LastZVol = FindSpawningVolume(false, true);
        if(LastZVol!=None)
            LastSpawningVolume = LastZVol;
    }

    if(LastZVol == None)
    {
        LastZVol = FindSpawningVolume(true, true);
        if( LastZVol!=None )
            LastSpawningVolume = LastZVol;

        if( LastZVol == none )
        {
            //log("Error!!! Couldn't find a place for the Patriarch after 2 tries, trying again later!!!");
            TryToSpawnInAnotherVolume(true);
            return false;
        }
    }

    // How many zombies can we have left to spawn at once
    ZombiesAtOnceLeft = MaxMonsters - NumMonsters;

    //log("Patrarich spawn, MaxMonsters = "$MaxMonsters$" NumMonsters = "$NumMonsters$" ZombiesAtOnceLeft = "$ZombiesAtOnceLeft$" TotalMaxMonsters = "$TotalMaxMonsters);

    if(LastZVol.SpawnInHere(NextSpawnSquad,,numspawned,TotalMaxMonsters,32/*ZombiesAtOnceLeft*/,,true))
    {
		if( (LastZVol.ZEDList.length > 0) && (LastZVol.ZEDList.length >= numspawned) )
		{
			for( i=LastZVol.ZEDList.length-1; i>=LastZVol.ZEDList.length-numspawned; i-- )
			{
				if( MO.MonsterClass == LastZVol.ZEDList[i].Class )
				{
					if( MO.bCustom )
						MonsterConfigMut.AddCustomMonster( string(MO.Name) );
					break;
				}
			}
		}

        NumMonsters+=numspawned;
        WaveMonsters+=numspawned;

        return true;
    }
    else
    {
        //log("Failed Spawned Patriarch - numspawned = "$numspawned);

        TryToSpawnInAnotherVolume(true);
        return false;
    }
}

function AddBossBuddySquad()
{
    local int numspawned;
    local int TotalZombiesValue;
    local int i, j, k;
    local int TempMaxMonsters;
    local int TotalSpawned;
    local int TotalZeds;
    local int SpawnDiff;

    if( !bWaveBossInProgress )
		return;

    // Scale the number of helpers by the number of players
    if( NumPlayers == 1 )
    {
        TotalZeds = 8;
    }
    else if( NumPlayers <= 3 )
    {
        TotalZeds = 12;
    }
    else if( NumPlayers <= 5 )
    {
        TotalZeds = 14;
    }
    else if( NumPlayers >= 6 )
    {
        TotalZeds = 16 + (NumPlayers-6)*2;
    }

    for ( i = 0; i < 10; i++ )
    {
        if( TotalSpawned >= TotalZeds )
        {
            FinalSquadNum++;
            //log("Too many monsters, returning");
            return;
        }

        numspawned = 0;

        // Set up the squad for spawning
        NextNewSpawnSquad.Length = 0;
        AddSpecialPatriarchSquad();

		NextSpawnSquad.Length = 0;
		for( j=0; j<NextNewSpawnSquad.Length; j++ )
			NextSpawnSquad[NextSpawnSquad.Length] = NextNewSpawnSquad[j].MonsterClass;

        LastZVol = FindSpawningVolume();
        if( LastZVol!=None )
            LastSpawningVolume = LastZVol;

        if(LastZVol == None)
        {
            LastZVol = FindSpawningVolume();
            if( LastZVol!=None )
                LastSpawningVolume = LastZVol;

            if( LastZVol == none )
            {
                log("Error!!! Couldn't find a place for the Patriarch squad after 2 tries!!!");
            }
        }

        // See if we've reached the limit
        if( (NextSpawnSquad.Length + TotalSpawned) > TotalZeds )
        {
            SpawnDiff = (NextSpawnSquad.Length + TotalSpawned) - TotalZeds;

            if( NextSpawnSquad.Length > SpawnDiff )
            {
				NextNewSpawnSquad.Remove(0, SpawnDiff);
                NextSpawnSquad.Remove(0, SpawnDiff);
            }
            else
            {
                FinalSquadNum++;
                return;
            }

            if( NextSpawnSquad.Length == 0 )
            {
                FinalSquadNum++;
                return;
            }
        }

        // Spawn the squad
        TempMaxMonsters =999;
        if( LastZVol.SpawnInHere(NextSpawnSquad,,numspawned,TempMaxMonsters,999,TotalZombiesValue) )
        {
			if( (LastZVol.ZEDList.length > 0) && (LastZVol.ZEDList.length >= numspawned) )
			{
				for( j=LastZVol.ZEDList.length-1; j>=LastZVol.ZEDList.length-numspawned; j-- )
				{
					for( k=0; k<NextNewSpawnSquad.Length; k++ )
						if( NextNewSpawnSquad[k].MonsterClass == LastZVol.ZEDList[j].Class )
						{
							if( NextNewSpawnSquad[k].bCustom )
								MonsterConfigMut.AddCustomMonster( string(NextNewSpawnSquad[k].Name) );
							NextNewSpawnSquad.Remove(k--, 1);
							break;
						}
				}
			}

            NumMonsters += numspawned;
            WaveMonsters+= numspawned;
            TotalSpawned += numspawned;
        }
    }

    FinalSquadNum++;
}

function AddSpecialPatriarchSquad()
{
	// Load final squads
	NextNewSpawnSquad.Length = 0;

    if( EndBossSetup.FinalSquads[FinalSquadNum] != "" )
		MonsterConfigMut.NewGetSquad( EndBossSetup.FinalSquads[FinalSquadNum], NextNewSpawnSquad );
}

function LoadSquads()
{
	local int i;
	local array <SumoSPMonster> Monsters;

	// Load normal squads
	InitNewSquads.Remove(0, InitNewSquads.Length);
    for( i=0; i<WaveSetup.Squads.Length; i++ )
	{
		Monsters.Remove(0, Monsters.Length);
		MonsterConfigMut.NewGetSquad( WaveSetup.Squads[i], Monsters);
		InitNewSquads.Length = InitNewSquads.Length+1;
		InitNewSquads[InitNewSquads.Length-1].MOS = Monsters;
	}

	// Load special squads
    InitSpecialSquad.Remove(0, InitSpecialSquad.Length);
    if( WaveSetup.SpecialSquad != "" )
	{
		Monsters.Remove(0, Monsters.Length);
		MonsterConfigMut.NewGetSquad( WaveSetup.SpecialSquad, Monsters );
		InitSpecialSquad = Monsters;
	}
}

function LoadMidBossSquad()
{
    local float Scale;

	// Load boss squad
	Scale = PlayerCountModifer();
	InitMidBossSquad.Length = 0;
	MonsterConfigMut.NewGetSquad( MidBossSetup.BossSquad, InitMidBossSquad, Scale );
}

function SetMidBossSquad()
{
	if( NextNewSpawnSquad.Length == 0 )
		NextNewSpawnSquad = InitMidBossSquad;
}

function MidBossAddSquad()
{
	if( NextNewSpawnSquad.Length > 0 )
	{
	    if (Class'KFBossSquad'.Default.bEnableSpawnFx)
		{
			if( SpawnMidBoss( NextNewSpawnSquad[0], True ) )
				NextNewSpawnSquad.Remove(0, 1);
		}
		else
			NewAddSquad(True);
	}
}

function MidBossAddMonsterSuccess(SumoSPMonster MO)
{
	if( MO.bCustom )
		MonsterConfigMut.AddCustomMonster( string(MO.Name) );
    TotalMaxMonsters --;
    NumMonsters ++;
    WaveMonsters ++;
}

function MidBossAddMonsterFailed(SumoSPMonster MO)
{
    if( BossSpawnMaxFails++ < 100 )
    {
        log("MidBossAddMonsterFailed: "$MO.Name$" trying again... retry="$BossSpawnMaxFails);
        NextNewSpawnSquad[NextNewSpawnSquad.Length] = MO;
    }
    else
    {
        log("MidBossAddMonsterFailed: max tries reached... skip");
        ForceWaveEnd();
    }
}

final function bool SpawnMidBoss( SumoSPMonster MO, bool bNotify )
{
	local NavigationPoint N;
	local array<NavigationPoint> Candinates;
	local byte i;
	local int j;
	local VolumeColTester Tst;
    local bool bResult;
    local SumoSpawnFx BDS;
	local Controller C;
	local array<Controller> CL;
    local float Dist;
    local Class<SumoSpawnFx> SpawnFxClass;

    SpawnFxClass = Class<SumoSpawnFx>(DynamicLoadObject(Class'KFBossSquad'.Default.SpawnFx,Class'Class'));
	if( SpawnFxClass==None )
	{
		log("FATAL ERROR: SpawnFx '"$Class'KFBossSquad'.Default.SpawnFx$"' not found");
	}

    // Find spawn locations close to players
	for( C=Level.ControllerList; C!=None; C=C.NextController )
	{
		if( C.bIsPlayer && C.Pawn!=None && C.Pawn.Health>0 )
			CL[CL.Length] = C;
	}
	if( CL.Length>0 )
		C = CL[Rand(CL.Length)];
	if( C==None )
        return false;
    for( N=Level.NavigationPointList; N!=None; N=N.NextNavigationPoint )
    {
        if( PathNode(N)!=None )
        {
            Dist=VSizeSquared(N.Location-C.Pawn.Location);
            if( Dist<1500000 && Dist>15000 && FastTrace(N.Location,C.Pawn.Location) )
			    Candinates[Candinates.Length] = N;
        }
    }
	if( Candinates.Length==0 )
		return false;

	for( i=0; i<30; i++ ) // Give it 30 tries
	{
		j = Rand(Candinates.Length);
		N = Candinates[j];

		// Try twice..
		if( TestSpot(Tst,N.Location,MO.MonsterClass) || TestSpot(Tst,N.Location+vect(0,0,1)*(MO.MonsterClass.Default.CollisionHeight-N.CollisionHeight),MO.MonsterClass) )
		{
            BDS = Spawn(SpawnFxClass,,,Tst.Location,GetRandDir());
            if( BDS != None )
			{
				BDS.MO = MO;
				BDS.bNotifyGame = bNotify;
				bResult = True;            
				break;
			}
		}

		// Remove candinate entry, and try random next...
		Candinates.Remove(j,1);
		if( Candinates.Length==0 )
			break;
	}
	Tst.Destroy();
    return bResult;
}

final function rotator GetRandDir()
{
	local rotator R;

	R.Yaw = Rand(65536);
	return R;
}

final function bool TestSpot( out VolumeColTester T, vector P, class<Actor> A )
{
	if( T==None )
	{
		T = Spawn(Class'VolumeColTester',,,P);
		if( T==None ) return false;
		T.SetCollisionSize(A.Default.CollisionRadius,A.Default.CollisionHeight);
		T.bCollideWhenPlacing = True;
	}
	return T.SetLocation(P);
}

function BSAwards()
{
    local Controller C, D;
    local int i, MaxKills, Kills;

    if( SScore.Length > 1 )
    {
        MaxKills = -1;
        D = None;

        for ( C=Level.ControllerList; C!=None; C=C.NextController )
        {
            if( KFPlayerController(C) != None )
            {
                for( i=0; i<SScore.Length; i++ )
                {
                    if( C.PlayerReplicationInfo.PlayerID == SScore[i].PlayerID )
                    {
                        if( C.PlayerReplicationInfo.Kills > SScore[i].Kills )                        
                            Kills = C.PlayerReplicationInfo.Kills - SScore[i].Kills;
                        else
                            Kills = 0;

                        if( Kills >= MaxKills )
                        {
                            if( Kills == MaxKills )
                            {
                                // Draw, player with highest score wins
                                if( C.PlayerReplicationInfo.Kills > D.PlayerReplicationInfo.Kills )
                                    D = C;
                            }
                            else
                            {
                                MaxKills = Kills;
                                D = C;
                            }
                        }
                        break;
                    }
                }
            }
        }

        if( D != None && KFPlayerController(D) != None )
        {
            for ( C=Level.ControllerList; C!=None; C=C.NextController )
            {
                if( KFPlayerController(C) != None )
                {
                    if( C.PlayerReplicationInfo.PlayerID == D.PlayerReplicationInfo.PlayerID )
                    {
                        KFPlayerController(C).ReceiveLocalizedMessage(Class'BossSquadMessage',Class'KFBossSquad'.Default.BonusStageCash,C.PlayerReplicationInfo,C.PlayerReplicationInfo);
                        C.Pawn.PlaySound( Class'CashPickup'.Default.PickupSound,SLOT_None,2);
                        C.PlayerReplicationInfo.Score += Class'KFBossSquad'.Default.BonusStageCash;
                    }
                    else
                    {
                        KFPlayerController(C).ReceiveLocalizedMessage(Class'BossSquadMessage',Class'KFBossSquad'.Default.BonusStageCash,C.PlayerReplicationInfo,D.PlayerReplicationInfo);
                    }
                }
            }
        }
    }
}

static function Font LoadBSMessageFont(int i)
{
    if( Default.BSMessageFont[0]==None )
    {
        Default.BSMessageFont[0] = Font(DynamicLoadObject("KFFonts.KFBase02DS36",Class'Font'));
        if( Default.BSMessageFont[0]==None )
            Default.BSMessageFont[0] = Font'Engine.DefaultFont';
    }

    if( Default.BSMessageFont[1]==None )
    {
        Default.BSMessageFont[1] = Font(DynamicLoadObject("KFFonts.KFBase02DS24",Class'Font'));
        if( Default.BSMessageFont[1]==None )
            Default.BSMessageFont[1] = Font'Engine.DefaultFont';
    }

    return default.BSMessageFont[i];
}

function float PlayerCountModifer()
{
    local float AdjustedModifier;
    local int NumEnemies;
    local Controller C;
    AdjustedModifier = 1.0;

    For( C=Level.ControllerList; C!=None; C=C.NextController )
        if( C.bIsPlayer && C.PlayerReplicationInfo!=None && C.Pawn!=None && C.Pawn.Health > 0 && C.Pawn.IsA('KFHumanPawn') )
            NumEnemies++;

    if( NumEnemies > 1 )
        AdjustedModifier += float(NumEnemies - 1) * MidBossSetup.PlayerCountScale;

    return AdjustedModifier;
}

function ShowBossHP(bool showall)
{
	local Controller C;
	local ZombieBossBase Boss;
	local string Msg;

	foreach DynamicActors(class'ZombieBossBase', Boss)
		break;

	if (Boss != None && Boss.Health > 0) {
		Msg = "Patriarch HP = "$Boss.Health$"/"$int(Boss.HealthMax)$" ("$(Boss.Health/Boss.HealthMax*100)$"%)";
		for (C = Level.ControllerList; C != None; C = C.NextController)
			if (PlayerController(C) != None)
            {
                if (showall || C.PlayerReplicationInfo.bAdmin || C.PlayerReplicationInfo.bSilentAdmin)
				    PlayerController(C).ClientMessage(Msg);
            }
	}
}

function ForceWaveEnd()
{
    local Controller C, nextC;
    local int i;

    i = NumMonsters;
    C = Level.ControllerList;
    while (C != None && i > 0)
    {
        nextC = C.NextController;
        if (KillZed(C))
            --i;
        C = nextC;
    }

    TotalMaxMonsters = 0;
}

function ForceTraderEnd()
{
    WaveCountDown = 6;
}

function ForceBoss()
{
    WaveNum = 9;
    ForceWaveEnd();
}

function ForceWave(int w)
{
    WaveNum = w;
    ForceWaveEnd();
}

function AddMonsters(int n)
{
    TotalMaxMonsters+=n;
	KFGameReplicationInfo(Level.Game.GameReplicationInfo).MaxMonsters=TotalMaxMonsters+NumMonsters;
}

final function MakeShopBugMap()
{
	local int i;

	for( i=(ShopBugMaps.Length-1); i>=0; --i )
		if( ShopBugMaps[i]~=string(Outer.Name) )
			return;
	ShopBugMaps[ShopBugMaps.Length] = string(Outer.Name);
	SaveConfig();
}

final function unMakeShopBugMap()
{
	local int i;

	for( i=(ShopBugMaps.Length-1); i>=0; --i )
		if( ShopBugMaps[i]~=string(Outer.Name) )
		{
			ShopBugMaps.Remove(i,1);
			SaveConfig();
			return;
		}
}

function ManualAddSquad(string Squad)
{
	// If TotalMaxMonsters equals to Zero, NextNewSpawnSquad may contains junk
	if( TotalMaxMonsters == 0 && NextNewSpawnSquad.Length>0 )
		NextNewSpawnSquad.Length = 0;

	TotalMaxMonsters += MonsterConfigMut.NewGetSquad( Squad, NextNewSpawnSquad );
	KFGameReplicationInfo(Level.Game.GameReplicationInfo).MaxMonsters = TotalMaxMonsters + NumMonsters;
}

// poosh suggestion
static event class<GameInfo> SetGameType( string MapName )
{
    if ( Left(MapName, InStr(MapName, "-")) ~= "KFO")
        return default.Class;
		
    return super.SetGameType( MapName );
}

event InitGame( string Options, out string Error )
{
    Super.InitGame(Options, Error);

    if( MonsterConfigMut==None )
	{
        foreach DynamicActors(class'KFBossSquad', MonsterConfigMut)
            break;
        if( MonsterConfigMut==None )
        {
			log("----------------------------------------------------------");
            Log("ERROR: InitGame(), KFBossSquad mutator not loaded!");
			log("----------------------------------------------------------");
            return;
        }
	}
}

defaultproperties
{
    GameName="Boss Squads"
}

