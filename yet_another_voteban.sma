/*	Yet Another Voteban AMXX Plugin
*
*	— удобный и симпатичный голосовальщик за бан игроков
*	для Ваших великолепных серверов Counter-Strike 1.6.
*
*
* 	Авторы: AndrewZ и voed.
*
*
*	Поддержка осуществляется тут:
*		http://c-s.net.ua/forum/topic69366s0.html
*
*
*	Переменные плагина:
*
*		yav_time_default "5" 		— стандартное время бана в минутах, доступное для простых смертных (1 значение).
*		yav_time "5 15 30 60 180" 	— дополнительное время бана для игроков с флагом доступа "yav_time_access" (от 1 до 5 значений, через пробел).
*		yav_ban_type "1" 			— тип бана: -2 = BANID (STEAMID); -1 = ADDIP; 1 = AMXBANS; 2 = FRESHBANS; 3 = ADVANCED BANS; 4 = SUPERBAN; 5 = MULTIBAN.
*		yav_delay "5" 				— задержка между голосованиями, в минутах.
*		yav_duration "15"			— длительность голосования.
*		yav_percent "60"			— необходимый процент проголосовавших игроков для осуществления бана (1-100).
*		yav_min_players "3"			— минимум игроков на сервере для возможности открыть меню голосования.
*		yav_spec_admins "0"			— учитывать ли админов в команде наблюдателей как активных админов. (1 - учитывать, 0 - пропускать)
*		yav_roundstart_delay "-1"	— блокировка вызова голосования в начале раунда, в секундах. (Целое или дробное положительное значение - блокировка на указанное время, "-1" - блокировка до конца mp_buytime, "0" - отключить, не блокировать)
*		yav_access ""				— флаг доступа к меню голосования. (Можно указать несколько: "abc", либо оставить пустым "", чтобы разрешить использовать всем).
*		yav_time_access "c"			— флаг доступа к выбору времени бана и к голосованию без кулдауна. (Можно указать несколько: "abc", либо оставить пустым "", чтобы отключить).
*		yav_admin_access "d"		— флаг админа для блока голосования и включения оповещения админов. (Можно указать несколько: "abc", либо оставить пустым "", чтобы отключить).
*		yav_immunity_access "a"		— флаг иммунитета к вотебану. (Можно указать несколько: "abc", либо оставить пустым "", чтобы отключить).
*		yav_log_to_file "1"			— логирование банов в файл "addons\amxmodx\logs". Название логов "YAV_ГГГГДДММ.log".
*/

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

#define PLUGIN		"Yet Another Voteban"
#define VERSION		"1.61"
#define AUTHOR		"AndrewZ/voed"

#define PDATA_SAFE			2
#define OFFSET_LINUX		5
#define OFFSET_CSMENUCODE	205

#define MAX_PLAYERS		32
#define MSGS_PREFIX		"YAV"

#define TID_ENDVOTE 	5051
#define TID_BLOCKVOTE 	5052

enum
{
	MENU_SOUND_SELECT, // 0
	MENU_SOUND_DENY, // 1
	MENU_SOUND_SUCCESS // 2
}

new g_pcvr_DefaultTime, g_pcvr_Time, g_pcvr_BanType, g_pcvr_Delay,
	g_pcvr_Duration, g_pcvr_Percent, g_pcvr_MinPlayers, g_pcvr_SpecAdmins,
	g_pcvr_RoundStartDelay, g_pcvr_mpBuyTime,
	g_pcvr_Access, g_pcvr_TimeAccess, g_pcvr_AdminAccess, g_pcvr_ImmunityAccess,
	g_pcvr_LogToFile

new g_szMenuSounds[][] =
{
	"buttons/lightswitch2.wav", // 0
	"buttons/button2.wav", // 1
	"buttons/blip1.wav" // 2
}

new g_szUserReason[ MAX_PLAYERS + 1 ][ 26 ],
	g_iUserSelectedID[ MAX_PLAYERS + 1 ],
	g_iUserBanTime[ MAX_PLAYERS + 1 ],
	g_iTotalVotes[ MAX_PLAYERS + 1 ],
	g_iUserGametime[ MAX_PLAYERS + 1 ]

new g_szInitiator[ 3 ][ 35 ],
	g_iBanID,
	g_iBanTime,
	g_szBanReason[ 26 ]
	
new bool:g_bIsVoteStarted, bool:g_bIsVoteBlocked
new g_szParsedCvarTime[ 5 ][ 8 ]

