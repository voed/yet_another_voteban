# Yet Another Voteban AMXX Plugin
Удобный и симпатичный голосовальщик за бан игроков для Ваших великолепных серверов Counter-Strike 1.6.

Авторы: [AndrewZo](https://github.com/AndrewZo), [voed](https://github.com/voed), [wopox1337](https://github.com/wopox1337).
 
Переменные плагина:

	yav_time_default "5" 		— стандартное время бана в минутах, доступное для простых смертных (1 значение).
	
	yav_time "5 15 30 60 180" 	— дополнительное время бана для игроков с флагом доступа "yav_time_access" (от 1 до 5 значений, через пробел).
	
	yav_ban_type "1" 		— тип бана: -2 = BANID (STEAMID); -1 = ADDIP; 1 = AMXBANS; 2 = FRESHBANS; 3 = ADVANCED BANS; 4 = SUPERBAN; 5 = MULTIBAN.
	
	yav_delay "5" 			— задержка между голосованиями, в минутах.
	
	yav_duration "15"		— длительность голосования.
	
	yav_percent "60"		— необходимый процент проголосовавших игроков для осуществления бана (1-100).
	
	yav_min_players "3"		— минимум игроков на сервере для возможности открыть меню голосования.
	
	yav_spec_admins "0"		— учитывать ли админов в команде наблюдателей как активных админов. (1 - учитывать, 0 - пропускать)
	
	yav_roundstart_delay "-1"	— блокировка вызова голосования в начале раунда, в секундах. (Целое или дробное положительное значение - блокировка на указанное время, "-1" - блокировка до конца mp_buytime, "0" - отключить, не блокировать)
	
	yav_access ""			— флаг доступа к меню голосования. (Можно указать несколько: "abc", либо оставить пустым "", чтобы разрешить использовать всем).
	
	yav_time_access "c"		— флаг доступа к выбору времени бана и к голосованию без кулдауна. (Можно указать несколько: "abc", либо оставить пустым "", чтобы отключить).
	
	yav_admin_access "d"		— флаг админа для блока голосования и включения оповещения админов. (Можно указать несколько: "abc", либо оставить пустым "", чтобы отключить).
	
	yav_immunity_access "a"		— флаг иммунитета к вотебану. (Можно указать несколько: "abc", либо оставить пустым "", чтобы отключить).
	
	yav_log_to_file "1"		— логирование банов в файл "addons\amxmodx\logs". Название логов "YAV_ГГГГДДММ.log".
