ADUserDataManager = {}

ADUserDataManager.users = {}
ADUserDataManager.SinglePlayer = "SinglePlayer"

function ADUserDataManager:getUserByConnection(connection)
    return g_currentMission.userManager:getUserByConnection(connection)
end

function ADUserDataManager:getUserIdByConnection(connection)
    local user = self:getUserByConnection(connection)
    if user ~= nil then
        return user.uniqueUserId
    else
        return nil
    end
end

function ADUserDataManager:getUserSettingNames()
    local settings = {}
    for settingName, setting in pairs(AutoDrive.settings) do
        if setting.isUserSpecific then
            table.insert(settings, settingName)
        end
    end
    return settings
end

function ADUserDataManager:load()
    self.userSettingNames = self:getUserSettingNames()
    self.isSinglePlayerOrHost = (not g_currentMission.missionDynamicInfo.isMultiplayer) or (g_currentMission.missionDynamicInfo.isMultiplayer and not g_currentMission.missionDynamicInfo.isClient)
end

function ADUserDataManager:loadFromXml()
    local userCount = 0
    local file = tostring(g_currentMission.missionInfo.savegameDirectory) .. "/AutoDriveUsersData.xml"
    if fileExists(file) then
        local xmlFile = loadXMLFile("AutoDriveUsersData_XML_temp", file)
        if xmlFile ~= nil then
            local uIndex = 0
            while true do
                local uKey = string.format("AutoDriveUsersData.users.user(%d)", uIndex)
                if not hasXMLProperty(xmlFile, uKey) then
                    break
                end
                local uniqueId = getXMLString(xmlFile, uKey .. "#uniqueId")
                if uniqueId ~= nil and uniqueId ~= "" then
                    self.users[uniqueId] = {}
                    self.users[uniqueId].hudX = Utils.getNoNil(getXMLFloat(xmlFile, uKey .. "#hudX"), AutoDrive.HudX or 0.5)
                    self.users[uniqueId].hudY = Utils.getNoNil(getXMLFloat(xmlFile, uKey .. "#hudY"), AutoDrive.HudY or 0.5)
                    self.users[uniqueId].settings = {}
                    self.users[uniqueId].settingsClipboard = nil
                    for _, sn in pairs(self.userSettingNames) do
                        local setting = AutoDrive.settings[sn]
                        if setting and not setting.shallNotBeSaved then
                            self.users[uniqueId].settings[sn] = Utils.getNoNil(getXMLInt(xmlFile, uKey .. "#" .. sn), AutoDrive.getSettingState(sn))
                        end
                    end
                    userCount = userCount + 1
                end
                uIndex = uIndex + 1
            end

            if self.isSinglePlayerOrHost then
                -- no client, use a single player user
                local uniqueId = ADUserDataManager.SinglePlayer
                if self.users[uniqueId] ~= nil then
                    self:applyUserSettings((self.users[uniqueId].hudX or 0.5), (self.users[uniqueId].hudY or 0.5), self.users[uniqueId].settings)
                    self.users[uniqueId].settingsClipboard = nil
                end
            end
            Logging.info("[AD] ADUserDataManager: loaded data for %d users", userCount)
        end
        delete(xmlFile)
    end
end

function ADUserDataManager:userConnected(connection)
    local userId = self:getUserIdByConnection(connection)
    if userId ~= nil and self.users[userId] == nil then
        -- new user - use current settings (default)
        self.users[userId] = {}
        self.users[userId].hudX = AutoDrive.HudX or 0.5
        self.users[userId].hudY = AutoDrive.HudY or 0.5
        self.users[userId].settings = {}
        for _, sn in pairs(self.userSettingNames) do
            self.users[userId].settings[sn] = AutoDrive.getSettingState(sn)
        end
        Logging.info("[AD] ADUserDataManager: user ID %s connected", tostring(userId))
    end
end

function ADUserDataManager:saveToXml()
    local file = g_currentMission.missionInfo.savegameDirectory .. "/AutoDriveUsersData.xml"
    local xmlFile = createXMLFile("AutoDriveUsersData_XML_temp", file, "AutoDriveUsersData")

    if self.isSinglePlayerOrHost then
        -- no client, create a single player user ID
        local uniqueId = ADUserDataManager.SinglePlayer

        -- single player, so use the current data
        self.users[uniqueId] = {}
        self.users[uniqueId].hudX = AutoDrive.HudX or 0.5
        self.users[uniqueId].hudY = AutoDrive.HudY or 0.5
        self.users[uniqueId].settings = {}
        for _, sn in pairs(self.userSettingNames) do
            self.users[uniqueId].settings[sn] = AutoDrive.getSettingState(sn)
        end
    end

    local uIndex = 0
    for uniqueId, userData in pairs(self.users) do
        local uKey = string.format("AutoDriveUsersData.users.user(%d)", uIndex)
        setXMLString(xmlFile, uKey .. "#uniqueId", uniqueId)
        setXMLFloat(xmlFile, uKey .. "#hudX", userData.hudX)
        setXMLFloat(xmlFile, uKey .. "#hudY", userData.hudY)

        for sn, sv in pairs(userData.settings) do
            local setting = AutoDrive.settings[sn]
            if setting and not setting.shallNotBeSaved then
                setXMLInt(xmlFile, uKey .. "#" .. sn, sv)
            end
        end
        uIndex = uIndex + 1
    end
    Logging.info("[AD] ADUserDataManager: saved data for %d users", uIndex)
    saveXMLFile(xmlFile)
    delete(xmlFile)