public plugin_precache()
{
	new i
	
	for( i = 0; i < sizeof g_szMenuSounds; i ++ )
		precache_sound( g_szMenuSounds[ i ] )
}

public plugin_init()
{
	register_plugin( PLUGIN, VERSION, AUTHOR )
	
	g_pcvr_DefaultTime = 		register_cvar( "yav_time_default", "5" )
	g_pcvr_Time = 				register_cvar( "yav_time", "5 15 30 60 180" )
	g_pcvr_BanType = 			register_cvar( "yav_ban_type", "2" )
	g_pcvr_Delay = 				register_cvar( "yav_delay", "5" )
	g_pcvr_Duration =			register_cvar( "yav_duration", "15" )
	g_pcvr_Percent = 			register_cvar( "yav_percent", "60" )
	g_pcvr_MinPlayers = 		register_cvar( "yav_min_players", "3" )
	g_pcvr_SpecAdmins = 		register_cvar( "yav_spec_admins", "0" )
	g_pcvr_RoundStartDelay =	register_cvar( "yav_roundstart_delay", "-1" )
	g_pcvr_Access = 			register_cvar( "yav_access", "" )
	g_pcvr_TimeAccess = 		register_cvar( "yav_time_access", "c" )
	g_pcvr_AdminAccess = 		register_cvar( "yav_admin_access", "d" )
	g_pcvr_ImmunityAccess = 	register_cvar( "yav_immunity_access", "a" )
	g_pcvr_LogToFile =			register_cvar( "yav_log_to_file", "1" )
	
	g_pcvr_mpBuyTime = 			register_cvar( "mp_buytime", "" )
	
	register_event( "HLTV", "event_newround", "a", "1=0", "2=0" )
	
	register_clcmd( "say /voteban", "show_voteban_players_menu" )
	register_clcmd( "say_team /voteban", "show_voteban_players_menu" )
	register_clcmd( "amx_votebanmenu", "show_voteban_main_menu" )
	
	register_clcmd( "voteban_reason", "cmd_voteban_reason" )

	register_dictionary( "yet_another_voteban.txt" )
}

public plugin_cfg()
{
	new szData[ 44 ]; get_pcvar_string( g_pcvr_Time, szData, charsmax( szData ) )
	
	parse( szData,	g_szParsedCvarTime[ 0 ], 7, 
					g_szParsedCvarTime[ 1 ], 7, 
					g_szParsedCvarTime[ 2 ], 7, 
					g_szParsedCvarTime[ 3 ], 7,
					g_szParsedCvarTime[ 4 ], 7 )
}

public event_newround()
{
	new Float:fCvar
	fCvar = get_pcvar_float( g_pcvr_RoundStartDelay )
	
	if( fCvar == 0.0 )
		return

	if( task_exists( TID_BLOCKVOTE ) )
		remove_task( TID_BLOCKVOTE )
	
	if( fCvar == -1.0 )
		fCvar = get_pcvar_float( g_pcvr_mpBuyTime ) * 60
	
	g_bIsVoteBlocked = true
	set_task( fCvar, "task_unblock_vote", TID_BLOCKVOTE )
}

public task_unblock_vote()
	g_bIsVoteBlocked = false
	
public client_connect( id )
	clear_user_voteban_data( id )

public client_disconnect( id )
	clear_user_voteban_data( id )

public clear_user_voteban_data( id )
{
	g_iUserSelectedID[ id ] = 0
	g_iUserBanTime[ id ] = get_pcvar_num( g_pcvr_DefaultTime )
	arrayset( g_szUserReason[ id ], 0, sizeof( g_szUserReason ) )
	
	if( g_iBanID == id )
		clear_voteban_data()
}

public clear_voteban_data()
{
	if( task_exists( TID_ENDVOTE ) )
		remove_task( TID_ENDVOTE )
	
	g_bIsVoteStarted = false
	g_iBanID = 0
	g_iBanTime = 0
	arrayset( g_szBanReason, 0, sizeof( g_szBanReason ) )
	arrayset( g_iTotalVotes, 0, MAX_PLAYERS + 1 )
}

public cmd_voteban_reason( id )
{
	new i, szArgs[ 26 ], szBlock[][] = { "!g", "!y", "!t", "%", "#", "", "", "", "" }
	
	read_args( szArgs, charsmax( szArgs ) )
	remove_quotes( szArgs )
	
	for( i = 0; i < sizeof( szBlock ); i ++ )
		replace_all( szArgs, charsmax( szArgs ), szBlock[ i ], "" )
	
	g_szUserReason[ id ] = szArgs
	
	show_voteban_main_menu( id )
	
	return PLUGIN_HANDLED
}

