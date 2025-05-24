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
    if self.isEditingHud then
        self:splitHudElementLayers()
    else
        self:mergeHudElementLayers()
    end
	self:createHudAt(self.posX, self.posY)
end

function AutoDriveHud:decHudWidth(vehicle)
    if self.numElementsH > 7 then
        self.numElementsH = self.numElementsH - 1
        self:createHudAt(self.posX, self.posY)
    end
end

function AutoDriveHud:incHudWidth(vehicle)
    if self.numElementsH < 20 then
        self.numElementsH = self.numElementsH + 1
        self:createHudAt(self.posX, self.posY)
    end
end

function AutoDriveHud:decHudHeight(vehicle)
    if self.numElementsV > 2 then
        self.numElementsV = self.numElementsV - 1
        self:createHudAt(self.posX, self.posY + (self.elementHeight + self.gapHeight))
    end
end

function AutoDriveHud:incHudHeight(vehicle)
    if self.numElementsV < 10 then
        self.numElementsV = self.numElementsV + 1
        self:createHudAt(self.posX, self.posY - (self.elementHeight + self.gapHeight))
    end
end

function AutoDriveHud:splitHudElementLayers()
    -- for easy-of-use, we split the hud elements into edit and non-edit layers
    local elements, i  = {}, 0

    for _, element in pairs(self.elements) do
        if element.edit == nil then
            -- element on both layers, split
            print("Splitting element: " .. element.name)
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
end

function AutoDriveHud:mouseEventOnHudEditorElements(vehicle, posX, posY, isDown, isUp, button)
    for name, elements in pairs(self.hudEditorElements) do
        for _, element in ipairs(elements) do
            local layer = element.layer
            if element:hit(posX, posY, layer) then
                if button == 1 and isDown and AutoDrive.Hud.isEditingHud then
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

function AutoDriveHud:dropElement(name, target)
    local config = self.ELEMENTS[name]
    local edit = AutoDrive.isEditorModeEnabled()
    local elements, i  = {}, 0

    -- find elements to remove
    for _, element in pairs(self.elements) do
        local remove = false
        if element.edit == edit and element.y == target.y then
            local elementConfig = self.ELEMENTS[element.name]
            if element.x + elementConfig.w - 1 >= target.x and element.x <= target.x + config.w - 1 then
                -- remove the element
                remove = true
            end
        end
        if not remove then
            i = i + 1
            elements[i] = element
        end
    end
    -- add the new element
    i = i + 1
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
