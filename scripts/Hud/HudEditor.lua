AutoDriveHud.fileName = "hud.xml"
AutoDriveHud.nextHudPreset = 1

ADHudEditorButton = ADInheritsFrom(ADHudButton)

function ADHudEditorButton:new(posX, posY, width, height, primaryAction, toolTip)
    local o = ADHudEditorButton:create()
    o:init(posX, posY, width, height)
    o.primaryAction = primaryAction
    o.toolTip = toolTip or ""
    o.state = 0
    o.isVisible = true
    o.editMode = nil
    o.layer = 5
    o.images = o:readImages()
    o.ov = g_overlayManager:createOverlay(o.images[o.state], o.position.x, o.position.y, o.size.width, o.size.height)
    return o
end

function ADHudEditorButton:act(vehicle, posX, posY, isDown, isUp, button)
    vehicle.ad.sToolTip = self.toolTip
    vehicle.ad.nToolTipWait = 5
    vehicle.ad.sToolTipInfo = nil
    vehicle.ad.toolTipIsSetting = true

    if self.primaryAction == "input_rotateHudPresets" then
        vehicle.ad.sToolTipInfo = g_i18n:getText("gui_ad_nextHudPreset_tooltip_" .. AutoDrive.Hud.nextHudPreset)
    end

    if isUp and button == 1 then
        local func = AutoDriveHud[self.primaryAction]
        if type(func) ~= "function" then
            Logging.error("[AutoDrive] HudEditorButton '%s' = '%s'", self.primaryAction, type(func))
            return false
        end
        func(AutoDrive.Hud, vehicle)
        return true
    end
    
    if button > 0 and button < 4 and isDown then
        return true, true
    end

    return false
end

function ADHudEditorButton:getNewState(vehicle)
    local newState = self.state

    if self.primaryAction == "toggleEditHud" then
        self.isVisible = (AutoDrive.leftCTRLmodifierKeyPressed and AutoDrive.mouseOverHud) or AutoDrive.Hud.isEditingHud
    end

    return newState
end


function AutoDriveHud:toggleEditHud(vehicle)
	self.isEditingHud = not self.isEditingHud
    local oldHeight = self.numElementsV
    if self.isEditingHud then
        self.isShowingTips = false
        self:splitHudElementLayers()
    else
        self:loadHud()
    end
	self:createHudAt(self.posX, self.posY + (oldHeight - self.numElementsV) * (self.elementHeight + self.gapHeight))
end

function AutoDriveHud:input_decHudWidth(vehicle)
    if self.numElementsH > 7 then
        self.numElementsH = self.numElementsH - 1
        self:createHudAt(self.posX, self.posY)
    end
end

function AutoDriveHud:input_incHudWidth(vehicle)
    if self.numElementsH < 20 then
        self.numElementsH = self.numElementsH + 1
        self:createHudAt(self.posX, self.posY)
    end
end

function AutoDriveHud:input_decHudHeight(vehicle)
    if self.numElementsV > 2 then
        self.numElementsV = self.numElementsV - 1
        self:createHudAt(self.posX, self.posY + (self.elementHeight + self.gapHeight))
    end
end

function AutoDriveHud:input_incHudHeight(vehicle)
    if self.numElementsV < 10 then
        self.numElementsV = self.numElementsV + 1
        self:createHudAt(self.posX, self.posY - (self.elementHeight + self.gapHeight))
    end
end

function AutoDriveHud:input_rotateHudPresets(vehicle)
    local oldHeight = self.numElementsV
    self.nextHudPreset = self:loadCurrentPreset()
    self:splitHudElementLayers()
    self:createHudAt(self.posX, self.posY + (oldHeight - self.numElementsV) * (self.elementHeight + self.gapHeight))
end

function AutoDriveHud:input_saveHud(vehicle)
    self:mergeHudElementLayers()
    self:saveHud()
    self:splitHudElementLayers()
end

function AutoDriveHud:splitHudElementLayers()
    -- for easy-of-use, we split the hud elements into edit and non-edit layers
    local elements, i  = {}, 0

    for _, element in pairs(self.elements) do
        if element.edit == nil then
            -- element on both layers, split
            i = i + 1
            elements[i] = {name=element.name, x=element.x, y=element.y, edit=false }
            i = i + 1
            elements[i] = {name=element.name, x=element.x, y=element.y, edit=true }
        else
            i = i + 1
            elements[i] = element
        end
    end
    self.elements = elements
end