public show_voteban_players_menu( id )
{
	if( !is_voteban_available( id ) )
		return PLUGIN_HANDLED
	
	new iMenu, i, szTemp[ 64 ], szName[ 32 ], szFlags[ 23 ], szId[ 3 ]
	
	formatex( szTemp, charsmax( szTemp ), "\y%L\R", id, "VOTEBAN_MENU_PLAYERS_TITLE" ) // Выбор игрока
	iMenu = menu_create( szTemp, "handler_voteban_players_menu" )
	
	for( i = 1; i <= MAX_PLAYERS; i ++ )
	{
		if( !get_user_status( i ) || ( i == id ) )
			continue
		
		get_user_name( i, szName, charsmax( szName ) )
		get_pcvar_string( g_pcvr_ImmunityAccess, szFlags, charsmax( szFlags ) )
		
		if( get_user_flags( i ) & read_flags( szFlags ) )
			formatex( szTemp, charsmax( szTemp ), "\d%s \r*", szName )
		else
			formatex( szTemp, charsmax( szTemp ), "\w%s", szName )
		
		num_to_str( i, szId, charsmax( szId ) )
		
		menu_additem( iMenu, szTemp, szId, ADMIN_ALL )
	}
	
	if( !menu_items( iMenu ) )
	{
		menu_destroy( iMenu )
		return PLUGIN_HANDLED
	}
	
	formatex( szTemp, charsmax( szTemp ), "%L", id, "VOTEBAN_MENU_BACK" )
	menu_setprop( iMenu, MPROP_BACKNAME, szTemp )
	
	formatex( szTemp, charsmax( szTemp ), "%L", id, "VOTEBAN_MENU_NEXT" )
	menu_setprop( iMenu, MPROP_NEXTNAME, szTemp )
	
	formatex( szTemp, charsmax( szTemp ), "%L", id, "VOTEBAN_MENU_EXIT" )
	menu_setprop( iMenu, MPROP_EXITNAME, szTemp )
	
	menu_setprop( iMenu, MPROP_NUMBER_COLOR, "\w" )
	
	if( pev_valid( id ) == PDATA_SAFE )
		set_pdata_int( id, OFFSET_CSMENUCODE, 0, OFFSET_LINUX )
	
	menu_display( id, iMenu, 0 )
	
	return PLUGIN_HANDLED
}

public handler_voteban_players_menu( id, iMenu, iItem )
{
	if( !is_voteban_available( id ) || ( iItem == MENU_EXIT ) )
	{
		menu_destroy( iMenu )
		client_spk( id, MENU_SOUND_SELECT )
		
		return PLUGIN_HANDLED
	}
	
	new szData[ 3 ], szName[ 32 ], iAccess, iCallback, sId
	menu_item_getinfo( iMenu, iItem, iAccess, szData, charsmax( szData ), szName, charsmax( szName ), iCallback )
	
	sId = str_to_num( szData )
	
	if( get_user_status( sId ) )
	{
		new szFlags[ 23 ]
		get_pcvar_string( g_pcvr_ImmunityAccess, szFlags, charsmax( szFlags ) )
	
		if( !( get_user_flags( sId ) & read_flags( szFlags ) ) )
		{
			g_iUserSelectedID[ id ] = sId
			show_voteban_main_menu( id )
			client_spk( id, MENU_SOUND_SELECT )
		}
		else
		{
			show_voteban_players_menu( id )
			yet_another_print_color( id, "%L", id, "VOTEBAN_IMMUNITY" ) // Выбранный игрок имеет иммунитет к бану.
			client_spk( id, MENU_SOUND_DENY )
		}
	}
	else
	{
		yet_another_print_color( id, "%L", id, "VOTEBAN_LEAVE" ) // Выбранный игрок недоступен для выбора, возможно он покинул сервер.
		client_spk( id, MENU_SOUND_DENY )
	}

	menu_destroy( iMenu )
	
	return PLUGIN_HANDLED
}

