local font = renderer.setup_font("C:/program files (x86)/steam/steamapps/common/Counter-Strike Global Offensive/nix/fonts/visitor.ttf", 9, 4)
local verdana_warning = renderer.setup_font("C:/windows/fonts/verdana.ttf", 30, 35)
local verdana_distance = renderer.setup_font("C:/windows/fonts/verdana.ttf", 15, 0)

ffi.cdef[[
    typedef struct { 
        float r, g, b, a;
    } color_t;

    typedef struct {
        uintptr_t* entity;
        color_t glow_color;
        char unknown[4];
        float unk;
        float bloom_amount;
        float localplayeriszeropoint3;
        bool render_when_occluded;
        bool render_when_unoccluded;
        bool full_bloom_render;
        char unknown1[1];
        int full_bloom_stencil_test_value;
        int glow_style;
        int split_screen_slot;
        int next_free_slot;
    } glowobject_definition_t;

    typedef struct {
        glowobject_definition_t* glowobject_definitions;
        int max_size;
        int pad;
        int size;
        glowobject_definition_t* unk;
        int first_free_slot;
    } glowobject_manager_t;
]]

local glow_manager = ffi.cast("glowobject_manager_t**", client.find_pattern("client.dll", "0F 11 05 ? ? ? ? 83 C8 01 C7 05 ? ? ? ? 00 00 00 00") + 0x3)[0]
local nullptr = ffi.new("void*")
local m_nExplodeEffectTickBegin = se.get_netvar("DT_BaseCSGrenadeProjectile", "m_nExplodeEffectTickBegin")
local m_vecVelocity = se.get_netvar("DT_BaseGrenade", "m_vecVelocity")
local m_vecOrigin = se.get_netvar("DT_BaseEntity", "m_vecOrigin")
local m_vecViewOffset = se.get_netvar("DT_BasePlayer", "m_vecViewOffset[0]")

math.round = function(first, second)
    local multiplier = 10 ^ (second or 0)
    return math.floor(first * multiplier + 0.5) / multiplier
end
  
local function distance_in_ft(o, distance)
    local vec = vec3_t.new(distance.x - o.x, distance.y - o.y, distance.z - o.z)
    return math.round(math.sqrt(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z) / 12, 3)
end

local function arc(x, y, x2, y2, i, i2, color)
    local i3 = i2

    while i < i2 + i2 do
        i = i + 1

        local math = i * math.pi / 180
        renderer.line(vec2_t.new(x + math.cos(math) * x2, y + math.sin(math) * x2), vec2_t.new(x + math.cos(math) * y2, y + math.sin(math) * y2), color) 
    end
end

local nades_times = {
    smokes = 18,
    fallen_molotovs = 7.03125,
}

local function is_valid_ptr(ptr)
    return ptr == nullptr and nil or ptr
end

local function get_address_of(ptr)
    return ffi.cast("uintptr_t*", ptr)[0]
end

local function render_glow(grenade)
    local glow_grenade_colors = {
        molotovs = color_t.new(255, 255, 255, 255),
        decoys = color_t.new(255, 255, 255, 255),
        flashbang = color_t.new(255, 255, 255, 255),
        hegrenades = color_t.new(255, 255, 255, 255),
        smokes = color_t.new(255, 255, 255, 255),
    }

    for i = 0, glow_manager.size do
        local glow_object = glow_manager.glowobject_definitions[i]

        if not is_valid_ptr(glow_object) or not is_valid_ptr(glow_object.entity) or glow_object.next_free_slot ~= -2 then
            goto continue
        end

        for group, value in pairs(grenade) do
            local current_grenades = value

            for i = 1, #current_grenades do
                local grenades = current_grenades[i]

                if get_address_of(grenades:get_address()) == glow_object.entity[0] then
                    local color = glow_grenade_colors[group]

                    glow_object.glow_color.r = color.r / 255
                    glow_object.glow_color.g = color.g / 255
                    glow_object.glow_color.b = color.b / 255
                    glow_object.glow_color.a = color.a / 255
                    glow_object.render_when_occluded = true
                    glow_object.render_when_unoccluded = false
                    break
                end
            end
        end
        ::continue::
    end
end

