FieldPointGenerator = {}
FieldPointGenerator.MOD_NAME = g_currentModName
FieldPointGenerator.SAVE_FILE = "FieldPointGenerator.xml"
FieldPointGenerator.STATE_FILE_PREFIX = "FieldPointGenerator_state_savegame"
FieldPointGenerator.BUILD = "RC1-MODSETTINGS-STATE"

-- FieldPointGenerator.INSET_METERS = 2.0
-- FieldPointGenerator.RESAMPLE_SPACING = 8.0
FieldPointGenerator.SMOOTH_ITERATIONS = 1
FieldPointGenerator.MAX_MITER_FACTOR = 4.0

FieldPointGenerator.TEXT_PROMPT = "Do you want field outlines generated?"
FieldPointGenerator.TEXT_WARNING = "Generating field outlines. The game might freeze for a few seconds. Please do not save. Exit and reload the save game after generation."
FieldPointGenerator.TEXT_SUCCESS = "Field outlines generated successfully. Please do not save. Exit and reload this save game now."

function FieldPointGenerator:containsValue(tbl, value)
    if tbl == nil then
        return false
    end

    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end

    return false
end

function FieldPointGenerator:addUnique(tbl, value)
    if tbl == nil then
        return
    end

    if not self:containsValue(tbl, value) then
        table.insert(tbl, value)
    end
end

function FieldPointGenerator:getFieldId(field)
    if field == nil then
        return nil
    end

    if field.getId ~= nil then
        return field:getId()
    end

    if field.fieldId ~= nil then
        return field.fieldId
    end

    if field.id ~= nil then
        return field.id
    end

    return nil
end

function FieldPointGenerator:getPolygonNodes(field)
    if field == nil then
        return nil
    end

    if field.getPolygonPoints ~= nil then
        return field:getPolygonPoints()
    end

    if field.polygonPoints ~= nil then
        return field.polygonPoints
    end

    return nil
end

function FieldPointGenerator:isSamePoint2D(a, b, epsilon)
    epsilon = epsilon or 0.01

    if a == nil or b == nil then
        return false
    end

    return math.abs(a.x - b.x) <= epsilon and math.abs(a.z - b.z) <= epsilon
end