public show_voteban_main_menu( id )
{
	if( !is_voteban_available( id ) )
		return PLUGIN_HANDLED
	
	new iMenu, szTemp[ 64 ], sId
	
	sId = g_iUserSelectedID[ id ]
	
	formatex( szTemp, charsmax( szTemp ), "\y%L", id, "VOTEBAN_MENU_TITLE" ) // Голосование за бан
	iMenu = menu_create( szTemp, "handler_voteban_main_menu" )

// === 1 ===

	if( get_user_status( sId ) )
	{
		new szName[ 32 ]
		get_user_name( sId, szName, charsmax( szName ) )
		
		formatex( szTemp, charsmax( szTemp ), "%L \y%s", id, "VOTEBAN_MENU_PLAYER", szName ) // Игрок:
	}
	else formatex( szTemp, charsmax( szTemp ), "%L \d%L", id, "VOTEBAN_MENU_PLAYER", id, "VOTEBAN_MENU_SELECT_PLAYER" ) // Выбрать игрока

	menu_additem( iMenu, szTemp, "1", ADMIN_ALL )
	
// =========
	

// === 2 ===

	if( g_szUserReason[ id ][ 0 ] )
		formatex( szTemp, charsmax( szTemp ), "%L \y%s^n", id, "VOTEBAN_MENU_REASON", g_szUserReason[ id ] ) // Причина
		
	else formatex( szTemp, charsmax( szTemp ), "%L \d%L^n", id, "VOTEBAN_MENU_REASON", id, "VOTEBAN_MENU_ENTER_REASON"  ) // Причина || Ввести причину бана
	
	menu_additem( iMenu, szTemp, "2", ADMIN_ALL )
	
// =========
	

// === 3 ===

	new szFlags[ 23 ]
	get_pcvar_string( g_pcvr_TimeAccess, szFlags, charsmax( szFlags ) )
	
	if( get_user_flags( id ) & read_flags( szFlags ) )
	{
		formatex( szTemp, charsmax( szTemp ), "%L \y%i %L^n", id, "VOTEBAN_MENU_TIME", g_iUserBanTime[ id ], id, "VOTEBAN_MENU_MINUTES" ) // Время бана || минут
		menu_additem( iMenu, szTemp, "3", ADMIN_ALL )
	}
	
// =========

// === 4 ===
	
	new iAdmins = get_admins_online()
	
	if( iAdmins )
		formatex( szTemp, charsmax( szTemp ), "%L", id, "VOTEBAN_MENU_NOTIFY", iAdmins ) // Сообщить администратору (\y%d в сети\w)
	else
		formatex( szTemp, charsmax( szTemp ), "%L", id, "VOTEBAN_MENU_START_VOTE" ) // Начать голосование
	
	menu_additem( iMenu, szTemp, "4", ADMIN_ALL )
	
// =========

	
	formatex( szTemp, charsmax( szTemp ), "%L", id, "VOTEBAN_MENU_EXIT" )
	menu_setprop( iMenu, MPROP_EXITNAME, szTemp )
	
	menu_setprop( iMenu, MPROP_NUMBER_COLOR, "\w" )
	
	if( pev_valid( id ) == PDATA_SAFE )
		set_pdata_int( id, OFFSET_CSMENUCODE, 0, OFFSET_LINUX )
	
	menu_display( id, iMenu, 0 )
	
	return PLUGIN_HANDLED
}

