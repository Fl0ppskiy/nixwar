local m_bSpotted = se.get_netvar("DT_BaseEntity", "m_bSpotted")

local function on_create_move(cmd)
    local local_player = entitylist.get_players(0)

    for i = 1, #local_player do
        local player = local_player[i]

        if not player:is_dormant() and player:is_alive() then
            player:set_prop_bool(m_bSpotted, true)
        end
    end
end

client.register_callback("create_move", on_create_move)