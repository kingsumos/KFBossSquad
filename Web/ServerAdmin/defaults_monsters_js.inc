<script type="text/JavaScript">
var submitAction;
var MonsterList = "<%MonsterList%>";
var InUseMonsterList = "<%InUseMonsterList%>";

function setSubmitAction(name)
{
	submitAction = name;
}
function validateModifyMonster(oForm)
{
	for (i = 0; i < oForm.length; i++) {
		var value = oForm.elements[i].value.toLowerCase();
		var valueFloat = 0;
		if( value !== "" ) {
			var match = /^([0-9]*[.]*[0-9]+)$/g.exec(value);
			if( match ) {
				valueFloat = parseFloat(match[1]);
			}
		}

		switch(oForm.elements[i].name)
		{
			case "MonsterAlias":
				if( submitAction === "Delete" ) {
					if( InUseMonsterList.indexOf("," + value + ",") !== -1 ) {
						alert("ERROR: can't delete: monster already in use by some squad");
						return false;
					}
				}
				break;
			case "MonsterClass":
				// readonly, validation not needed
				break;
			case "HeadHealthScale":
				if( submitAction === "Update" ) {
					if( valueFloat === 0 ) {
						alert("ERROR: head health multiplier: please enter a number greater than zero");
						return false;
					}
				}
				break;
			case "HealthScale":
				if( submitAction === "Update" ) {
					if( valueFloat === 0 ) {
						alert("ERROR: body health multiplier: please enter a number greater than zero");
						return false;
					}
				}
				break;
			case "SpeedScale":
				if( submitAction === "Update" ) {
					if( valueFloat === 0 ) {
						alert("ERROR: speed multiplier: please enter a number greater than zero");
						return false;
					}
				}
				break;
			case "DamageScale":
				if( submitAction === "Update" ) {
					if( valueFloat === 0 ) {
						alert("ERROR: damage multiplier: please enter a number greater than zero");
						return false;
					}
				}
				break;
		};
	}
}
function validateNewMonster(oForm)
{
	for (i = 0; i < oForm.length; i++) {
		var value = oForm.elements[i].value.toLowerCase();
		var valueFloat = 0;
		if( value !== "" ) {
			var match = /^([0-9]*[.]*[0-9]+)$/g.exec(value);
			if( match ) {
				valueFloat = parseFloat(match[1]);
			}
		}

		switch(oForm.elements[i].name)
		{
			case "MonsterAlias":
				if( MonsterList.indexOf("," + value + ",") !== -1 ) {
					alert("ERROR: monster alias '" + value + "' is already in use");
					return false;
				}
				break;
			case "MonsterClass":
				if( value==="" || value.indexOf(".")===-1 ) {
					alert("ERROR: please enter a valid monster class, format: package.class");
					return false;
				}
				break;
			case "HeadHealthScale":
				if( valueFloat === 0 ) {
					alert("ERROR: head health multiplier: please enter a number greater than zero");
					return false;
				}
				break;
			case "HealthScale":
				if( valueFloat === 0 ) {
					alert("ERROR: body health multiplier: please enter a number greater than zero");
					return false;
				}
				break;
			case "SpeedScale":
				if( valueFloat === 0 ) {
					alert("ERROR: speed multiplier: please enter a number greater than zero");
					return false;
				}
				break;
			case "DamageScale":
				if( valueFloat === 0 ) {
					alert("ERROR: damage multiplier: please enter a number greater than zero");
					return false;
				}
				break;
		};
  }
}
function validateGeneral(oForm)
{
	for (i = 0; i < oForm.length; i++) {
		if( oForm.elements[i].name === "WaveMaxMonsters" ) {
			var value = oForm.elements[i].value;
			var valueInt = 0;
			if( value !== "" ) {
				var match = /^([0-9]+)$/g.exec(value);
				if( match ) {
					valueInt = parseInt(match[1]);
				}
			}
			if( valueInt === 0 ) {
				alert("ERROR: invalid Number of monsters value: " + value);
				return false;
			}
		}
	}
}
function validateNewSquad(oForm)
{
	for (i = 0; i < oForm.length; i++) {
		var value = oForm.elements[i].value.toLowerCase();
		if( value !== "" )
		{
			var match = /^Monster(Num|Name)([0-9]+).*/g.exec(oForm.elements[i].name);
			if( match )
			{
				if( match[1] === "Name" )
				{
					if( MonsterList.indexOf("," + value + ",") === -1 ) {
						alert("ERROR: monster alias '" + value + "' does not exists!");
						return false;
					}
					break;
				}
				else if( match[1] === "Num" )
				{
					// TODO : squad spawn may fail (i.e. Num>MaxZombiesOnce)
					console.log(match[1] + '=' + parseInt(value));
				}
			}
		}
	}
}
function validateBoss(oForm)
{
	for (i = 0; i < oForm.length; i++) {
		if( oForm.elements[i].name === "EndGameBoss" ) {
			var value = oForm.elements[i].value.toLowerCase();
			if( MonsterList.indexOf("," + value + ",") === -1 ) {
				alert("ERROR: EndGameBoss monster alias '" + value + "' does not exists!");
				return false;
			}
			break;
		}
	}

	// TODO : validate empty boss buddy squads...

	return validateNewSquad(oForm);
}
function validateModifySquad(oForm)
{
	return validateNewSquad(oForm);
}
</script>
