#include <sourcemod>
new String:bounty[10][32];
new Handle:bountyhndl;
new bounties=0;
new bool:ml=false;
new String:Error[255];
new String:path[]="addons/sourcemod/data/bounty/";
new String:grammer[]="points";
new Handle:db=INVALID_HANDLE;
public Plugin:myinfo =
{
	name = "Disc-FF Bounty Event",
	author = "SakuraTheBabyfur",
	description = "Bounty event plugin for Disc-FF servers",
	version = "1.0",
	url = "http://www.disc-ff.com"
};
public OnPluginStart()
{
	db = SQL_DefConnect(Error, sizeof(Error));
	if (db == INVALID_HANDLE) PrintToServer("Could not connect: %s", Error)
	if(SQL_FastQuery(db,"CREATE TABLE Bounty(ID int, SteamID varchar(30), Name varchar(60), Points int, PRIMARY KEY (SteamID))")) PrintToServer("Bounty table created successfully.");
	CreateTimer(180.0,message, _,TIMER_REPEAT);
	CreateDirectory(path,7);
	RegConsoleCmd("sm_points", Command_points, "Get your bounty points!");
	RegConsoleCmd("sm_toppoints", Command_toppoints, "See who has the most bounty points!");
	RegAdminCmd("sm_reload_bounty",bounty_reload,ADMFLAG_ROOT,"Reload players with bounty");
	RegAdminCmd("sm_add_bounty",bounty_add,ADMFLAG_ROOT,"Add players to bounty");
	HookEvent("player_death", Event_PlayerDeath);
	loadbounty();
}
public Action:message(Handle:timer)
{
	new rand=GetRandomInt(0,2);
	if(rand==0)PrintToChatAll("\x07000000[Bounty]\x04Type !points to see your points");
	if(rand==1)PrintToChatAll("\x07000000[Bounty]\x04Type !toppoints to see who has the most points");
	return Plugin_Continue;
}
public OnClientDisconnect(client)
{
	new String:Name[MAX_NAME_LENGTH],String:SteamID[MAX_NAME_LENGTH],String:query[300],String:NewName[100];
	GetClientName(client,Name,MAX_NAME_LENGTH);
	GetClientAuthId(client,AuthId_Steam2,SteamID,sizeof(SteamID),true);
	SQL_EscapeString(db,Name,NewName,100);
	Format(query,300,"UPDATE Bounty SET Name='%s' WHERE SteamID='%s'",NewName,SteamID);
	SQL_FastQuery(db,query);
}
public OnClientAuthorized(client,const String:auth[])
{
	new String:query[300],String:name[MAX_NAME_LENGTH],String:NewName[100];
	GetClientName(client,name,MAX_NAME_LENGTH);
	SQL_EscapeString(db,name,NewName,100);
	Format(query,300,"INSERT INTO Bounty (Name,SteamID,Points) VALUES ('%s','%s','0')",NewName,auth);
	SQL_FastQuery(db,query);
	for(new i=0;i<=bounties;i++)
	{
		if(StrEqual(auth,bounty[i],false))
		{
			for (new a = 1; a <= MaxClients; a++)
			{
				if(IsClientInGame(a)&&(!IsFakeClient(a))) ClientCommand(a, "playgamesound vo/Announcer_attention.wav");
			}
			PrintHintTextToAll("A player with a bounty has joined!");
		}
	}
}
public hMenu(Handle:xmenu,MenuAction:action,param1,param2)
{
}
public Action:Command_toppoints(client, args)
{
	new Handle:pointsquery=INVALID_HANDLE;
	new Handle:menu = CreateMenu(hMenu);
	new String:Name[65],String:text[100];
	SetMenuTitle(menu, "Top Players");
	pointsquery=SQL_Query(db,"SELECT Name,Points FROM Bounty ORDER BY Points DESC");
	if (pointsquery == INVALID_HANDLE)
	{
		new String:error[255]
		SQL_GetError(db, error, sizeof(error))
		PrintToServer("Failed to query (error: %s)", error)
		PrintToChat(client,"Error! %s",error);
	}
	else
	{
		for(new x=0;x<3;x++)
		{
			if(!SQL_FetchRow(pointsquery)) continue;
			SQL_FetchString(pointsquery,0,Name,65);
			Format(text,100,"%s: %i Points",Name,SQL_FetchInt(pointsquery,1));
			AddMenuItem(menu, text, text,ITEMDRAW_DISABLED);
		}
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, 20);
	}
	CloseHandle(pointsquery);
	return Plugin_Handled;
}
public Action:Command_points(client, args) 
{
	new String:auth[32],String:query[300];
	GetClientAuthId(client,AuthId_Steam2,auth, sizeof(auth), true);
	Format(query,300,"SELECT Points FROM Bounty WHERE SteamID='%s'",auth);
	new Handle:mypoints=SQL_Query(db,query);
	if (mypoints == INVALID_HANDLE)
	{
		new String:error[255]
		SQL_GetError(db, error, sizeof(error))
		PrintToServer("Failed to query (error: %s)", error)
		PrintToChat(client,"Error! %s",error);
	}
	else
	{
		SQL_FetchRow(mypoints);
		new points=SQL_FetchInt(mypoints,0);
		if(points==1) grammer="point";
		else grammer="points";
		if(points==0) PrintToChat(client,"\x07000000[Bounty]\x04You have 0 points! Kill people with bounties to collect points");
		else PrintToChat(client,"\x07000000[Bounty]\x04You have %i %s",points,grammer);
	}
	CloseHandle(mypoints);
	return Plugin_Handled;
}
public Action:bounty_reload(client, args)
{
	loadbounty();
	ReplyToCommand(client,"\x07000000[Bounty]\x04Reloaded Bounties");
	return Plugin_Handled;
}
public Event_PlayerDeath(Handle:event,const String:name[],bool:dontBroadcast)
{
	new attacker=GetClientOfUserId(GetEventInt(event,"attacker"));
	new client=GetClientOfUserId(GetEventInt(event,"userid"));
	if(attacker!=client&&attacker!=0)
	{
		new String:attackername[MAX_NAME_LENGTH], String:attackerid[MAX_NAME_LENGTH], String:clientname[MAX_NAME_LENGTH], String:auth[MAX_NAME_LENGTH];
		GetClientName(client,clientname,MAX_NAME_LENGTH);
		GetClientName(attacker,attackername,MAX_NAME_LENGTH);
		GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth), true);
		for(new i=0;i<=bounties;i++)
		{
			if(StrEqual(auth,bounty[i],false))
			{
				PrintToChat(attacker,"\x07000000[Bounty]\x04You got 1 point for killing %s",clientname);
				if(!(GetEventInt(event, "death_flags") & 32))
				{
					GetClientAuthId(attacker, AuthId_Steam2,attackerid, sizeof(attackerid), true);
					new String:query[200];
					Format(query,200,"UPDATE Bounty SET Points=Points+1,Name='%s' WHERE SteamID='%s'",attackername,attackerid);
					SQL_Query(db,query);
				}
			}
		}
	}
}
public loadbounty()
{
	bountyhndl=OpenFile("addons/sourcemod/data/bounty/bounty.txt","rt");
	if(bountyhndl==INVALID_HANDLE)
	{
		PrintToServer("Bounty file created");
		OpenFile("addons/sourcemod/data/bounty/bounty.txt","w");
		bountyhndl=OpenFile("addons/sourcemod/data/bounty/bounty.txt","rt");
	}
	new String:linedata[32];
	bounties=0;
	while(ReadFileLine(bountyhndl,linedata,sizeof(linedata)))
	{
		TrimString(linedata);
		bounty[bounties]=linedata;
		bounties++
	}
	CloseHandle(bountyhndl);
	PrintToServer("Loaded Bounties"); 
}
public Action:bounty_add(client, args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "\x07000000[Bounty]\x04Usage: sm_add_bounty <target>");
		return Plugin_Handled;
	}
	decl String:pattern[MAX_NAME_LENGTH],String:buffer[MAX_NAME_LENGTH];
	GetCmdArg(1,pattern,sizeof(pattern));
	new targets[32];
	new count = ProcessTargetString(pattern,client,targets,sizeof(targets),COMMAND_FILTER_CONNECTED,buffer,sizeof(buffer),ml);
	if (count <= 0) ReplyToCommand(client,"\x07000000[Bounty]\x04Bad target");
	else for (new i = 0; i < count; i++)
	{
		new t = targets[i];
		new String:auth[MAX_NAME_LENGTH]="Failure2";
		GetClientAuthId(t, AuthId_Steam2, auth, sizeof(auth), true);
		new bool:found=false;
		for(new a=0;a<bounties;a++)
		{
			if(StrEqual(auth,bounty[a]))
			{
				ReplyToCommand(client,"\x07000000[Bounty]\x04User already has a bounty!");
				found=true;
			}
		}
		if(found!=true)
		{
			bountyhndl=OpenFile("addons/sourcemod/data/bounty/bounty.txt","at");
			new String:name[MAX_NAME_LENGTH];
			GetClientName(t, name, MAX_NAME_LENGTH);
			bounty[bounties]=auth;
			bounties++;
			if(WriteFileLine(bountyhndl,auth)) ReplyToCommand(client,"\x07000000[Bounty]\x04Added a bounty to %s",name);
			else ReplyToCommand(client,"Failure");
			CloseHandle(bountyhndl);
		}
	}
	return Plugin_Handled;
}