ADHudSettingsButton = ADInheritsFrom(ADGenericHudElement)

function ADHudSettingsButton:new(posX, posY, width, height, setting, toolTip, state, editMode)
    local o = ADHudSettingsButton:create()
    o:init(posX, posY, width, height)
    o.setting = setting
    o.toolTip = toolTip
    o.state = state
    o.editMode = editMode
    o.isVisible = false

    o.layer = 5

    o.images = o:readImages()

    o.ov = g_overlayManager:createOverlay(o.images[o.state], o.position.x, o.position.y, o.size.width, o.size.height)

    return o
end

function ADHudSettingsButton:readImages()
    local images = {}
    local counter = 1

    local adTextureConfig = g_overlayManager.textureConfigs["ad_gui"]
    while true do
        local sliceId = self.setting .. "_" .. counter
        if adTextureConfig.slices[sliceId] == nil then
            break
        end
        images[counter] = "ad_gui." .. sliceId
        counter = counter + 1
    end
    return images
end

function ADHudSettingsButton:onDraw(vehicle, uiScale)
    self:updateState(vehicle)
    if self.isVisible then
        self.ov:render()
    end
end

function ADHudSettingsButton:updateState(vehicle)
    local newState = AutoDrive.getSettingState(self.setting, vehicle)
    self.isVisible = self.editMode == nil or self.editMode == AutoDrive.isEditorModeEnabled()
    self.ov:setSliceId(self.images[newState])
    self.state = newState
end

function ADHudSettingsButton:act(vehicle, posX, posY, isDown, isUp, button)
    if self.isVisible then
        vehicle.ad.sToolTip = self.toolTip
        vehicle.ad.nToolTipWait = 5
        vehicle.ad.sToolTipInfo = nil
        vehicle.ad.toolTipIsSetting = true

        if button == 1 and isUp then
            local currentState = AutoDrive.getSettingState(self.setting, vehicle)
            currentState = (currentState + 1)
            if currentState > table.count(AutoDrive.settings[self.setting].values) then
                currentState = 1
            end
            AutoDrive.setSettingState(self.setting, currentState, vehicle)
            AutoDriveUpdateSettingsEvent.sendEvent(vehicle)
        end
    end

    return false
end
