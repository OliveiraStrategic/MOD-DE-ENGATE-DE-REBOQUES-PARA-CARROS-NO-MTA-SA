--[[
MOD DE ENGATE DE REBOQUES PARA CARROS NO MTA:SA

Descrição: Permite engatar/desengatar reboques pequenos em carros e SUVs cadastrados via XML.
- Suporte multiplayer: trailer fica preso ao veículo, não ao jogador.
- Desengate automático ao forçar curva fechada.
- Fácil personalização via allowed_vehicles.xml e offsets.

Autor: Gabriel Oliveira
Créditos: Gabriel Oliveira
]]

local attachedTrailers = {}
local allowedVehicles = {}

function loadAllowedVehicles()
    local xml = xmlLoadFile('allowed_vehicles.xml')
    if not xml then return end
    for i, node in ipairs(xmlNodeGetChildren(xml)) do
        local model = tonumber(xmlNodeGetAttribute(node, 'model'))
        if model then
            allowedVehicles[model] = true
        end
    end
    xmlUnloadFile(xml)
end

addEventHandler('onResourceStart', resourceRoot, loadAllowedVehicles)

function isVehicleAllowed(vehicle)
    return allowedVehicles[getElementModel(vehicle)]
end

function isAllowedTrailer(trailer)
    local allowedTrailerModels = {
        [606] = true, -- Baggage Trailer (covered)
        [607] = true, -- Baggage Trailer (Uncovered)
        [610] = true, -- Farm Trailer
        [611] = true, -- Street Clean Trailer
        -- Não permite 435, 450, 591, 584, 608
    }
    return allowedTrailerModels[getElementModel(trailer)]
end

-- Tabela de offsets para cada modelo de veículo permitido
local vehicleTrailerOffsets = {
    [400] = {x = 0, y = -3.2, z = 0.2}, -- Landstalker
    [401] = {x = 0, y = -3.0, z = 0.2}, -- Bravura
    -- Adicione mais modelos conforme necessário
}

-- Função para manter o reboque no chão e "puxado" por uma linha invisível
function attachTrailerWithLine(trailer, veh)
    local model = getElementModel(veh)
    local offset = vehicleTrailerOffsets[model] or {x = 0, y = -3.2, z = 0.2}
    -- Engata fisicamente pelo MTA:SA
    attachTrailerToVehicle(veh, trailer)
    -- Ajusta posição do trailer para trás do veículo e no chão
    setTimer(function()
        if isElement(trailer) and isElement(veh) then
            local vx, vy, vz = getElementPosition(veh)
            local _, _, rz = getElementRotation(veh)
            local rad = math.rad(rz)
            local tx = vx + offset.x * math.cos(rad) - offset.y * math.sin(rad)
            local ty = vy + offset.x * math.sin(rad) + offset.y * math.cos(rad)
            local tz = vz + offset.z
            setElementPosition(trailer, tx, ty, getGroundPosition(tx, ty, tz) + 0.1)
            setElementRotation(trailer, 0, 0, rz)
        end
    end, 200, 1)
end

-- Função para calcular diferença angular absoluta
local function getAngleDiff(a, b)
    local diff = math.abs(a - b) % 360
    if diff > 180 then diff = 360 - diff end
    return diff
end

-- Timer para monitorar o ângulo e desprender se necessário
function monitorTrailerAngle(veh, trailer)
    if isTimer(veh.trailerAngleTimer) then killTimer(veh.trailerAngleTimer) end
    veh.trailerAngleTimer = setTimer(function()
        if not isElement(veh) or not isElement(trailer) or getVehicleTowedByVehicle(veh) ~= trailer then
            if isTimer(veh.trailerAngleTimer) then killTimer(veh.trailerAngleTimer) end
            veh.trailerAngleTimer = nil
            return
        end
        local _, _, rzVeh = getElementRotation(veh)
        local _, _, rzTrailer = getElementRotation(trailer)
        local angle = getAngleDiff(rzVeh, rzTrailer)
        if angle > 60 then -- Limite de curva (ajuste conforme necessário)
            detachTrailerFull(veh, nil, 'O reboque se desprendeu por forçar demais a curva!')
        end
    end, 100, 0)
end

function detachTrailerFull(veh, player, motivo)
    if not isElement(veh) or not attachedTrailers[veh] then return end
    local trailer = attachedTrailers[veh]
    -- Reposiciona suavemente atrás do veículo antes de desengatar
    if isElement(trailer) then
        local vx, vy, vz = getElementPosition(veh)
        local _, _, rz = getElementRotation(veh)
        local rad = math.rad(rz)
        local tx = vx - 2 * math.sin(rad)
        local ty = vy + 2 * math.cos(rad)
        local tz = getGroundPosition(tx, ty, vz) + 0.2
        setElementPosition(trailer, tx, ty, tz)
        setElementVelocity(trailer, 0, 0, 0)
    end
    detachTrailerFromVehicle(veh)
    attachedTrailers[veh] = nil
    if isTimer(veh.trailerAngleTimer) then killTimer(veh.trailerAngleTimer) end
    veh.trailerAngleTimer = nil
    if player then
        outputChatBox(motivo or 'Reboque desengatado!', player, 255,100,0)
    end
end

-- Função para encontrar trailer já engatado em um veículo
function findVehicleByTrailer(trailer)
    for veh, t in pairs(attachedTrailers) do
        if t == trailer then return veh end
    end
    return nil
end

-- Modificar attachTrailer para iniciar o monitoramento
function attachTrailer(player)
    local veh = getPedOccupiedVehicle(player)
    if not veh or not isVehicleAllowed(veh) then return end
    local x, y, z = getElementPosition(veh)
    local trailers = getElementsWithinRange(x, y, z, 10, 'vehicle')
    for _, trailer in ipairs(trailers) do
        if getVehicleType(trailer) == 'Trailer' and not getVehicleTowedByVehicle(trailer) and isAllowedTrailer(trailer) then
            -- Se o trailer já está engatado em outro veículo, desengate do anterior
            local oldVeh = findVehicleByTrailer(trailer)
            if oldVeh and oldVeh ~= veh then
                detachTrailerFull(oldVeh)
            end
            attachTrailerWithLine(trailer, veh)
            attachedTrailers[veh] = trailer
            monitorTrailerAngle(veh, trailer)
            outputChatBox('Reboque engatado!', player, 0,255,0)
            return
        end
    end
    outputChatBox('Nenhum reboque permitido próximo.', player, 255,0,0)
end
addCommandHandler('engatar', attachTrailer)

function detachTrailer(player)
    local veh = getPedOccupiedVehicle(player)
    detachTrailerFull(veh, player)
end
addCommandHandler('desengatar', detachTrailer)