local function render_other(grenade)
    grenade_names_colors = {
        molotovs = color_t.new(255, 255, 255, 255),
        fallen_molotovs = color_t.new(255, 255, 255, 255),
        decoys = color_t.new(255, 255, 255, 255),
        flashbang = color_t.new(255, 255, 255, 255),
        hegrenades = color_t.new(255, 255, 255, 255),
        smokes = color_t.new(255, 255, 255, 255),
    }

    grebade_timers_colors = {
        fallen_molotovs = color_t.new(0, 120, 255, 255),
        smokes = color_t.new(0, 120, 255, 255),
    }

    local current_time = globalvars.get_current_time()
    grenade.fallen_molotovs = entitylist.get_entities_by_class("CInferno")
    
    for group, value in pairs(grenade) do
        local current_grenades = value

        for i = 1, #current_grenades do
            local grenades = current_grenades[i]
            local box = grenades:get_bbox()

            if (box.left > 0 or box.top > 0) and (grenades:get_prop_int(m_nExplodeEffectTickBegin) == 0 or group == "fallen_molotovs") then
                local text = group:sub(1, -2)
                text = text == "fallen_molotov" and "molotov" or text
                local text_size = renderer.get_text_size(font, 9, text)
                local x = box.right - text_size.x / 2
                local y = box.bottom + text_size.y / 2
                renderer.text(text, font, vec2_t.new(x, y), 9, grenade_names_colors[group])

                local velocity = grenades:get_prop_vector(m_vecVelocity)
                if (group == "smokes" or group == "fallen_molotovs") and velocity.x == 0 then
                    local x = box.right - text_size.x / 2 - 10
                    local y = box.bottom + (text_size.y or 0) + 10
                    local max_size = (text_size.x + 20) / 100
                    local spawn_time = grenades:get_prop_float(0x20)
                    local math = math.min(math.abs(((spawn_time + nades_times[group] - current_time) / nades_times[group]) * 100), 100)

                    renderer.rect_filled(vec2_t.new(x, y), vec2_t.new(x + (max_size * math), y - 2), grebade_timers_colors[group])
                end
            end
        end
    end
end

local function render_molotov(pos)
    local eye_pos = pos	
    local grenades = entitylist.get_entities_by_class("CMolotovProjectile")
	local correct_shit = 0

	if grenades then
		for i = 1, #grenades do
			local grenade = grenades[i]

			if grenade then
				local entity_origin = grenade:get_prop_vector(m_vecOrigin)
				local pos2d = se.world_to_screen(entity_origin)
				local fraction, hit_entity_index = trace.line(engine.get_local_player(), 33570827, eye_pos, entity_origin)
                local distance = distance_in_ft(eye_pos, entity_origin)

				if distance > 100 then
					correct_shit = 4
				else
					correct_shit = 0
                end

                if distance < 250 then
					renderer.circle(vec2_t.new(pos2d.x, pos2d.y - 50), 30, 30, true, color_t.new(25, 25, 25, 200))

					renderer.text("!", verdana_warning, vec2_t.new(pos2d.x - 5, pos2d.y - 75), 30, color_t.new(200, 200, 100, 255))
					renderer.text(tostring(math.round(distance, 0)) .. " ft", verdana_distance, vec2_t.new(pos2d.x - 15 - correct_shit, pos2d.y - 45), 15, color_t.new(255, 255, 255, 200))
				end
			end
		end
	end
end

local function render_hegrenade(pos)
    local eye_pos = pos	
    local grenades = entitylist.get_entities_by_class("CBaseCSGrenadeProjectile")
	local correct_shit = 0

	if grenades then
		for i = 1, #grenades do
			local grenade = grenades[ i ]
	
			if grenade then
				local entity_origin = grenade:get_prop_vector(m_vecOrigin)
				local pos2d = se.world_to_screen(entity_origin)
				local fraction, hit_entity_index = trace.line(engine.get_local_player(), 33570827, eye_pos, entity_origin)
				local distance = distance_in_ft(eye_pos, entity_origin)

				if distance > 100 then
					correct_shit = 4
				else
					correct_shit = 0
                end

                if distance < 250 then
					renderer.circle(vec2_t.new(pos2d.x, pos2d.y - 50), 30, 30, true, color_t.new(25, 25, 25, 200))

					renderer.text("!", verdana_warning, vec2_t.new(pos2d.x - 5, pos2d.y - 75), 30, color_t.new(200, 200, 100, 255))
					renderer.text(tostring(math.round(distance, 0)) .. " ft", verdana_distance, vec2_t.new(pos2d.x - 15 - correct_shit, pos2d.y - 45), 15, color_t.new(255, 255, 255, 200))
				end
			end
		end
	end
end

local function on_paint()
    if not engine.is_in_game() or not engine.is_connected() then
        return
    end
	
    local grenades = {
        molotovs = entitylist.get_entities_by_class("CMolotovProjectile"),
        decoys = entitylist.get_entities_by_class("CDecoyProjectile"),
        --flashbang = entitylist.get_entities_by_class(""),
        hegrenades = entitylist.get_entities_by_class("CBaseCSGrenadeProjectile"),
        smokes = entitylist.get_entities_by_class("CSmokeGrenadeProjectile")
    }

    local local_player = entitylist.get_local_player()
	local local_origin = local_player:get_prop_vector(m_vecOrigin)
	local local_view = local_player:get_prop_vector(m_vecViewOffset)
    local pos = vec3_t.new(local_origin.x + local_view.x, local_origin.y + local_view.y, local_origin.z + local_view.z)

    if local_player then
        render_glow(grenades)
        render_other(grenades)
        render_molotov(pos)
        render_hegrenade(pos)
    end
end

client.register_callback("paint", on_paint)