function FieldPointGenerator:cleanupPoints(points)
    local cleaned = {}

    if points == nil then
        return cleaned
    end

    for i = 1, #points do
        local p = points[i]
        local prev = cleaned[#cleaned]

        if prev == nil or not self:isSamePoint2D(prev, p) then
            table.insert(cleaned, p)
        end
    end

    if #cleaned >= 2 and self:isSamePoint2D(cleaned[1], cleaned[#cleaned]) then
        table.remove(cleaned, #cleaned)
    end

    return cleaned
end

function FieldPointGenerator:getFieldWorldPoints(field)
    local points = {}
    local polygonNodes = self:getPolygonNodes(field)

    if polygonNodes == nil then
        return points
    end

    for _, pointNode in ipairs(polygonNodes) do
        if pointNode ~= nil then
            local x, y, z = getWorldTranslation(pointNode)
            table.insert(points, {
                x = x,
                y = y,
                z = z
            })
        end
    end

    return self:cleanupPoints(points)
end

function FieldPointGenerator:getDistance2D(a, b)
    local dx = b.x - a.x
    local dz = b.z - a.z
    return math.sqrt(dx * dx + dz * dz)
end

function FieldPointGenerator:normalize2D(x, z)
    local len = math.sqrt(x * x + z * z)
    if len < 0.0001 then
        return 0, 0
    end
    return x / len, z / len
end

function FieldPointGenerator:getSignedArea(points)
    local area = 0

    if points == nil or #points < 3 then
        return 0
    end

    for i = 1, #points do
        local a = points[i]
        local b = points[i + 1]
        if b == nil then
            b = points[1]
        end

        area = area + (a.x * b.z - b.x * a.z)
    end

    return area * 0.5
end

function FieldPointGenerator:getInwardNormalForEdge(a, b, isCCW)
    local dx = b.x - a.x
    local dz = b.z - a.z

    if isCCW then
        return self:normalize2D(-dz, dx)
    else
        return self:normalize2D(dz, -dx)
    end
end

function FieldPointGenerator:getOffsetEdgeLine(a, b, insetDistance, isCCW)
    local nx, nz = self:getInwardNormalForEdge(a, b, isCCW)

    return {
        px = a.x + nx * insetDistance,
        pz = a.z + nz * insetDistance,
        dx = b.x - a.x,
        dz = b.z - a.z
    }
end

function FieldPointGenerator:intersectLines2D(line1, line2)
    local det = line1.dx * line2.dz - line1.dz * line2.dx

    if math.abs(det) < 0.0001 then
        return nil
    end

    local rx = line2.px - line1.px
    local rz = line2.pz - line1.pz
    local t = (rx * line2.dz - rz * line2.dx) / det

    return {
        x = line1.px + line1.dx * t,
        z = line1.pz + line1.dz * t
    }
end

function FieldPointGenerator:getBisectorInsetPoint(prevPoint, curPoint, nextPoint, insetDistance, isCCW)
    local n1x, n1z = self:getInwardNormalForEdge(prevPoint, curPoint, isCCW)
    local n2x, n2z = self:getInwardNormalForEdge(curPoint, nextPoint, isCCW)

    local bx = n1x + n2x
    local bz = n1z + n2z

    bx, bz = self:normalize2D(bx, bz)

    if math.abs(bx) < 0.0001 and math.abs(bz) < 0.0001 then
        bx, bz = n1x, n1z
    end

    return {
        x = curPoint.x + bx * insetDistance,
        y = curPoint.y,
        z = curPoint.z + bz * insetDistance
    }
end

function FieldPointGenerator:offsetPolygonProper(points, insetDistance)
    -- if points == nil or #points < 3 or insetDistance <= 0 then
    if points == nil or #points < 3 then
        return points
    end

    local result = {}
    local isCCW = self:getSignedArea(points) > 0

    for i = 1, #points do
        local prevIndex = i - 1
        local nextIndex = i + 1

        if prevIndex < 1 then
            prevIndex = #points
        end
        if nextIndex > #points then
            nextIndex = 1
        end

        local prevPoint = points[prevIndex]
        local curPoint = points[i]
        local nextPoint = points[nextIndex]

        local line1 = self:getOffsetEdgeLine(prevPoint, curPoint, insetDistance, isCCW)
        local line2 = self:getOffsetEdgeLine(curPoint, nextPoint, insetDistance, isCCW)

        local intersection = self:intersectLines2D(line1, line2)
        local finalPoint = nil

        if intersection ~= nil then
            local distanceToCur = math.sqrt((intersection.x - curPoint.x) ^ 2 + (intersection.z - curPoint.z) ^ 2)
            local maxMiter = insetDistance * FieldPointGenerator.MAX_MITER_FACTOR

            if distanceToCur <= maxMiter then
                finalPoint = {
                    x = intersection.x,
                    y = curPoint.y,
                    z = intersection.z
                }
            end
        end

        if finalPoint == nil then
            finalPoint = self:getBisectorInsetPoint(prevPoint, curPoint, nextPoint, insetDistance, isCCW)
        end

        result[#result + 1] = finalPoint
    end

    return self:cleanupPoints(result)
end

function FieldPointGenerator:lerpPoint(a, b, t)
    return {
        x = a.x + (b.x - a.x) * t,
        y = a.y + (b.y - a.y) * t,
        z = a.z + (b.z - a.z) * t
    }
end

function FieldPointGenerator:resampleClosedPolygon(points, spacing)
    if points == nil or #points < 3 or spacing <= 0 then
        return points
    end

    local result = {}

    for i = 1, #points do
        local p0 = points[i]
        local p1 = points[i + 1]
        if p1 == nil then
            p1 = points[1]
        end

        local dist = self:getDistance2D(p0, p1)
        local steps = math.max(1, math.ceil(dist / spacing))

        for s = 0, steps - 1 do
            local t = s / steps
            result[#result + 1] = self:lerpPoint(p0, p1, t)
        end
    end

    return self:cleanupPoints(result)
end

function FieldPointGenerator:chaikinClosed(points)
    local result = {}

    if points == nil or #points < 3 then
        return points
    end

    for i = 1, #points do
        local p0 = points[i]
        local p1 = points[i + 1]

        if p1 == nil then
            p1 = points[1]
        end

        local q = {
            x = 0.75 * p0.x + 0.25 * p1.x,
            y = 0.75 * p0.y + 0.25 * p1.y,
            z = 0.75 * p0.z + 0.25 * p1.z
        }

        local r = {
            x = 0.25 * p0.x + 0.75 * p1.x,
            y = 0.25 * p0.y + 0.75 * p1.y,
            z = 0.25 * p0.z + 0.75 * p1.z
        }

        result[#result + 1] = q
        result[#result + 1] = r
    end

    return self:cleanupPoints(result)
end

function FieldPointGenerator:transformFieldPoints(points)
    local transformed = points

    -- transformed = self:offsetPolygonProper(transformed, FieldPointGenerator.INSET_METERS)
    -- transformed = self:resampleClosedPolygon(transformed, FieldPointGenerator.RESAMPLE_SPACING)
    transformed = self:offsetPolygonProper(transformed, self.insetMeters)
    transformed = self:resampleClosedPolygon(transformed, self.resampleSpacing)

    for _ = 1, FieldPointGenerator.SMOOTH_ITERATIONS do
        transformed = self:chaikinClosed(transformed)
    end

    transformed = self:cleanupPoints(transformed)

    return transformed
end

function FieldPointGenerator:getFieldJob(fieldID)
    local job

    if g_fieldManager == nil or g_fieldManager.fields == nil then
        return job
    end

    for _, field in pairs(g_fieldManager.fields) do
        local tempFieldId = self:getFieldId(field)

        if tempFieldId ~= nil and tempFieldId == fieldID then
            local originalPoints = self:getFieldWorldPoints(field)

            if originalPoints ~= nil and #originalPoints >= 3 then
                local transformedPoints = self:transformFieldPoints(originalPoints)

                if transformedPoints ~= nil and #transformedPoints >= 3 then
                    job = {
                        fieldId = tempFieldId,
                        originalPoints = originalPoints,
                        points = transformedPoints,
                        originalCount = #originalPoints,
                        transformedCount = #transformedPoints
                    }
                    return job
                else
                    print(string.format("[AD][FPG] Skipped field %d because transformed points were invalid", tempFieldId))
                end
            else
                print(string.format("[AD][FPG] Skipped field %d because original polygon was invalid", tempFieldId))
            end
            break
        end
    end
    if job == nil then
        print(string.format("[AD][FPG] Field %d not found!", fieldID))
    end
    return job
end

function FieldPointGenerator:getMaxWaypointId(waypoints)
    local maxId = 0

    for _, wp in ipairs(waypoints) do
        if wp.id ~= nil and wp.id > maxId then
            maxId = wp.id
        end
    end

    return maxId
end

function FieldPointGenerator:getWaypointById(waypoints, id) -- ???
    for _, wp in ipairs(waypoints) do
        if wp.id == id then
            return wp
        end
    end

    return nil
end

function FieldPointGenerator:addDualConnection(waypoints, aId, bId)
    local a = self:getWaypointById(waypoints, aId)
    local b = self:getWaypointById(waypoints, bId)

    if a == nil or b == nil then
        return false
    end

    self:addUnique(a.out, bId)
    self:addUnique(b.incoming, aId)

    self:addUnique(b.out, aId)
    self:addUnique(a.incoming, bId)

    return true
end

function FieldPointGenerator:removeWrongFieldGeneratorWayPoints(wayPoints)
    local foundWrong = true
    local i = 1
    while #wayPoints > 3 and (i <= #wayPoints or foundWrong == true) do
        foundWrong = false
        local wp_previous = wayPoints[i-1]
        if wp_previous == nil then
            wp_previous = wayPoints[#wayPoints]
        end
        local wp_current = wayPoints[i]
        local wp_ahead = wayPoints[i+1]
        if wp_ahead == nil then
            wp_ahead = wayPoints[1]
        end
        if wp_current ~= nil then
            local angle =
                    math.abs(
                    AutoDrive.angleBetween(
                        {x = wp_ahead.x - wp_current.x, z = wp_ahead.z - wp_current.z},
                        {x = wp_current.x - wp_previous.x, z = wp_current.z - wp_previous.z}
                    )
                )
            if angle > 80 then
                -- start again
                foundWrong = true
                i = 1

                local ret
                ret = table.removeValue(wayPoints, wp_current)
            end
            i = i + 1
        end
    end
end

function FieldPointGenerator:appendLoopToWaypointTableAD(waypoints, points)
    if points == nil or #points < 3 then
        local retText = string.format("Not enough points %s", (points and #points or "999"))
        return false, retText
    end

    local maxId = self:getMaxWaypointId(waypoints)
    local createdIds = {}
    for i = 1, #points do
        local p = points[i]
        local newId = maxId + i

        local waypoint = {
            id = newId,
            x = p.x,
            y = p.y,
            z = p.z,
            out = {},
            incoming = {},
            flags = 0,
            fieldID = self.fieldID
        }
        table.insert(self.waypoints, waypoint)
        createdIds[#createdIds + 1] = newId
    end

    for i = 1, #createdIds do
        local currentId = createdIds[i]
        local nextId = createdIds[i + 1]

        if nextId == nil then
            nextId = createdIds[1]
        end

        local ok = self:addDualConnection(self.waypoints, currentId, nextId)
        if not ok then
            return false, "Failed to build loop connections"
        end
    end

    return true, createdIds
end

function FieldPointGenerator:getWayPointsForFieldID(waypoints, fieldID, insetMeters, resampleSpacing)
    self.insetMeters = insetMeters or 2
    self.resampleSpacing = resampleSpacing or 8
    self.waypoints = {}
    self.fieldID = fieldID

    local job = self:getFieldJob(fieldID)
    if job == nil or job.points == nil then
        print(string.format("[AD][FPG] getWayPointsForFieldID failed job %s points %s", job, job and job.points and #job.points or 999))
        return false, "No valid field jobs found"
    end
    self:removeWrongFieldGeneratorWayPoints(job.points)

    local oldCount = #self.waypoints
    local patchedFields = 0
    local failedFields = 0
    local totalAddedPoints = 0

    local ok, result = self:appendLoopToWaypointTableAD(waypoints, job.points)
    -- local ok, result = self:appendLoopToWaypointTableAD(waypoints, job.originalPoints)

    if ok then
        -- patchedFields = patchedFields + 1
        -- totalAddedPoints = totalAddedPoints + #job.points
        -- print(string.format(
        --     "[AD][FPG] Field %d patched | original=%d transformed=%d added=%d",
        --     job.fieldId,
        --     job.originalCount,
        --     job.transformedCount,
        --     #job.points
        -- ))
    else
        failedFields = failedFields + 1
        print(string.format("[AD][FPG] Field %d failed: %s", job.fieldId, tostring(result)))
    end
    return self.waypoints
end
