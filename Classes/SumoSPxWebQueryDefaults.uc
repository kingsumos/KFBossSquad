class SumoSPxWebQueryDefaults extends xWebQueryHandler
	config;

var config string DefaultsIndexPage;
var config string DefaultsSquadsPage;
var config string DefaultsMonstersPage;
var config string DefaultsBossPage;
var localized string NoteSquadsPage;
var localized string NoteMonstersPage;
var localized string NoteBossPage;

function bool Query(WebRequest Request, WebResponse Response)
{
	if (!CanPerform(NeededPrivs))
		return false;

	switch (Mid(Request.URI, 1))
	{
		case DefaultPage: QueryDefaults(Request, Response); return true;
		case DefaultsIndexPage:	QueryDefaultsMenu(Request, Response); return true;
		case DefaultsSquadsPage: if (!MapIsChanging()) QuerySquadsPage(Request, Response); return true;
		case DefaultsMonstersPage: if (!MapIsChanging()) QueryMonstersPage(Request, Response); return true;
		case DefaultsBossPage: if (!MapIsChanging()) QueryBossPage(Request, Response); return true;
	}
	return false;
}

function QueryDefaults(WebRequest Request, WebResponse Response)
{
	local String GameType, PageStr, WaveNum;

	// if no gametype specified use the first one in the list
	GameType = Request.GetVariable("GameType", String(Level.Game.Class));

	// if no page specified, use the first one
	PageStr = Request.GetVariable("Page", DefaultsSquadsPage);
	WaveNum = Eval(Request.GetVariable("WaveNum") != "", "&WaveNum="$ Request.GetVariable("WaveNum"), "");

	Response.Subst("IndexURI", 	DefaultsIndexPage $ "?GameType=" $ GameType $ "&Page=" $ PageStr $ WaveNum);
	Response.Subst("MainURI", 	PageStr $ "?GameType=" $GameType $ WaveNum);

	ShowFrame(Response, DefaultPage);
}

function QueryDefaultsMenu(WebRequest Request, WebResponse Response)
{
	local int i;
	local string Content;

	Response.Subst("DefaultBG", DefaultBG);
	for (i=0; i<10; i++)
		Content = Content $ MakeMenuRow(Response, String(Level.Game.Class) $ "&Page=defaults_squads&WaveNum=" $i, "Wave"@i+1);
	Content = Content $ MakeMenuRow(Response, String(Level.Game.Class) $ "&Page=defaults_boss", "Boss");
	Content = Content $ MakeMenuRow(Response, String(Level.Game.Class) $ "&Page=defaults_monsters", "Monsters");
	Response.Subst("Content", Content);
	Response.Subst("WaveNum", Request.GetVariable("WaveNum", ""));
	ShowPage(Response, DefaultsIndexPage);
}

function string MakeMenuRow(WebResponse Response, string URI, string Title)
{
	Response.Subst("URI", DefaultPage $ "?GameType=" $ URI);
	Response.Subst("URIText", Title);
	return WebInclude("squads_menu_row");
}

