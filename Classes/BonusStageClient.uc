Class BonusStageClient extends Emitter;

var Pawn PawnOwner;
var PlayerController PlayerOwner;
var transient float NextDmgTime, InitTime;
var bool bWornOff,bHasInit,bDisableEmitter;

replication
{
	// Variables the server should send to the client.
	reliable if( Role==ROLE_Authority && bNetDirty )
		bWornOff,PawnOwner,bDisableEmitter;
}

function BeginPlay()
{
	PawnOwner = Pawn(Owner);
	PlayerOwner = PlayerController(PawnOwner.Controller);
    if (Class'KFBossSquad'.Default.bEnableLifeBoost)
		PawnOwner.Health = 500;
    if (Class'KFBossSquad'.Default.bEnableGodMode)
        PlayerOwner.bGodMode = true;
    else
    {
        Emitters[0].Disabled = true;
        bDisableEmitter = true;
    }
    SetTimer(3,false);
}
function Timer()
{
	if( !bHasInit )
	{
		bHasInit = true;
		InitTime = Level.TimeSeconds+15;
        SetTimer(Class'KFBossSquad'.Default.BonusStageTime+15,false);
		return;
	}
	Disable('Tick');
	SetTimer(0.f,false);
	bWornOff = true;
	LifeSpan = 0.6f;
	if( Level.NetMode!=NM_DedicatedServer )
		PostNetReceive();
}
function Tick( float Delta )
{
	local Monster M;

	if( InitTime<Level.TimeSeconds && Knife(PawnOwner.Weapon)==None )
		NextDmgTime = Level.TimeSeconds+30;
    if( KFGameType(Level.Game).bWaveInProgress == false )
        Timer();
	else if( PawnOwner==None || PawnOwner.Health<=0 )
		Timer();
	else if( NextDmgTime<Level.TimeSeconds )
	{
		NextDmgTime = Level.TimeSeconds+0.1f;
		foreach VisibleCollidingActors(Class'Monster',M,600,PawnOwner.Location)
			if( IsTouching(M) )
				M.TakeDamage(100,PawnOwner,PawnOwner.Location,vect(0,0,0),Class'DamageType');
	}

	if( PlayerOwner!=None && Class'KFBossSquad'.Default.bEnableGodMode)
		PlayerOwner.bGodMode = true;

	if( PawnOwner!=None && Class'KFBossSquad'.Default.bEnableLifeBoost)
		PawnOwner.Health = 500;
}
final function bool IsTouching( Actor A )
{
	local vector V;

	V = PawnOwner.Location-A.Location;
	if( Abs(V.Z)>(PawnOwner.CollisionHeight+A.CollisionHeight+50.f) )
		return false;
	V.Z = 0;
	return (VSize(V)<(PawnOwner.CollisionRadius+A.CollisionRadius+50.f));
}
function Destroyed()
{
	if( PlayerOwner!=None && Class'KFBossSquad'.Default.bEnableGodMode )
		PlayerOwner.bGodMode = false;
	if( PawnOwner!=None && PawnOwner.Health>100 && Class'KFBossSquad'.Default.bEnableLifeBoost )
		PawnOwner.Health = 100;
}

simulated function PostNetBeginPlay()
{
	if( bWornOff )
		return;
	if( PawnOwner!=None )
		SetOwner(PawnOwner);
    if (bDisableEmitter)
        Emitters[0].Disabled = true;
}
simulated function PostNetReceive()
{
	if( bWornOff )
		Kill();
	if( PawnOwner!=Owner )
		SetOwner(PawnOwner);
}

defaultproperties
{
	Begin Object Class=SpriteEmitter Name=SpriteEmitter0
		FadeOut=True
		FadeIn=True
		SpinParticles=True
		UseSizeScale=True
		UseRegularSizeScale=False
		UniformSize=True
		Acceleration=(Z=60.000000)
		ColorMultiplierRange=(X=(Min=0.700000),Y=(Min=0.000000,Max=0.100000),Z=(Min=0.700000,Max=0.900000))
		FadeOutStartTime=0.150000
		FadeInEndTime=0.100000
		StartLocationRange=(X=(Min=-22.000000,Max=22.000000),Y=(Min=-22.000000,Max=22.000000),Z=(Min=-44.000000,Max=44.000000))
		SpinsPerSecondRange=(X=(Min=-0.100000,Max=0.100000))
		StartSpinRange=(X=(Max=1.000000))
		SizeScale(0)=(RelativeTime=1.000000,RelativeSize=5.000000)
		StartSizeRange=(X=(Min=4.000000,Max=7.000000))
		Texture=Texture'Effects_Tex.explosions.fire_quad'
		LifetimeRange=(Min=0.400000,Max=0.600000)
	End Object
	Emitters(0)=SpriteEmitter'SpriteEmitter0'

	bNoDelete=false
	RemoteRole=ROLE_SimulatedProxy
	Physics=PHYS_Trailer
	bNetNotify=true
}
