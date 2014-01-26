class BossSquadMessage extends TimerMessage;

var localized string Message[3];

static function string GetString(
	optional int Switch,
	optional PlayerReplicationInfo RelatedPRI_1,
	optional PlayerReplicationInfo RelatedPRI_2,
	optional Object OptionalObject )
{
    if( Switch > 2 )
    {
        if( RelatedPRI_1.PlayerID == RelatedPRI_2.PlayerID )
            return "You won"@Switch@"pounds!";
        else
            return "Player"@RelatedPRI_2.PlayerName@"won"@Switch@"pounds!";
    }

    return Default.Message[Switch];
}

static function GetPos(int Switch, out EDrawPivot OutDrawPivot, out EStackMode OutStackMode, out float OutPosX, out float OutPosY)
{
	OutDrawPivot = default.DrawPivot;
	OutStackMode = default.StackMode;
	OutPosX = default.PosX;

	switch( Switch )
	{
		case 0:
		case 1:
		case 2:
			OutPosY = 0.45;
			break;
		default:
			OutPosY = 0.70;
			break;
	}
}

static function float GetLifeTime(int Switch)
{
	switch( switch )
	{
		case 0:
		case 1:
			return 1;
		default:
		    return 6;
	}
}

static function RenderComplexMessage(
	Canvas Canvas,
	out float XL,
	out float YL,
	optional string MessageString,
	optional int Switch,
	optional PlayerReplicationInfo RelatedPRI_1,
	optional PlayerReplicationInfo RelatedPRI_2,
	optional Object OptionalObject
	)
{
	local int i;
	local float TempY;

	i = InStr(MessageString, "|");

	TempY = Canvas.CurY;

	if ( switch == 0 || switch == 1 )
        Canvas.Font = class'BSGameType'.Static.LoadBSMessageFont(0);
    else
        Canvas.Font = class'BSGameType'.Static.LoadBSMessageFont(1);

	Canvas.FontScaleX = Canvas.ClipX / 1024.0;
	Canvas.FontScaleY = Canvas.FontScaleX;

	if ( i < 0 )
	{
		Canvas.TextSize(MessageString, XL, YL);
		Canvas.SetPos((Canvas.ClipX / 2.0) - (XL / 2.0), TempY);
		Canvas.DrawTextClipped(MessageString, false);
	}
	else
	{
		Canvas.TextSize(Left(MessageString, i), XL, YL);
		Canvas.SetPos((Canvas.ClipX / 2.0) - (XL / 2.0), TempY);
		Canvas.DrawTextClipped(Left(MessageString, i), false);

		Canvas.TextSize(Mid(MessageString, i + 1), XL, YL);
		Canvas.SetPos((Canvas.ClipX / 2.0) - (XL / 2.0), TempY + YL);
		Canvas.DrawTextClipped(Mid(MessageString, i + 1), false);
	}

	Canvas.FontScaleX = 1.0;
	Canvas.FontScaleY = 1.0;
}

defaultproperties
{
     Message(0)="BOSS TIME!"
     Message(1)="BONUS STAGE!"
     Message(2)="Ten Seconds Remaining!"
     bComplexString=True
     DrawColor=(G=0)
     FontSize=5
}