function QuerySquadsPage(WebRequest Request, WebResponse Response)
{
	local bool Checked;
	local int i, j, WaveNum;
	local float PlayerCountScale;
	local String HtmlInclude, tmp1, tmp2, Squad, Type, JavaScripts;
	local BSGameType KF;
	local KFBossSquad Mut;
    local SumoWaveSetup WaveSetup;
	local SumoMidBossSetup SmallMidBossSetup;
	local SumoMidBossSetup LargeMidBossSetup;
	local array <string> MonsterName, MonsterNum, Squads;

    KF = BSGameType(Level.Game);

	if( CanPerform(NeededPrivs) && KF!=None && KF.MonsterConfigMut!=None )
	{
		WaveNum = int(Request.GetVariable("WaveNum", "0"));

		Mut = KF.MonsterConfigMut;
        WaveSetup = Mut.GetWaveSetup(WaveNum);
		SmallMidBossSetup = Mut.GetSmallMidBossSetup(WaveNum);
		LargeMidBossSetup = Mut.GetLargeMidBossSetup(WaveNum);

		if (Request.GetVariable("Delete") != "")
		{
			Type = Request.GetVariable("Squad", "999");

			if( Type == "SPECIAL" )
			{
				WaveSetup.SpecialSquad = "";
				WaveSetup.SaveConfig();
			}
			else if( Type == "BOSS" )
			{
				SmallMidBossSetup.ResetProperties();
				SmallMidBossSetup.ClearConfig();
			}
			else if( Type == "LARGEBOSS" )
			{
				LargeMidBossSetup.ResetProperties();
				LargeMidBossSetup.ClearConfig();
			}
			else
			{
				i = int(Type);
				if( i < WaveSetup.Squads.Length )
				{
					for( j=0; j<WaveSetup.Squads.Length; j++ )
						if( i!=j )
							Squads[Squads.Length] = WaveSetup.Squads[j];
					WaveSetup.Squads.Length = 0;
					if( Squads.Length > 0 )
					{
						WaveSetup.Squads = Squads;
						WaveSetup.SaveConfig();
					}
				}
			}
		}

		if (Request.GetVariable("Update") != "")
		{
			if( Request.GetVariable("Config") != "" )
			{
				WaveSetup.WaveMaxMonsters = int( Request.GetVariable("WaveMaxMonsters") );
				WaveSetup.bSequential = bool( Request.GetVariable("SequentialSquadSpawn") );
				WaveSetup.SaveConfig();
			}

			Squad = "";
			for( j=0; j<7; j++ )
			{
				tmp1 = Request.GetVariable( "MonsterNum"$j );
				tmp2 = Request.GetVariable( "MonsterName"$j );
				if( tmp1 != "" && tmp2 != "" )
					Squad = Squad $ tmp1 $ ":" $ tmp2 $ " ";
			}
			Squad = Left(Squad,Len(Squad)-1);

			if( Squad != "" && Mut.CheckSquad( Squad ) == False )
			{
				Type = Request.GetVariable("Squad", "-1");

				if( Type == "NEW" )
				{
					// new normal squad
					WaveSetup.Squads[WaveSetup.Squads.Length] = Squad;
					WaveSetup.SaveConfig();
				}
				else if ( Type == "SPECIAL" )
				{
					// update special squad
					if( Squad != WaveSetup.SpecialSquad )
					{
						WaveSetup.SpecialSquad = Squad;
						WaveSetup.SaveConfig();
					}
				}
				else if ( Type == "BOSS" )
				{
					// update boss squad
					Checked = bool(Request.GetVariable("BonusStage", "False"));
					PlayerCountScale = float(Request.GetVariable("PlayerCountScale", "1.000000"));

					if( Squad != SmallMidBossSetup.BossSquad || Checked != SmallMidBossSetup.BonusStage || PlayerCountScale != SmallMidBossSetup.PlayerCountScale )
					{
						SmallMidBossSetup.BossSquad = Squad;
						SmallMidBossSetup.BonusStage = Checked;
						SmallMidBossSetup.PlayerCountScale = PlayerCountScale;
						SmallMidBossSetup.SaveConfig();
					}
				}
				else if ( Type == "LARGEBOSS" )
				{
					// update largeboss squad
					Checked = bool(Request.GetVariable("BonusStage", "False"));
					PlayerCountScale = float(Request.GetVariable("PlayerCountScale", "1.000000"));

					if( Squad != LargeMidBossSetup.BossSquad || Checked != LargeMidBossSetup.BonusStage || PlayerCountScale != LargeMidBossSetup.PlayerCountScale )
					{
						LargeMidBossSetup.BossSquad = Squad;
						LargeMidBossSetup.BonusStage = Checked;
						LargeMidBossSetup.PlayerCountScale = PlayerCountScale;
						LargeMidBossSetup.SaveConfig();
					}
				}
				else
				{
					// update normal squad
					i = int(TYpe);
					if( Squad != WaveSetup.Squads[i] )
					{
						WaveSetup.Squads[i] = Squad;
						WaveSetup.SaveConfig();
					}
				}
			}
		}

		// Normal Squads
		HtmlInclude = "";
        for( i=0; i<WaveSetup.Squads.Length; i++ )
        {
			Response.Subst("PostAction", DefaultsSquadsPage $ "?Squad="$string(i));
			Response.Subst("WaveNum", WaveNum);
			HtmlInclude = HtmlInclude $ WebInclude( DefaultsSquadsPage $ "_header" );
			ExplodeSquad( WaveSetup.Squads[i], MonsterName, MonsterNum );
			HtmlInclude = HtmlInclude $ MakeSquadRow( Response, MonsterName, MonsterNum );
			HtmlInclude = HtmlInclude $ WebInclude( DefaultsSquadsPage $ "_footer" );
        }
		Response.Subst("MonsterSquads", HtmlInclude);

		// New Squad
		MonsterName.Length = 0;
		MonsterNum.Length = 0;
		HtmlInclude = MakeSquadRow( Response, MonsterName, MonsterNum );
		Response.Subst("MonsterNewSquad", HtmlInclude);

		// Special Squad
		Response.Subst("PostAction", DefaultsSquadsPage $ "?Squad=SPECIAL");
		Response.Subst("WaveNum", WaveNum);
		HtmlInclude = WebInclude( DefaultsSquadsPage $ "_header" );
		ExplodeSquad( WaveSetup.SpecialSquad, MonsterName, MonsterNum );
		HtmlInclude = HtmlInclude $ MakeSquadRow( Response, MonsterName, MonsterNum );
		HtmlInclude = HtmlInclude $ WebInclude( DefaultsSquadsPage $ "_footer_s" );
		Response.Subst("MonsterSpecialSquad", HtmlInclude);

		// Small Boss Squad
		Response.Subst("PostAction", DefaultsSquadsPage $ "?Squad=BOSS");
		Response.Subst("WaveNum", WaveNum);
		HtmlInclude = WebInclude( DefaultsSquadsPage $ "_header" );
		ExplodeSquad( SmallMidBossSetup.BossSquad, MonsterName, MonsterNum );
		HtmlInclude = HtmlInclude $ MakeSquadRow( Response, MonsterName, MonsterNum );
		Response.Subst("Checked", Eval(SmallMidBossSetup.BonusStage, "checked", ""));
		Response.Subst("PlayerCountScale", Eval(SmallMidBossSetup.PlayerCountScale!=0, SmallMidBossSetup.PlayerCountScale, ""));
		HtmlInclude = HtmlInclude $ WebInclude( DefaultsSquadsPage $ "_footer_b" );
		Response.Subst("MonsterBossSquad", HtmlInclude);

		// Large Boss Squad
		Response.Subst("PostAction", DefaultsSquadsPage $ "?Squad=LARGEBOSS");
		Response.Subst("WaveNum", WaveNum);
		HtmlInclude = WebInclude( DefaultsSquadsPage $ "_header" );
		ExplodeSquad( LargeMidBossSetup.BossSquad, MonsterName, MonsterNum );
		HtmlInclude = HtmlInclude $ MakeSquadRow( Response, MonsterName, MonsterNum );
		Response.Subst("Checked", Eval(LargeMidBossSetup.BonusStage, "checked", ""));
		Response.Subst("PlayerCountScale", Eval(LargeMidBossSetup.PlayerCountScale!=0, LargeMidBossSetup.PlayerCountScale, ""));
		HtmlInclude = HtmlInclude $ WebInclude( DefaultsSquadsPage $ "_footer_b" );
		Response.Subst("MonsterLargeBossSquad", HtmlInclude);

		Response.Subst("Wave", WaveNum+1);
		Response.Subst("PostActionMaxMonsters", DefaultsSquadsPage $ "?Config=General");
		Response.Subst("WaveMaxMonsters", WaveSetup.WaveMaxMonsters);
		Response.Subst("SequentialSquadSpawn", Eval(WaveSetup.bSequential, "checked", ""));
		Response.Subst("PostAction", DefaultsSquadsPage $ "?Squad=NEW");
		Response.Subst("WaveNum", WaveNum);
		Response.Subst("PageHelp", NoteSquadsPage);

		// Monsters/InUseMonsters : used in javascript validation
		Response.Subst("MonsterList", GetMonsters());
		Response.Subst("InUseMonsterList", GetInUseMonsters());
		JavaScripts = WebInclude( DefaultsMonstersPage $ "_js" );
		Response.Subst("JavaScripts", JavaScripts);

		ShowPage(Response, DefaultsSquadsPage);
	}
	else
		AccessDenied(Response);
}

