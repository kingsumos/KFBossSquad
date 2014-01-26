class SumoSPMonster extends Object
    PerObjectConfig
    config(KFBossSquad);

var config class<KFMonster> MonsterClass;
var config float SpeedScale;
var config float HealthScale;
var config float HeadHealthScale;
var config float DamageScale;
var config float MotionDetectorThreat;

var string ShortName;
var bool bCustom;

function bool Init()
{
	if( MonsterClass == None )
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
		log("--------------------------------------------------");

		log("Missing MonsterClass configuration for"@self);
		return false;
	}

	ShortName = Locs(MonsterClass.Name);
	if( Locs(Self.Name) != ShortName )
		bCustom = True;
	return true;
}

defaultproperties
{
	SpeedScale = 1.00f;
	HealthScale = 1.00f;
	HeadHealthScale = 1.00f;
	DamageScale = 1.00f;
	MotionDetectorThreat = 0.00f;
}
