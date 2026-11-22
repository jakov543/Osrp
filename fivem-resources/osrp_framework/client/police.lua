-- OSRP framework v1.0.26 - police uniform from the locker room in PU Osijek (osrp_osijek fires 'osrp:policeLocker')
local saved = nil

local function apply(ped, outfit)
    for comp, v in pairs(outfit) do
        if comp == 'hat' then
            if v[1] < 0 then ClearPedProp(ped, 0) else SetPedPropIndex(ped, 0, v[1], v[2] or 0, true) end
        else
            SetPedComponentVariation(ped, comp, v[1], v[2] or 0, 0)
        end
    end
end

AddEventHandler('osrp:policeLocker', function()
    if Config.PoliceUniformJobOnly and OSRP.Job ~= 'police' then
        return OSRP.Notify('~r~Svlačionica je samo za policiju.~s~')
    end
    local ped = PlayerPedId()
    local male = GetEntityModel(ped) == joaat('mp_m_freemode_01')
    if saved then
        for comp, v in pairs(saved.comps) do SetPedComponentVariation(ped, comp, v[1], v[2], 0) end
        if saved.hat[1] >= 0 then SetPedPropIndex(ped, 0, saved.hat[1], saved.hat[2], true) else ClearPedProp(ped, 0) end
        saved = nil
        return OSRP.Notify('Presvukao si se u ~b~civilnu odjeću~s~.')
    end
    saved = { comps = {}, hat = { GetPedPropIndex(ped, 0), GetPedPropTextureIndex(ped, 0) } }
    for _, comp in ipairs({ 3, 4, 6, 7, 8, 9, 10, 11 }) do
        saved.comps[comp] = { GetPedDrawableVariation(ped, comp), GetPedTextureVariation(ped, comp) }
    end
    DoScreenFadeOut(300) Wait(350)
    apply(ped, (Config.PoliceUniform or {})[male and 'm' or 'f'] or {})
    Wait(250) DoScreenFadeIn(300)
    OSRP.Notify('Obukao si ~b~policijsku uniformu~s~. Pritisni ~y~E~s~ ponovno za civilnu odjeću.')
end)