function string MakeSquadRow(WebResponse Response, array <string> MonsterName, array <string> MonsterNum )
{
	local int i;

	for( i=0; i<7; I++ )
	{
		if( i<MonsterNum.Length )
		{
			Response.Subst( "MonsterNum"$i, MonsterNum[i] );
			Response.Subst( "MonsterName"$i, MonsterName[i] );
		}
		else
		{
			Response.Subst( "MonsterNum"$i, "" );
			Response.Subst( "MonsterName"$i, "" );
		}
	}

	return WebInclude( DefaultsSquadsPage );
}

function QueryMonstersPage(WebRequest Request, WebResponse Response)
{
	local int i, j;
	local BSGameType KF;
	local KFBossSquad Mut;
	local SumoSPMonster Monster;
	local string HtmlInclude, tmp, Type, JavaScripts;
	local array<string> MonsterNames;
    local class<KFMonster> MC;

	local string Alias;
	local string MonsterClass;
	local string HeadHealthScale;
	local string HealthScale;
	local string SpeedScale;
	local string DamageScale;
	local string MotionDetectorThreat;

    KF = BSGameType(Level.Game);

	if( CanPerform(NeededPrivs) && KF!=None && KF.MonsterConfigMut!=None )
	{
		Mut = KF.MonsterConfigMut;

		if (Request.GetVariable("Delete") != "")
		{
			Type = Request.GetVariable("Monster");

			if( InStr(GetInUseMonsters(), "," $ locs(Type) $ ",") == -1 )
			{
				Monster = Mut.NewGetMonster(Type);
				if( Monster!=None )
				{
					Monster.ClearConfig();
					Monster = None;
				}
			}
		}

		if (Request.GetVariable("Update") != "")
		{
			Type = Request.GetVariable("Monster");
			Alias = Request.GetVariable( "MonsterAlias" );
			MonsterClass = Request.GetVariable( "MonsterClass" );
			HeadHealthScale = Request.GetVariable( "HeadHealthScale" );
			HealthScale = Request.GetVariable( "HealthScale" );
			SpeedScale = Request.GetVariable( "SpeedScale" );
			DamageScale = Request.GetVariable( "DamageScale" );
			MotionDetectorThreat = Request.GetVariable( "MotionDetectorThreat" );

			if( ( Alias != "" ) &&
				( MonsterClass != "" ) &&
				( HeadHealthScale != "" && float(HeadHealthScale)!=0 ) &&
				( HealthScale != "" && float(HealthScale)!=0 ) &&
				( SpeedScale != "" && float(SpeedScale)!=0 ) &&
				( DamageScale != "" && float(DamageScale)!=0 ) &&
				( MotionDetectorThreat != "" ) )
			{
				MC = Class<KFMonster>(DynamicLoadObject(MonsterClass,Class'Class'));
				if( MC==None )
				{
					log("FATAL ERROR: Monster '"$MonsterClass$"' not found");
				}
				else
				{
					if( Type=="NEWMONSTER" )
						Monster = Mut.CreateMonster(Alias);
					else
						Monster = Mut.NewGetMonster(Alias);

					Monster.MonsterClass = MC;
					Monster.HeadHealthScale = float(HeadHealthScale);
					Monster.HealthScale = float(HealthScale);
					Monster.SpeedScale = float(SpeedScale);
					Monster.DamageScale = float(DamageScale);
					Monster.MotionDetectorThreat = float(MotionDetectorThreat);
					Monster.Init();
					Monster.SaveConfig();
					Monster = None;
				}
			}
		}

		// New Monsters
		Response.Subst("readonly", "");
		HtmlInclude = MakeMonsterRow( Response, Monster );
		Response.Subst("MonstersNew", HtmlInclude);

		// Monsters
		MonsterNames = GetPerObjectNames("KFBossSquad", string(class'SumoSPMonster'.Name));
		for (i=0; i<MonsterNames.Length-1; i++)
		{
			for (j=i+1; j<MonsterNames.Length; j++)
			{
				if( locs(MonsterNames[i]) > locs(MonsterNames[j]) )
				{
					// Monster Short Names;
					tmp = MonsterNames[i];
					MonsterNames[i] = MonsterNames[j];
					MonsterNames[j] = tmp;
				}
			}
		}
		HtmlInclude = "";
		for (i=0; i<MonsterNames.Length; i++)
		{
			Monster = Mut.NewGetMonster( MonsterNames[i] );
			Response.Subst("PostAction", DefaultsMonstersPage $ "?Monster="$MonsterNames[i]);
			Response.Subst("readonly", " readonly");
			HtmlInclude = HtmlInclude $ WebInclude( DefaultsMonstersPage $ "_header" );
			HtmlInclude = HtmlInclude $ MakeMonsterRow( Response, Monster );
			HtmlInclude = HtmlInclude $ WebInclude( DefaultsMonstersPage $ "_footer" );
		}

		Response.Subst("Monsters", HtmlInclude);
		Response.Subst("PostAction", DefaultsMonstersPage $ "?Monster=NEWMONSTER");
		Response.Subst("PageHelp", NoteMonstersPage);

		// Monsters/InUseMonsters : used in javascript validation
		Response.Subst("MonsterList", GetMonsters());
		Response.Subst("InUseMonsterList", GetInUseMonsters());
		JavaScripts = WebInclude( DefaultsMonstersPage $ "_js" );
		Response.Subst("JavaScripts", JavaScripts);

		ShowPage(Response, DefaultsMonstersPage);
	}
	else
		AccessDenied(Response);
}

