
inverter = ui.add_key_bind( "inverter", "inverter", 0, 2 )
fakelags = ui.get_check_box( "antihit_fakelag_enable" )

client.register_callback( "create_move", function( cmd )

	if return_conditions( cmd ) then
		return
	end

	fakelags:set_value( false )
	cmd.send_packet = clientstate.get_choked_commands() >= 1

	break_lby( cmd )

	if cmd.send_packet == false then
		cmd.viewangles.yaw = cmd.viewangles.yaw + ( inverter:is_active() and -120 or 120 )
	end

end )

lower_body_yaw_update_time = 0.0
lower_body_yaw_force_choke = false

function break_lby( cmd )

	if math.abs(entitylist.get_local_player():get_prop_vector(se.get_netvar("DT_BasePlayer", "m_vecVelocity[0]")):length()) > 4.0 then
		return
	end

	if globalvars.get_current_time() >= lower_body_yaw_update_time then

		cmd.send_packet = false
		cmd.viewangles.yaw = cmd.viewangles.yaw + 179

		lower_body_yaw_force_choke = true
		lower_body_yaw_update_time = globalvars.get_current_time() + 0.22

		micro_move( cmd )
		return

	end

	if lower_body_yaw_force_choke then
		lower_body_yaw_force_choke = false
		cmd.send_packet = false
		return
	end

	if lower_body_yaw_force_choke then
		return
	end

end

micro_move_speed = 0.0

fakeduck_bind = ui.get_key_bind( "antihit_extra_fakeduck_bind" )

function micro_move( cmd )

    if math.abs(cmd.sidemove) > 4.0 then
    	return
    end

    micro_move_speed = fakeduck_bind:is_active() and 3.3 or (client.is_key_pressed(0x11) and 3.3 or 1.1)
    if cmd.command_number % 2 == 1 then micro_move_speed = -micro_move_speed end

    cmd.sidemove = micro_move_speed

end

is_warmap_started = false

se.register_event("round_start")
se.register_event("round_prestart")
se.register_event("round_freeze_end")

client.register_callback("fire_game_event", function(event)

	if event:get_name() == "round_prestart" then
		is_warmap_started = true
	end

	if event:get_name() == "round_freeze_end" then
        is_warmap_started = false
    end

    if event:get_name() == "round_start" then
    	lower_body_yaw_update_time = 0.22
    end

end)


function is_throwing(  )
    local active_weapon_throw_time = entitylist.get_entity_from_handle(entitylist.get_local_player():get_prop_int(se.get_netvar("DT_BaseCombatCharacter", "m_hActiveWeapon"))):get_prop_float(se.get_netvar("DT_BaseCSGrenade", "m_fThrowTime"))

    if active_weapon_throw_time > 0.1 then 
        return true
    end 
    
    return false
end

function return_conditions( cmd )

	if is_warmap_started then 
		return true
	end

    local active_weapon = entitylist.get_entity_from_handle(entitylist.get_local_player():get_prop_int(se.get_netvar("DT_BaseCombatCharacter", "m_hActiveWeapon")))

    if is_nade( ) and is_throwing( ) and not is_knife( ) then
    	return true
    end

    if (hasbit(cmd.buttons, 1) or (hasbit(cmd.buttons, 2048) and is_knife())) and can_shoot(active_weapon) then
    	return true
    end

    if hasbit(cmd.buttons, 32) then
        return true
    end

    local move_type = entitylist.get_local_player():get_prop_int(se.get_netvar("DT_BaseEntity", "m_nRenderMode") + 1) 

    if move_type == 0 or move_type == 8 or move_type == 9 then
        return true
    end

    return false
end

function server_time()
	return (entitylist.get_local_player():get_prop_int(se.get_netvar("DT_BasePlayer", "m_nTickBase")) * globalvars.get_interval_per_tick())
end

function can_shoot( weapon )
	return weapon:get_prop_float(se.get_netvar("DT_BaseCombatWeapon", "m_flNextPrimaryAttack")) <= server_time() and ((get_weapon_ammo( entitylist.get_local_player() ) > 0 and not get_weapon_recharge( )) or is_knife())
end

function hasbit(x, p) return x % (p + p) >= p end

ffi.cdef[[

	struct WeaponInfo_t
	{
		char _0x0000[20];
		__int32 max_clip;	
		char _0x0018[12];
		__int32 max_reserved_ammo;
		char _0x0028[96];
		char* hud_name;			
		char* weapon_name;		
		char _0x0090[60];
		__int32 type;			
		__int32 price;			
		__int32 reward;			
		char _0x00D8[20];
		bool full_auto;		
		char _0x00ED[3];
		__int32 damage;			
		float armor_ratio;		 
		__int32 bullets;	
		float penetration;	
		char _0x0100[8];
		float range;			
		float range_modifier;	
		char _0x0110[16];
		bool silencer;			
		char _0x0121[15];
		float max_speed;		
		float max_speed_alt;
		char _0x0138[76];
		__int32 recoil_seed;
		char _0x0188[32];
	};
]]

weapon_data_call = ffi.cast("int*(__thiscall*)(void*)", client.find_pattern("client.dll", "55 8B EC 81 EC ? ? ? ? 53 8B D9 56 57 8D 8B ? ? ? ? 85 C9 75 04"));

function weapon_data( weapon )
	return ffi.cast("struct WeaponInfo_t*", weapon_data_call(ffi.cast("void*", weapon:get_address())));
end

function get_weapon_ammo( player )
	return entitylist.get_entity_from_handle(entitylist.get_local_player():get_prop_int(se.get_netvar("DT_BaseCombatCharacter", "m_hActiveWeapon"))):get_prop_int(se.get_netvar("DT_BaseCombatWeapon", "m_iClip1"))
end

function get_weapon_recharge(  )

	if not entitylist.get_entity_from_handle(entitylist.get_local_player():get_prop_int(se.get_netvar("DT_BaseCombatCharacter", "m_hActiveWeapon"))) then
		return false
	end

	in_recharge = ffi.cast("uint32_t*", (client.find_pattern("client.dll", "C6 87 ? ? ? ? ? 8B 06 8B CE FF 90") + 2))
	is_recharging = ffi.cast("bool*", entitylist.get_entity_from_handle(entitylist.get_local_player():get_prop_int(se.get_netvar("DT_BaseCombatCharacter", "m_hActiveWeapon"))):get_address() + in_recharge[0])

	return is_recharging[0]
end

function is_nade(  )

    local weapon = entitylist.get_entity_from_handle(entitylist.get_local_player():get_prop_int(se.get_netvar("DT_BaseCombatCharacter", "m_hActiveWeapon")))

	if weapon_data(weapon).type == 0 then
		return true
	end

	return false

end

function is_knife(  )
	
	local weapon = entitylist.get_entity_from_handle(entitylist.get_local_player():get_prop_int(se.get_netvar("DT_BaseCombatCharacter", "m_hActiveWeapon")))

	if weapon_data(weapon).type == 1 then
		return true
	end

	return false

end