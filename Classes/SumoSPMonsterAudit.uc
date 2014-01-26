Class SumoSPMonsterAudit extends Actor;

var KFMonster Monster;
var KFMonsterController Controller;
var bool bBoss;

var BSGameType GT;

var transient float ValidKillTime;
var bool bInitKill;
var byte NoneSightCount;

function BeginPlay()
{
	Monster = KFMonster(Owner);
	if( ZombieBoss(Owner)!=None )
		bBoss = True;

    GT = BSGameType(Level.Game);
	SetTimer(1,True);
}

function Timer()
{
    if( Monster == None )
    {
        Destroy();
        return;
    }
}

function bool CanKillMeYet()
{
	local Controller C;

    if( Monster == None )
        return false;

	if( bBoss )
		return false;

	if( !bInitKill )
	{
		bInitKill = true;
		ValidKillTime = Level.TimeSeconds+60.f;
		return false;
	}
	else if( ValidKillTime>Level.TimeSeconds )
		return false;

	for( C=Level.ControllerList; C!=None; C=C.nextController )
	{
		if( C.bIsPlayer && C.PlayerReplicationInfo!=None && C.Pawn!=None && C.Pawn.Health>0 && C.LineOfSightTo(Monster) )
		{
			if( NoneSightCount>=5 )
			{
				Monster.OriginalGroundSpeed = Monster.Default.GroundSpeed;
				Monster.GroundSpeed = Monster.Default.GroundSpeed;
			}
			NoneSightCount = 0;
			return false;
		}
	}
	if( NoneSightCount>=5 ) // Walk faster to find players.
	{
		Monster.OriginalGroundSpeed = FMax(Monster.GroundSpeed,300.f);
		Monster.GroundSpeed = Monster.OriginalGroundSpeed;
	}

    if( GT != None && GT.bBossSquadRequested )
	    return (++NoneSightCount>60);
    else
	    return (++NoneSightCount>15);
}

defaultproperties
{
    bHidden=1
    bAlwaysRelevant=False
    bUpdateSimulatedPosition=False
}