function string MakeMonsterRow(WebResponse Response, SumoSPMonster Monster )
{
	if( Monster!=None )
	{
		Response.Subst( "MonsterClass", 		Monster.MonsterClass );
		Response.Subst( "MonsterAlias", 		Monster.Name );
		Response.Subst( "HeadHealthScale",  	Monster.HeadHealthScale );
		Response.Subst( "HealthScale",  		Monster.HealthScale );
		Response.Subst( "SpeedScale",   		Monster.SpeedScale );
		Response.Subst( "DamageScale",  		Monster.DamageScale );
		Response.Subst( "MotionDetectorThreat", Monster.MotionDetectorThreat );
	}
	else
	{
		Response.Subst( "MonsterClass", 		"" );
		Response.Subst( "MonsterAlias", 		"" );
		Response.Subst( "HeadHealthScale",  	"" );
		Response.Subst( "HealthScale",  		"" );
		Response.Subst( "SpeedScale",   		"" );
		Response.Subst( "DamageScale",  		"" );
		Response.Subst( "MotionDetectorThreat", "" );
	}
	return WebInclude( DefaultsMonstersPage );
}

function QueryBossPage(WebRequest Request, WebResponse Response)
{
	local bool bMultipleBosses, bError;
	local int i, j, BossNum, TotalBossNum;
	local String HtmlInclude, Squad, tmp1, tmp2, JavaScripts;
	local BSGameType KF;
	local KFBossSquad Mut;
	local SumoSPMonster Monster;
	local SumoEndBossSetup EndBossSetup, EndBossSetup2;
	local array <string> MonsterName, MonsterNum;

	local array<string> FinalSquads;
    local string EndGameBoss;

    KF = BSGameType(Level.Game);

	if( CanPerform(NeededPrivs) && KF!=None && KF.MonsterConfigMut!=None )
	{
		Mut = KF.MonsterConfigMut;

		for( TotalBossNum=0; TotalBossNum<50; TotalBossNum++ )
		{
			EndBossSetup = Mut.GetEndBossSetup(TotalBossNum);
			if( EndBossSetup.EndGameBoss=="" )
				break;
		}
		if( TotalBossNum>1 )
			bMultipleBosses = True;

		if (Request.GetVariable("MoveUp") != "")
		{
			BossNum = int(Request.GetVariable("BossNum"));
			if( BossNum > 0 )
			{
				EndBossSetup = Mut.GetEndBossSetup(BossNum);
				EndBossSetup2 = Mut.GetEndBossSetup(BossNum-1);
				EndGameBoss = EndBossSetup.EndGameBoss;
				FinalSquads = EndBossSetup.FinalSquads;
				EndBossSetup.EndGameBoss = EndBossSetup2.EndGameBoss;
				EndBossSetup.FinalSquads = EndBossSetup2.FinalSquads;
				EndBossSetup.SaveConfig();
				EndBossSetup2.EndGameBoss = EndGameBoss;
				EndBossSetup2.FinalSquads = FinalSquads;
				EndBossSetup2.SaveConfig();
			}
		}

		if (Request.GetVariable("Delete") != "")
		{
			BossNum = int(Request.GetVariable("BossNum"));
			j = 0;

			for( i=0; i<50; i++ )
			{
				EndBossSetup = Mut.GetEndBossSetup(i);
				if( EndBossSetup.EndGameBoss=="" )
					break;

				if( BossNum==i)
				{
					EndBossSetup.EndGameBoss = "";
					EndBossSetup.FinalSquads.Length = 0;
					EndBossSetup.ClearConfig();
					continue;
				}

				EndGameBoss = EndBossSetup.EndGameBoss;
				FinalSquads = EndBossSetup.FinalSquads;
				EndBossSetup.EndGameBoss = "";
				EndBossSetup.FinalSquads.Length = 0;
				EndBossSetup.ClearConfig();

				EndBossSetup = Mut.GetEndBossSetup(j++);
				EndBossSetup.EndGameBoss = EndGameBoss;
				EndBossSetup.FinalSquads = FinalSquads;
				EndBossSetup.SaveConfig();
			}
		}

		if (Request.GetVariable("Update") != "")
		{
			EndGameBoss = Request.GetVariable( "EndGameBoss" );
			Monster = Mut.NewGetMonster(EndGameBoss);
			if( Monster==None )
				bError = True;

			for( i=0; i<3; i++ )
			{
				Squad = "";
				for( j=0; j<7; j++ )
				{
					tmp1 = Request.GetVariable( "MonsterNum"$j$"_"$i );
					tmp2 = Request.GetVariable( "MonsterName"$j$"_"$i );
					if( tmp1 != "" && tmp2 != "" )
						Squad = Squad $ tmp1 $ ":" $ tmp2 $ " ";
				}
				Squad = Left(Squad,Len(Squad)-1);

				if( Mut.CheckSquad( Squad ) == False )
					FinalSquads[FinalSquads.Length] = Squad;
				else
					bError = True;
			}

			if( bError==False )
			{
				tmp1 = Request.GetVariable("BossNum");

				if( tmp1 == "NEW" )
					BossNum = TotalBossNum;
				else
					BossNum = int(tmp1);

				EndBossSetup = Mut.GetEndBossSetup(BossNum);
				EndBossSetup.EndGameBoss = EndGameBoss;
				EndBossSetup.FinalSquads = FinalSquads;
				EndBossSetup.SaveConfig();
			}			
		}

		for( i=0; i<50; i++ )
		{
			EndBossSetup = Mut.GetEndBossSetup(i);
			if( EndBossSetup.EndGameBoss=="" )
				break;

			// Boss N
			Response.Subst("PostAction", DefaultsBossPage $ "?BossNum=" $ i);
			Response.Subst("TitleValue", "Boss"@i+1);
			Response.Subst("EndGameBoss", EndBossSetup.EndGameBoss );
			HtmlInclude = HtmlInclude $ WebInclude( DefaultsBossPage $ "_header" );

			// Buddy Squad
			for( j=0; j<3; j++ )
			{
				ExplodeSquad( EndBossSetup.FinalSquads[j], MonsterName, MonsterNum );
				HtmlInclude = HtmlInclude $ MakeBossSquadRow( Response, j, MonsterName, MonsterNum );
			}

			if( bMultipleBosses )
				Response.Subst("HideDeleteButtton", "" );
			else
				Response.Subst("HideDeleteButtton", "display: none;" );
			if( i==0 )
				Response.Subst("HideMoveUpButtton", "display: none;" );
			else
				Response.Subst("HideMoveUpButtton", "" );
			HtmlInclude = HtmlInclude $ WebInclude( DefaultsBossPage $ "_footer" );
		}

		// New Boss
		Response.Subst("PostAction", DefaultsBossPage $ "?BossNum=NEW");
		Response.Subst("TitleValue", "New Boss");
		Response.Subst("EndGameBoss", "" );
		HtmlInclude = HtmlInclude $ WebInclude( DefaultsBossPage $ "_header" );
		MonsterName.Length = 0;
		MonsterNum.Length = 0;
		for( j=0; j<3; j++ )
			HtmlInclude = HtmlInclude $ MakeBossSquadRow( Response, j, MonsterName, MonsterNum );
		HtmlInclude = HtmlInclude $ WebInclude( DefaultsBossPage $ "_footer_new" );

		Response.Subst("BossList", HtmlInclude);
		Response.Subst("PageHelp", NoteBossPage);

		// Monsters/InUseMonsters : used in javascript validation
		Response.Subst("MonsterList", GetMonsters());
		Response.Subst("InUseMonsterList", GetInUseMonsters());
		JavaScripts = WebInclude( DefaultsMonstersPage $ "_js" );
		Response.Subst("JavaScripts", JavaScripts);

		ShowPage(Response, DefaultsBossPage);
	}
	else
		AccessDenied(Response);
}