public handler_voteban_main_menu( id, iMenu, iItem )
{
	if( !is_voteban_available( id ) || ( iItem == MENU_EXIT ) )
	{
		menu_destroy( iMenu )
		clear_user_voteban_data( id )
		client_spk( id, MENU_SOUND_SELECT )
		
		return PLUGIN_HANDLED
	}
	
	new szData[ 3 ], szName[ 32 ], iAccess, iCallback, iKey
	menu_item_getinfo( iMenu, iItem, iAccess, szData, charsmax( szData ), szName, charsmax( szName ), iCallback )
	
	iKey = str_to_num( szData )
	
	switch( iKey )
	{
		case 1:
		{
			show_voteban_players_menu( id )
			client_spk( id, MENU_SOUND_SELECT )
		}
		
		case 2: 
		{
			client_cmd( id, "messagemode voteban_reason" )
			client_spk( id, MENU_SOUND_SELECT )
		}
		
		case 3:
		{
			show_voteban_time_menu( id )
			client_spk( id, MENU_SOUND_SELECT )
		}
		
		case 4:
		{
			new sId = g_iUserSelectedID[ id ]
			
			if( !get_user_status( sId ) )
			{
				yet_another_print_color( id, "%L",  id, "VOTEBAN_NEED_PLAYER" ) // Вы должны выбрать игрока
				show_voteban_main_menu( id )
				client_spk( id, MENU_SOUND_DENY )
			}
			
			else if( !g_szUserReason[ id ][ 0 ] )
			{
				yet_another_print_color( id, "%L",  id, "VOTEBAN_NEED_REASON" ) // Вы должны ввести причину бана
				show_voteban_main_menu( id )
				client_spk( id, MENU_SOUND_DENY )
			}
			
			else
			{	
				new szFlags[ 23 ], iAdmins = get_admins_online()
				
				if( iAdmins )
				{
					new i, szSelectedName[ 32 ], szName[ 32 ]
					
					for( i = 1; i <= MAX_PLAYERS; i ++ )
					{
						get_pcvar_string( g_pcvr_AdminAccess, szFlags, charsmax( szFlags ) )
		
						if( !get_user_status( i ) || !( get_user_flags( i ) & read_flags( szFlags ) ) )
							continue
							
						get_user_name( sId, szSelectedName, charsmax( szSelectedName ) )
						get_user_name( id, szName, charsmax( szName ) )
						yet_another_print_color( i, "%L",  i, "VOTEBAN_ADMIN_NOTIFICATION", szName, szSelectedName, g_szUserReason[ id ] ) // %s хочет забанить %s за "%s".
						client_spk( i, MENU_SOUND_SUCCESS )
					}
					
					yet_another_print_color( id, "%L",  id, "VOTEBAN_ADMIN_NOTIFIED", iAdmins ) // Администраторов уведомлено о вашей жалобе: %d.
					client_spk( id, MENU_SOUND_SUCCESS )
					clear_user_voteban_data( id )
					
					return PLUGIN_HANDLED
				}
				
				get_pcvar_string( g_pcvr_TimeAccess, szFlags, charsmax( szFlags ) )
				
				get_user_name( id, g_szInitiator[ 0 ], 34 )
				get_user_ip( id, g_szInitiator[ 1 ], 34, 1 )
				get_user_authid( id, g_szInitiator[ 2 ], 34 )
				
				g_iBanID = sId
				g_szBanReason = g_szUserReason[ id ]
				
				if( get_user_flags( id ) & read_flags( szFlags ) )
					g_iBanTime = g_iUserBanTime[ id ]
				
				else g_iBanTime = get_pcvar_num( g_pcvr_DefaultTime )
				
				clear_user_voteban_data( id )
				
				g_bIsVoteStarted = true
				
				show_voteban_menu( id )
				
				g_iUserGametime[ id ] = floatround( get_gametime() )
				set_task( get_pcvar_float( g_pcvr_Duration ), "task_end_vote", TID_ENDVOTE )
			}
		}
	}
	
	menu_destroy( iMenu )
	
	return PLUGIN_HANDLED
}

public show_voteban_time_menu( id )
{
	new iMenu, i, szTemp[ 190 ]

	formatex( szTemp, charsmax( szTemp ), "\y%L", id, "VOTEBAN_MENU_TIME_TITLE" ) // Выбор срока бана
	iMenu = menu_create( szTemp, "handler_voteban_time_menu" )

	for( i = 0; i < sizeof( g_szParsedCvarTime ); i ++ )
	{
		if( !g_szParsedCvarTime[ i ][ 0 ] )
			break
		
		formatex( szTemp, charsmax( szTemp ), "%s %L", g_szParsedCvarTime[ i ], id, "VOTEBAN_MENU_MINUTES" ) // минут
		
		menu_additem( iMenu, szTemp, "", ADMIN_ALL )
	}
	
	formatex( szTemp, charsmax( szTemp ), "%L", id, "VOTEBAN_MENU_EXIT" )
	menu_setprop( iMenu, MPROP_EXITNAME, szTemp )
	
	menu_setprop( iMenu, MPROP_NUMBER_COLOR, "\w" )
	
	if( pev_valid( id ) == PDATA_SAFE )
		set_pdata_int( id, OFFSET_CSMENUCODE, 0, OFFSET_LINUX )
	
	menu_display( id, iMenu, 0 )
	
	return PLUGIN_HANDLED
}