end

function ADUserDataManager:sendToServer()
    local settings = {}
    for _, sn in pairs(self.userSettingNames) do
        settings[sn] = AutoDrive.getSettingState(sn)
    end
    AutoDriveUserDataEvent.sendToServer(AutoDrive.HudX, AutoDrive.HudY, settings)
end

function ADUserDataManager:updateUserSettings(connection, hudX, hudY, settings)
    local userId = self:getUserIdByConnection(connection)
    if userId ~= nil then
        self.users[userId] = {}
        self.users[userId].hudX = hudX
        self.users[userId].hudY = hudY
        self.users[userId].settings = settings
        Logging.info("[AD] ADUserDataManager: update user settings ID %s", tostring(userId))
    end
end

function ADUserDataManager:sendToClient(connection)
    local userId = self:getUserIdByConnection(connection)
    if userId ~= nil then
        Logging.info("[AD] ADUserDataManager: send user settings ID %s to client", tostring(userId))
        AutoDriveUserDataEvent.sendToClient(connection, self.users[userId].hudX, self.users[userId].hudY, self.users[userId].settings)
    end
end

function ADUserDataManager:applyUserSettings(hudX, hudY, settings)
    Logging.info("[AD] ADUserDataManager: apply user settings")
    for sn, sv in pairs(settings) do
        AutoDrive.setSettingState(sn, sv)
    end
    AutoDrive.Hud:createHudAt(hudX, hudY)
end

function ADUserDataManager:getSettingsClipboard(vehicle, userId)
    local uniqueId = userId
    if self.isSinglePlayerOrHost then
        -- no client, use a single player user
        uniqueId = ADUserDataManager.SinglePlayer
    end
    if not uniqueId or self.users[uniqueId] == nil or not vehicle or not vehicle.ad or not vehicle.ad.stateModule then
        return
    end

    self.users[uniqueId].settingsClipboard = {
        stateValues = {
            mode = vehicle.ad.stateModule:getMode(),
            firstMarkerId = vehicle.ad.stateModule:getFirstMarkerId(),
            secondMarkerId = vehicle.ad.stateModule:getSecondMarkerId(),
            fillType = vehicle.ad.stateModule:getFillType(),
            selectedFillTypes = {unpack(vehicle.ad.stateModule:getSelectedFillTypes() or {})},
            loadByFillLevel = vehicle.ad.stateModule:getLoadByFillLevel(),
            loopCounter = vehicle.ad.stateModule:getLoopCounter(),
            startHelper = vehicle.ad.stateModule:getStartHelper(),
            usedHelper = vehicle.ad.stateModule:getUsedHelper(),
        }
    }
    self.users[uniqueId].settingsClipboard.settings = {}
    for settingName, setting in pairs(vehicle.ad.settings) do
        if setting.isCopyPaste then
            self.users[uniqueId].settingsClipboard.settings[settingName] = setting.current
        end
    end
    AutoDriveMessageEvent.sendMessageOrNotification(vehicle, ADMessagesManager.messageTypes.INFO, "$l10n_AD_settings_copied;", 2000)
end

function ADUserDataManager:applySettingsClipboard(vehicle, userId)
    local uniqueId = userId
    if self.isSinglePlayerOrHost then
        -- no client, use a single player user
        uniqueId = ADUserDataManager.SinglePlayer
    end
    if not uniqueId or self.users[uniqueId] == nil or not vehicle or not vehicle.ad or not vehicle.ad.stateModule then
        return
    end
    if self.users[uniqueId].settingsClipboard == nil then
        AutoDriveMessageEvent.sendMessageOrNotification(vehicle, ADMessagesManager.messageTypes.ERROR, "$l10n_AD_settings_clipboard_empty;", 2000)
        return
    end
    if self.users[uniqueId].settingsClipboard.stateValues then
        local stateValues = self.users[uniqueId].settingsClipboard.stateValues
        vehicle.ad.stateModule:setMode(stateValues.mode)
        vehicle.ad.stateModule:setFirstMarker(stateValues.firstMarkerId)
        vehicle.ad.stateModule:setSecondMarker(stateValues.secondMarkerId)
        vehicle.ad.stateModule:setFillType(stateValues.fillType)
        vehicle.ad.stateModule:setSelectedFillTypes(stateValues.selectedFillTypes)
        vehicle.ad.stateModule:setLoadByFillLevel(stateValues.loadByFillLevel)
        vehicle.ad.stateModule:setLoopCounter(stateValues.loopCounter)
        vehicle.ad.stateModule:setStartHelper(stateValues.startHelper)
        vehicle.ad.stateModule:setUsedHelper(stateValues.usedHelper)
    end
    if self.users[uniqueId].settingsClipboard.settings then
        for settingName, current in pairs(self.users[uniqueId].settingsClipboard.settings) do
            AutoDrive.setSettingState(settingName, current, vehicle)
        end
        AutoDriveUpdateSettingsEvent.sendEvent(vehicle)
    end
    AutoDriveMessageEvent.sendMessageOrNotification(vehicle, ADMessagesManager.messageTypes.INFO, "$l10n_AD_settings_pasted;", 2000)
end