function string MakeBossSquadRow(WebResponse Response, int RowIndex, array <string> MonsterName, array <string> MonsterNum )
{
	local int i;

	for( i=0; i<7; I++ )
	{
		if( i<MonsterNum.Length )
		{
			Response.Subst( "MonsterNum"$i, MonsterNum[i] );
			Response.Subst( "MonsterName"$i, MonsterName[i] );
		}
		else
		{
			Response.Subst( "MonsterNum"$i, "" );
			Response.Subst( "MonsterName"$i, "" );
		}
	}
	Response.Subst( "RowIndex", RowIndex );
	return WebInclude( DefaultsBossPage $ "_row" );
}

function ExplodeSquad( string Squad, out array <string> MonsterName, out array <string> MonsterNum )
{
    local int i;
    local array<string> Cfg;
    local string Monster, Num;

    Split(Squad, " ", Cfg);
	MonsterName.Length = 0;
	MonsterNum.Length = 0;

	for( i=0; i<Cfg.Length; i++ )
	{
		if( !Divide(Cfg[i], ":" , Num, Monster) )
			continue;
		if( int(Num) == 0 )
			continue;
		MonsterName[MonsterName.Length] = Monster;
		MonsterNum[MonsterNum.Length] = Num;
	}
}

function string GetInUseMonsters()
{
	local int i, WaveNum, BossNum;
	local string Monsters;
	local SumoWaveSetup WaveSetup;
	local SumoMidBossSetup SmallMidBossSetup;
	local SumoMidBossSetup LargeMidBossSetup;
	local SumoEndBossSetup EndBossSetup;
	local BSGameType KF;
	local KFBossSquad Mut;

    KF = BSGameType(Level.Game);
	Mut = KF.MonsterConfigMut;
	Monsters = ",";

	for( WaveNum=0; WaveNum<10; WaveNum++ )
	{
		// Normal Squads
		WaveSetup = Mut.GetWaveSetup(WaveNum);
        for( i=0; i<WaveSetup.Squads.Length; i++ )
			AddMonsters( WaveSetup.Squads[i], Monsters );
		// Special Squad
		AddMonsters( WaveSetup.SpecialSquad, Monsters );

		// Small Boss Squad
		SmallMidBossSetup = Mut.GetSmallMidBossSetup(WaveNum);
		AddMonsters( SmallMidBossSetup.BossSquad, Monsters );

		// Large Boss Squad
		LargeMidBossSetup = Mut.GetLargeMidBossSetup(WaveNum);
		AddMonsters( LargeMidBossSetup.BossSquad, Monsters );
	}

	for( BossNum=0; BossNum<50; BossNum++ )
	{
		// End Boss
		EndBossSetup = Mut.GetEndBossSetup(BossNum);
		if( EndBossSetup.EndGameBoss=="" )
			break;
		if( InStr(Monsters, "," $ locs(EndBossSetup.EndGameBoss) $ ",") == -1 )
			Monsters = Monsters $ locs(EndBossSetup.EndGameBoss) $ ",";

		// Boss Buddy Squads
		for( i=0; i<3; i++ )
			AddMonsters( EndBossSetup.FinalSquads[i], Monsters );
	}

	return Monsters;
}