public handler_voteban_time_menu( id, iMenu, iItem )
{
	if( !is_voteban_available( id ) || ( iItem == MENU_EXIT ) )
	{
		menu_destroy( iMenu )
		clear_user_voteban_data( id )
		client_spk( id, MENU_SOUND_SELECT )
		
		return PLUGIN_HANDLED
	}
	
	switch( iItem )
	{
		case 0..4: g_iUserBanTime[ id ] = str_to_num( g_szParsedCvarTime[ iItem ] )
	}
	
	show_voteban_main_menu( id )
	client_spk( id, MENU_SOUND_SELECT )
	
	menu_destroy( iMenu )
	
	return PLUGIN_HANDLED
}

public show_voteban_menu( id )
{
	new i
	
	for( i = 1; i <= MAX_PLAYERS; i ++ )
	{
		if( !get_user_status( i ) || i == g_iBanID )
			continue
		
		new szName[ 32 ], szBanName[ 32 ]
		get_user_name( id, szName, charsmax( szName ) )
		get_user_name( g_iBanID, szBanName, charsmax( szBanName ) )

		client_spk( i, MENU_SOUND_SUCCESS )
		yet_another_print_color( i, "%L", i, "VOTEBAN_WHO_START", szName, szBanName, g_szBanReason ) // начал голосование за бан
		
  		if( i == id )
		{
			add_vote( id )
			continue
		}
		
		new iMenu, szTemp[ 64 ]
		
		formatex( szTemp, charsmax( szTemp ), "\y%L", i, "VOTEBAN_MENU_TITLE" ) // Голосование за бан
		iMenu = menu_create( szTemp, "handler_voteban_menu" )
		
		formatex( szTemp, charsmax( szTemp ), "%L", i, "VOTEBAN_MENU_YES" )
		menu_additem( iMenu, szTemp, "", ADMIN_ALL )
		
		formatex( szTemp, charsmax( szTemp ), "%L", i, "VOTEBAN_MENU_NO" )
		menu_additem( iMenu, szTemp, "", ADMIN_ALL )
		
		menu_addblank( iMenu, 1 )
		
		formatex( szTemp, charsmax( szTemp ), "\w%L \y%s", i, "VOTEBAN_MENU_PLAYER", szBanName ) // Игрок
		menu_addtext( iMenu, szTemp, 1 )
		
		formatex( szTemp, charsmax( szTemp ), "\w%L \y%s", i, "VOTEBAN_MENU_REASON", g_szBanReason ) // Причина
		menu_addtext( iMenu, szTemp, 1 )
		
		formatex( szTemp, charsmax( szTemp ), "\w%L \y%s", i, "VOTEBAN_MENU_INITIATOR", szName ) // Инициатор
		menu_addtext( iMenu, szTemp, 1 )
		
		menu_setprop( iMenu, MPROP_EXIT, MEXIT_NEVER )
		
		menu_setprop( iMenu, MPROP_NUMBER_COLOR, "\w" )
		
		if( pev_valid( i ) == PDATA_SAFE )
			set_pdata_int( id, OFFSET_CSMENUCODE, 0, OFFSET_LINUX )
		
		menu_display( i, iMenu, 0 )
	}
}

public handler_voteban_menu( id, iMenu, iItem )
{
	if( iItem == 0 )
		add_vote( id )
	else
	{
		menu_destroy( iMenu )
		client_spk( id, MENU_SOUND_SELECT )
		
		return PLUGIN_HANDLED
	}
	
	client_spk( id, MENU_SOUND_SELECT )
	
	return PLUGIN_HANDLED
}

public add_vote( id )
{
	if( !get_user_status( id ) )
		return PLUGIN_HANDLED
	
	if( !g_bIsVoteStarted )
	{
		yet_another_print_color( id, "%L",  id, "VOTEBAN_ALREADY_FINISHED" ) // Голосование уже закончено.
		return PLUGIN_HANDLED
	}

	g_iTotalVotes[ g_iBanID ] ++
	
	new iTotalVotes, iNeedVotes
	iTotalVotes = g_iTotalVotes[ g_iBanID ]
	iNeedVotes = get_pcvar_num( g_pcvr_Percent ) * get_players_online() / 100
	
	if( iTotalVotes < iNeedVotes )
	{
		new i, szName[ 32 ]
		
		get_user_name( g_iBanID, szName, charsmax( szName ) )
		
		for( i = 1; i <= MAX_PLAYERS; i ++ )
		{
			if( is_user_connected( i ) )
			{
				if( i != g_iBanID )
					client_print( i, print_center, "%L", i, "VOTEBAN_VOTE", szName, iTotalVotes, iNeedVotes ) // За бан %s проголосовало: %d, нужно: %d.
			}
		}
	}
	
	else
	{
		ban_player( g_iBanID )
	}
	
	return PLUGIN_HANDLED
}