function AutoDriveHud:mergeHudElementLayers()
    -- merge the edit and non-edit layers back into a single layer where possible
    local elements, i = {}, 0

    for y = 0, self.numElementsV-1 do
        for x = 0, self.numElementsH-1 do
            local editElement, nonEditElement = nil, nil
            for _, element in pairs(self.elements) do
                if element.x == x and element.y == y then
                    if element.edit == true then
                        editElement = element
                    elseif element.edit == false then
                        nonEditElement = element
                    else
                        -- this should not happen, but just in case
                        editElement = element
                        nonEditElement = element
                    end
                end
            end

            if editElement ~= nil and nonEditElement ~= nil and editElement.name == nonEditElement.name then
                -- element on both layers, merge them
                i = i + 1
                elements[i] = {name=editElement.name, x=x, y=y}
            else
                if editElement ~= nil then
                    i = i + 1
                    elements[i] = {name=editElement.name, x=x, y=y, edit=true}
                end
                if nonEditElement ~= nil then
                    i = i + 1
                    elements[i] = {name=nonEditElement.name, x=x, y=y, edit=false}
                end
            end
        end
    end
    self.elements = elements
end

function AutoDriveHud:mouseEventOnHudEditorElements(vehicle, posX, posY, isDown, isUp, button)
    -- handle mouse events on the editor elements
    for name, elements in pairs(self.hudEditorElements) do
        for _, element in ipairs(elements) do
            local layer = element.layer
            if element:hit(posX, posY, layer) then
                if button == 1 and isDown then
                    self:startMovingHudElement(posX, posY, name)
                    return true
                end
                local mouseEventHandled, _ = element:mouseEvent(vehicle, posX, posY, isDown, isUp, button, layer)
                if mouseEventHandled then
                    return true
                end
            end
        end
    end
    -- handle right-click on hud to remove elements
    if (button == 2 or button == 3) and isUp then
        local target = self:getDropLocation(posX, posY, 1)
        if target ~= nil then
            self.elements = self:removeOverlappingElements(target.x, target.y, 1)
            self:createHudAt(self.posX, self.posY)
            return true
        end
    end
    return false
end

function AutoDriveHud:startMovingHudElement(posX, posY, element)
	self.isMovingElement = {name=element}
	self.lastMousePosX = posX
	self.lastMousePosY = posY
end

function AutoDriveHud:getDropLocation(posX, posY, width)
    local elementX = (posX - self.posX) / (self.elementWidth + self.gapWidth)
    local elementY = (posY - self.posY) / (self.elementHeight + self.gapHeight)
    if elementX >= 0 and elementY >= 0 and elementX + width - 1 < self.numElementsH and elementY < self.numElementsV then
        return {x=math.floor(elementX), y=self.numElementsV - math.floor(elementY) - 1}
    end
    return nil
end

function AutoDriveHud:moveHudElement(posX, posY)
    local name = self.isMovingElement.name
    local config = self.ELEMENTS[name]
    local x, y = posX - self.elementWidth / 2 - self.gapWidth, posY - self.elementHeight / 2 - self.gapHeight

    local elements = {}
    -- add the element being dragged, avoid rebuilding the entire hud
    self:addElement({name=name, x=0, y=0, absolutePos={x=x, y=y}}, elements)

    local target = self:getDropLocation(posX, posY, config.w)
    if target ~= nil then
        -- highlight the drop location
        local x = self.posX + target.x * (self.elementWidth + self.gapWidth) + self.gapWidth
        local y = self.posY + (self.numElementsV - target.y - 1) * (self.elementHeight + self.gapHeight) + self.gapHeight
        local w = config.w * (self.elementWidth + self.gapWidth) - self.gapWidth
        local h = config.h * (self.elementHeight + self.gapHeight) - self.gapHeight
        table.insert(elements, ADHudIcon:new(x, y, w, h, "ad_gui.dropTarget", 1, "drop_target"))
    end
    self.isMovingElement.target = target
	self.hudEditorElements["_moving_"] = elements
end

function AutoDriveHud:removeOverlappingElements(x, y, w)
    local edit = AutoDrive.isEditorModeEnabled()
    local elements, i  = {}, 0

    -- find elements to remove
    for _, element in pairs(self.elements) do
        local remove = false
        if element.edit == edit and element.y == y then
            local elementConfig = self.ELEMENTS[element.name]
            if element.x + elementConfig.w - 1 >= x and element.x <= x + w - 1 then
                remove = true
            end
        end
        if not remove then
            i = i + 1
            elements[i] = element
        end
    end
    return elements
