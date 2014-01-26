class SumoMidBossSetup extends Object
    PerObjectConfig
    config(KFBossSquad);

var config string BossSquad;
var config bool BonusStage;
var config float PlayerCountScale;

function ResetProperties()
{
	BossSquad="";
	BonusStage=False;
	PlayerCountScale=0.000000;
}

defaultproperties
{
	BossSquad=""
	BonusStage=False
	PlayerCountScale=0.000000
}