public ban_player( iBanID )
{
	if( task_exists( TID_ENDVOTE ) )
		remove_task( TID_ENDVOTE )
	
	if( !get_user_status( iBanID ) )
	{
		clear_voteban_data()
		return PLUGIN_HANDLED
	}
	
	new i, szName[ 32 ], szIP[ 16 ], szAuthID[ 35 ], iUserID, iTime
	
	get_user_name( iBanID, szName, charsmax( szName ) )
	get_user_ip( iBanID, szIP, charsmax( szIP ), 1 )
	get_user_authid( iBanID, szAuthID, charsmax( szAuthID ) )
	iUserID = get_user_userid( iBanID )
	iTime = g_iBanTime
	
	switch( get_pcvar_num( g_pcvr_BanType ) )
	{
		case -2: server_cmd( "banid %d ^"%s^" kick", iTime, szAuthID ) // BAN AUTHID (STEAMID)
		case -1: server_cmd( "addip %d %s", iTime, szIP ) // BAN IP
		case 1: server_cmd( "amx_ban %d ^"%s^" ^"[%s] %s^"", iTime, szAuthID, MSGS_PREFIX, g_szBanReason ) // AMXBANS
		case 2: server_cmd( "fb_ban %d #%d ^"[%s] %s^"", iTime, iUserID, MSGS_PREFIX, g_szBanReason ) // FRESH BANS
		case 3: server_cmd( "amx_ban ^"%s^" %d ^"[%s] %s^"", szAuthID, iTime, MSGS_PREFIX, g_szBanReason ) // ADVANCED BANS
		case 4: server_cmd( "amx_superban #%d %d ^"[%s] %s^"", iUserID, iTime, MSGS_PREFIX, g_szBanReason ) // SUPERBAN
		case 5: server_cmd( "amx_multiban #%d %d ^"[%s] %s^"", iUserID, iTime, MSGS_PREFIX, g_szBanReason ) // MULTIBAN
	}
	
	for( i = 1; i <= MAX_PLAYERS; i ++ )
	{
		if( !get_user_status( i ) || ( i == iBanID ) )
			continue
		
		yet_another_print_color( i, "%L", i, "VOTEBAN_BANNED", szName ) // %s забанен через голосование!
	}
	
	if( get_pcvar_num( g_pcvr_LogToFile ) )
	{
		new y, m, d, szTemp[ 32 ]
		
		date( y, m, d )
		formatex( szTemp, charsmax( szTemp ), "YAV_%d%02d%02d.log", y, m, d )
		log_to_file( szTemp, "Player ^"%s^" banned by initiator ^"%s^" for ^"%s^" (STEAM ID %s) (IP %s)", szName, g_szInitiator[ 0 ], g_szBanReason, g_szInitiator[ 2 ], g_szInitiator[ 1 ] )
	}
	
	clear_voteban_data()
	
	return PLUGIN_HANDLED
}

public task_end_vote()
{
	new i
	
	for( i = 1; i <= MAX_PLAYERS; i ++ )
	{
		if( !is_user_connected( i ) )
			continue
			
		yet_another_print_color( i, "%L",  i, "VOTEBAN_ENDED" ) // Голосование за бан провалено.
	}
	
	clear_voteban_data()
	
	g_bIsVoteStarted = false
}

