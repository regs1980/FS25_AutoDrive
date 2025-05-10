ADHudEditorButton = ADInheritsFrom(ADHudButton)

function ADHudEditorButton:new(posX, posY, width, height, primaryAction, toolTip)
    local o = ADHudEditorButton:create()
    o:init(posX, posY, width, height)
    o.primaryAction = primaryAction
    o.toolTip = toolTip or ""
    o.state = 0
    o.isVisible = true
    o.layer = 5
    o.images = o:readImages()
    o.ov = g_overlayManager:createOverlay(o.images[o.state], o.position.x, o.position.y, o.size.width, o.size.height)
    return o
end


function ADHudEditorButton:act(vehicle, posX, posY, isDown, isUp, button)
    if self.isVisible then
        vehicle.ad.sToolTip = self.toolTip
        vehicle.ad.nToolTipWait = 5
        vehicle.ad.sToolTipInfo = nil
        vehicle.ad.toolTipIsSetting = false

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
    end

    return false
end

function ADHudEditorButton:getNewState(vehicle)
    local newState = self.state
  
    if self.primaryAction == "toggleEditHud" then
        self.isVisible = AutoDrive.leftCTRLmodifierKeyPressed and AutoDrive.mouseOverHud
    end
    
    return newState
end


function AutoDriveHud:toggleEditHud(vehicle)
	self.isEditingHud = not self.isEditingHud
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