function AddMonsters( string Squad, out string Monsters )
{
    local int i;
    local array<string> Cfg;
    local string Monster, Num;

    Split(Squad, " ", Cfg);

	for( i=0; i<Cfg.Length; i++ )
	{
		if( !Divide(Cfg[i], ":" , Num, Monster) )
			continue;
		if( int(Num) == 0 )
			continue;
		if( InStr(Monsters, "," $ locs(Monster) $ ",") == -1 )
			Monsters = Monsters $ locs(Monster) $ ",";
	}
}

function string GetMonsters()
{
	local int i;
	local string Monsters;
	local array<string> MonsterNames;
	local SumoSPMonster Monster;
	local BSGameType KF;
	local KFBossSquad Mut;

    KF = BSGameType(Level.Game);
	Mut = KF.MonsterConfigMut;
	MonsterNames = GetPerObjectNames("KFBossSquad", string(class'SumoSPMonster'.Name));
	Monsters = ",";

	for (i=0; i<MonsterNames.Length; i++)
	{
		Monster = Mut.NewGetMonster( MonsterNames[i] );
		Monsters = Monsters $ locs(Monster.Name) $ ",";
	}

	return Monsters;
}

defaultproperties
{
     DefaultsIndexPage="squads_menu"
     DefaultsSquadsPage="defaults_squads"
     DefaultsMonstersPage="defaults_monsters"
     DefaultsBossPage="defaults_boss"
	 NoteSquadsPage="Wave configuration for BSGameType (Sexta Bruta)"
	 NoteMonstersPage="Monsters configuration for BSGameType (Sexta Bruta)"
	 NoteBossPage="Boss configuration for BSGameType (Sexta Bruta)"

     DefaultPage="squadsframe"
     Title="Squads"
     NeededPrivs="Ms"
}