stock bool:is_voteban_available( id )
{
	if( g_bIsVoteBlocked )
	{
		yet_another_print_color( id, "%L",  id, "VOTEBAN_BLOCKED" ) // В данный момент голосование недоступно.
		return false
	}

	if( g_bIsVoteStarted )
	{
		yet_another_print_color( id, "%L",  id, "VOTEBAN_ALREADY_STARTED" ) // В данный момент уже идёт голосование.
		return false
	}
	
	new szFlags, szCvarsFlags[ 3 ][ 23 ]
	
	szFlags = get_user_flags( id )
	get_pcvar_string( g_pcvr_AdminAccess, szCvarsFlags[ 0 ], charsmax( szCvarsFlags ) )
	get_pcvar_string( g_pcvr_TimeAccess, szCvarsFlags[ 1 ], charsmax( szCvarsFlags ) )
	get_pcvar_string( g_pcvr_Access, szCvarsFlags[ 2 ], charsmax( szCvarsFlags ) )
	
	if( szCvarsFlags[ 2 ][ 0 ] && !( szFlags & read_flags( szCvarsFlags[ 2 ] ) ) )
	{
		yet_another_print_color( id, "%L",  id, "VOTEBAN_NO_ACCESS" ) // К сожалению, у вас нет доступа к голосованию за бан.
		
		return false
	}
	
	if( szFlags & read_flags( szCvarsFlags[ 0 ] ) )
	{
		yet_another_print_color( id, "%L",  id, "VOTEBAN_YOU_ADMIN" ) // Используйте своё бан-меню.
		
		return false
	}
	
	if( g_iUserGametime[ id ] )
	{
		new iInterim, iDelayCvar
		
		iInterim = floatround( get_gametime() ) - g_iUserGametime[ id ]
		iDelayCvar = get_pcvar_num( g_pcvr_Delay )
		
		if( szCvarsFlags[ 1 ][ 0 ] && ( szFlags & read_flags( szCvarsFlags[ 1 ] ) ) )
			return true
		
		else if( iInterim < iDelayCvar * 60 )
		{
			yet_another_print_color( id, "%L",  id, "VOTEBAN_DELAY", ( iDelayCvar - ( iInterim / 60 ) ) + 1 ) // Вы должны подождать еще %d мин. после предыдущего голосования.
			
			return false
		}
	}
	
	if( get_players_online() < get_pcvar_num( g_pcvr_MinPlayers ) )
	{
		yet_another_print_color( id, "%L",  id, "VOTEBAN_NOT_ENOUGH_PLAYERS" ) // Недостаточно игроков, чтобы начать голосование.
		
		return false
	}

	return true
}

stock get_admins_online()
{
	new i, iAdmins, iTeam
	
	iAdmins = 0
	
	for( i = 1; i <= MAX_PLAYERS; i ++ )
	{
		new szFlags[ 23 ]; get_pcvar_string( g_pcvr_AdminAccess, szFlags, charsmax( szFlags ) )
		
		if( !get_user_status( i ) )
			continue
		
		if( !( get_user_flags( i ) & read_flags( szFlags ) ) )
			continue
			
		if( get_pcvar_num( g_pcvr_SpecAdmins ) )		
			iAdmins ++
		else
		{
			iTeam = get_user_team( i )
			
			if( !( ( iTeam == 2 ) || ( iTeam == 1 ) ) )
				continue
				
			iAdmins ++
		}
	}
	
	return iAdmins
}

stock get_players_online()
{
	new i, iPlayers, iTeam
	
	for( i = 1; i <= MAX_PLAYERS; i ++ )
	{
		if( !get_user_status( i ) )
			continue
		
		iTeam = get_user_team( i )
		
		if( !( ( iTeam == 2 ) || ( iTeam == 1 ) ) )
			continue

		iPlayers ++
	}
	
	return iPlayers
}

stock client_spk( id, iSoundID )
	client_cmd( id, "spk %s", g_szMenuSounds[ iSoundID ] )
	
stock get_user_status( id )
{
	if( !is_user_connected( id ) || is_user_hltv( id )/* || is_user_bot( id )*/ )
		return 0
		
	return 1
}
	
stock yet_another_print_color( id, szInput[], any:... )
{
	new szMessage[ 190 ]
   
	vformat( szMessage, charsmax( szMessage ), szInput, 3 )
	format( szMessage, charsmax( szMessage ), "^1[^4%s^1] %s", MSGS_PREFIX, szMessage )
	
	replace_all( szMessage, charsmax( szMessage ), "!g", "^4" ) // Green Color
	replace_all( szMessage, charsmax( szMessage ), "!n", "^1" ) // Default Color
	replace_all( szMessage, charsmax( szMessage ), "!t", "^3" ) // Team Color
  
	
#if AMXX_VERSION_NUM < 183

	new i, iNum = 1, iPlayers[ 32 ]
    
	if( id ) iPlayers[ 0 ] = id; else get_players( iPlayers, iNum, "h" )
	{
		for( i = 0; i < iNum; i ++ )
		{
			if( !is_user_connected( iPlayers[ i ] ) )
				continue 
				
			message_begin( MSG_ONE_UNRELIABLE, get_user_msgid( "SayText" ), _, iPlayers[ i ] )
			write_byte( iPlayers[ i ] )
			write_string( szMessage )
			message_end()
		}
	}
	
#else
	client_print_color( id, print_team_default, szMessage )
#endif

	return 1
}