end

function AutoDriveHud:dropElement(name, target)
    local config = self.ELEMENTS[name]
    local edit = AutoDrive.isEditorModeEnabled()
    local elements = self:removeOverlappingElements(target.x, target.y, config.w)

    -- add the new element
    local i = #elements + 1
    elements[i] = {name=name, x=target.x, y=target.y, edit=edit}
    self.elements = elements
    self:createHudAt(self.posX, self.posY)
end

function AutoDriveHud:stopMovingHudElement(drop)
    if drop and self.isMovingElement ~= nil and self.isMovingElement.target ~= nil then
        self:dropElement(self.isMovingElement.name, self.isMovingElement.target)
    end
    self.hudEditorElements["_moving_"] = nil
    self.isMovingElement = nil
end

function AutoDriveHud:loadHudFromXml(xml)
	self.numElementsH = getXMLInt(xml, "hud.size#width")
	self.numElementsV = getXMLInt(xml, "hud.size#height")
	self.elements = {}

	local i = 0
	while true do
		local key = string.format("hud.elements.element(%d)", i)
		if not hasXMLProperty(xml, key) then
			break
		end
		local name = getXMLString(xml, key .. "#name")
		local x = getXMLInt(xml, key .. "#x")
		local y = getXMLInt(xml, key .. "#y")
		local edit = getXMLBool(xml, key .. "#edit")
		i = i + 1
		self.elements[i] = { name = name, x = x, y = y, edit = edit }
	end

	if AutoDrive.HudX == nil or AutoDrive.HudY == nil then
		local uiScale = g_gameSettings:getValue("uiScale")
		if AutoDrive.getSetting("guiScale") ~= 0 then
			uiScale = AutoDrive.getSetting("guiScale")
		end

		self.width, self.height = getNormalizedScreenValues(
			(self.numElementsH * (self.elementSize + self.elementGap) + self.elementGap) * uiScale,
			(self.numElementsV * (self.elementSize + self.elementGap) + self.elementGap) * uiScale)

		self.posX = 1 - self.width
		self.posY = 0.31
		AutoDrive.HudX = self.posX
		AutoDrive.HudY = self.posY
	else
		self.posX = AutoDrive.HudX
		self.posY = AutoDrive.HudY
	end
end

function AutoDriveHud:loadCurrentPreset()
    local hudPresets = {
        -- these must be aligned with gui_ad_nextHudPreset_tooltip_X
        "gui/hud/default.xml",
        "gui/hud/defaultWithSettings.xml",
        "gui/hud/wide.xml",
        "gui/hud/wideWithSettings.xml",
    }
    local filename = AutoDrive.directory .. hudPresets[self.nextHudPreset]
    local xml = loadXMLFile("Hud_xml", filename)
	self:loadHudFromXml(xml)
	delete(xml)

    local nextHudPreset = self.nextHudPreset + 1
    if nextHudPreset > #hudPresets then
        nextHudPreset = 1
    end
    return nextHudPreset  -- returns the next preset for convenience
end

function AutoDriveHud:loadHud()
   	local filename = getUserProfileAppPath() .. "modSettings/FS25_AutoDrive/" .. self.fileName
    if fileExists(filename) then
        local xml = loadXMLFile("Hud_xml", filename)
        self:loadHudFromXml(xml)
        delete(xml)
    else
        -- load first preset and save it as the default hud
        self:loadCurrentPreset()
        self:saveHud()
    end
end

function AutoDriveHud:writeHudToXml(xml)
	setXMLInt(xml, "hud.size#width", self.numElementsH)
	setXMLInt(xml, "hud.size#height", self.numElementsV)

	for i, element in ipairs(self.elements) do
		local key = string.format("hud.elements.element(%d)", i - 1)
		setXMLString(xml, key .. "#name", element.name)
		setXMLInt(xml, key .. "#x", element.x)
		setXMLInt(xml, key .. "#y", element.y)
		if element.edit ~= nil then
			setXMLBool(xml, key .. "#edit", element.edit)
		end
	end
end

function AutoDriveHud:saveHud()
	local settingsFolder = getUserProfileAppPath() .. "modSettings/"
    createFolder(settingsFolder)
	
	local rootFolder = settingsFolder .. "FS25_AutoDrive/"
    createFolder(rootFolder)

	local xml = createXMLFile("Hud_xml", rootFolder .. self.fileName, "hud")
	self:writeHudToXml(xml)
    saveXMLFile(xml)
    delete(xml)
end
