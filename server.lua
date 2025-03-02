-- Event to receive invalid props from client and trigger server-side analysis
RegisterNetEvent('ak47_scan_props:clientScanCompleted')
AddEventHandler('ak47_scan_props:clientScanCompleted', function(invalidProps)
    source = source -- Client ID who sent the event
    logFile = "scan_results.log"
    invalidLogFile = "invalid_props.log"

    -- Overwrite logs at the start of each scan
    fileOverwrite(logFile, "") -- Clear scan_results.log
    fileOverwrite(invalidLogFile, "") -- Clear invalid_props.log

    -- Print start message in red
    print("^1[SCAN] Starting server-side analysis...^7")

    -- Log initial receipt of scan results
    fileAppend(logFile, string.format("[%s] Received scan results from client %d\n", os.date("%Y-%m-%d %H:%M:%S"), source))

    -- Process invalid props from client
    if #invalidProps > 0 then
        fileAppend(logFile, "Invalid Props Reported by Client:\n")
        consoleMsg = "^1[SCAN] Props to remove from Furniture.Objects:^7\n"
        for i, invalidProp in ipairs(invalidProps) do
            logEntry = string.format("%d. Category: %s | Object: %s | Name: %s\n", 
                i, invalidProp.category, invalidProp.object, invalidProp.name)
            fileAppend(logFile, logEntry)
            
            -- Add to console message
            consoleMsg = consoleMsg .. string.format("^1%d. Category: %s | Object: %s | Name: %s^7\n", 
                i, invalidProp.category, invalidProp.object, invalidProp.name)
            
            -- Log to invalid_props.log
            invalidLogEntry = string.format("[%s] Invalid Prop: Category=%s, Object=%s, Name=%s\n", 
                os.date("%Y-%m-%d %H:%M:%S"), invalidProp.category, invalidProp.object, invalidProp.name)
            fileAppend(invalidLogFile, invalidLogEntry)
        end
        print(consoleMsg) -- Print all invalid props in red
    else
        fileAppend(logFile, "No invalid props reported by client " .. source .. "\n")
        print("^1[SCAN] No props need to be removed from Furniture.Objects.^7")
    end

    -- Run housing analysis with client-detected invalid props
    AnalyzeFurnitureUsage(invalidProps, logFile)

    -- Print message if invalid props exist, prompting to fix them
    if #invalidProps > 0 then
        print("^1[SCAN] Invalid props detected. Run '/remove_invalid_props' to remove them from houses.^7")
    end
end)

-- Command to remove invalid props from houses
RegisterCommand("remove_invalid_props", function(source, args, rawCommand)
    if source ~= 0 then
        print("This command can only be run from the server console.")
        return
    end

    if not exports.oxmysql then
        print("^1[REMOVE_INVALID] ERROR: oxmysql not found. Cannot proceed.^7")
        return
    end

    print("^1[REMOVE_INVALID] Starting removal of invalid props from houses...^7")

    -- Read invalid_props.log to get list of invalid props
    invalidProps = readInvalidPropsFromLog()
    if not invalidProps or #invalidProps == 0 then
        print("^1[REMOVE_INVALID] No invalid props found in invalid_props.log.^7")
        return
    end

    -- Build a lookup table for invalid props
    invalidPropLookup = {}
    for _, prop in ipairs(invalidProps) do
        invalidPropLookup[prop] = true
    end

    -- Scan and update houses
    exports.oxmysql:execute("SELECT id, furnitures FROM ak47_housing", {}, function(result)
        if not result or #result == 0 then
            print("^1[REMOVE_INVALID] No data found in ak47_housing table.^7")
            return
        end

        updatedHouses = 0
        for _, row in ipairs(result) do
            houseId = row.id
            furnituresJson = row.furnitures

            if furnituresJson and furnituresJson ~= "" then
                success, furnitures = pcall(json.decode, furnituresJson)
                if not success then
                    print("^1[REMOVE_INVALID] Failed to decode JSON for house " .. houseId .. ": " .. furnituresJson .. "^7")
                    goto continue
                end

                -- Filter out invalid props
                modified = false
                newFurnitures = {}
                for key, item in pairs(furnitures) do
                    propName = item.hashname or tostring(item.object)
                    if not invalidPropLookup[propName] then
                        newFurnitures[key] = item -- Keep valid props
                    else
                        modified = true
                        print("^1[REMOVE_INVALID] Removed prop " .. propName .. " from house " .. houseId .. "^7")
                    end
                end

                -- Update database if modified
                if modified then
                    updatedFurnituresJson = json.encode(newFurnitures)
                    exports.oxmysql:execute("UPDATE ak47_housing SET furnitures = ? WHERE id = ?", {updatedFurnituresJson, houseId})
                    updatedHouses = updatedHouses + 1
                end
            end

            ::continue::
        end

        print("^1[REMOVE_INVALID] Completed. Updated " .. updatedHouses .. " houses with invalid props removed.^7")
    end)
end, false)

-- Function to read invalid props from invalid_props.log
function readInvalidPropsFromLog()
    resourcePath = GetResourcePath(GetCurrentResourceName())
    fullPath = resourcePath .. "/invalid_props.log"
    file, err = io.open(fullPath, "r")
    if not file then
        print("Error: Could not open invalid_props.log for reading. Reason: " .. (err or "unknown"))
        return {}
    end

    invalidProps = {}
    for line in file:lines() do
        -- Parse lines like "[timestamp] Invalid Prop: Category=X, Object=Y, Name=Z"
        objectMatch = line:match("Object=([^,]+),")
        if objectMatch then
            table.insert(invalidProps, objectMatch)
        end
    end
    file:close()
    return invalidProps
end

-- Function to analyze furniture usage in ak47_housing table
function AnalyzeFurnitureUsage(invalidProps, logFile)
    fileAppend(logFile, "Starting furniture analysis from ak47_housing table...\n")

    if not exports.oxmysql then
        fileAppend(logFile, "ERROR: oxmysql not found. Furniture analysis skipped.\n")
        return
    end

    if not Furniture or not Furniture.Objects then
        fileAppend(logFile, "ERROR: Furniture.Objects not loaded. Cannot check missing props.\n")
        return
    end

    -- Build a lookup table for Furniture.Objects
    configProps = {}
    for category, objects in pairs(Furniture.Objects) do
        for _, prop in pairs(objects) do
            configProps[prop.object] = true
        end
    end

    -- Convert invalid props to a lookup table for faster checking
    invalidPropLookup = {}
    for _, invalidProp in ipairs(invalidProps) do
        invalidPropLookup[invalidProp.object] = true
    end

    exports.oxmysql:execute("SELECT id, furnitures FROM ak47_housing", {}, function(result)
        if not result or #result == 0 then
            fileAppend(logFile, "No data found in ak47_housing table.\n")
            return
        end

        propUsage = {}
        housePropCounts = {}
        housesWithInvalidProps = {}
        missingProps = {}

        for _, row in ipairs(result) do
            houseId = row.id
            furnituresJson = row.furnitures

            if furnituresJson and furnituresJson ~= "" then
                success, furnitures = pcall(json.decode, furnituresJson)
                if not success then
                    fileAppend(logFile, string.format("Failed to decode JSON for house %d: %s\n", houseId, furnituresJson))
                    goto continue
                end

                housePropCounts[houseId] = {}
                for _, item in pairs(furnitures) do
                    propName = item.hashname or tostring(item.object)
                    if not propName then
                        fileAppend(logFile, string.format("Warning: No hashname or object found for item in house %d\n", houseId))
                        goto skipItem
                    end

                    propUsage[propName] = (propUsage[propName] or 0) + 1
                    housePropCounts[houseId][propName] = (housePropCounts[houseId][propName] or 0) + 1

                    if invalidPropLookup[propName] then
                        if not housesWithInvalidProps[houseId] then
                            housesWithInvalidProps[houseId] = {}
                        end
                        housesWithInvalidProps[houseId][propName] = (housesWithInvalidProps[houseId][propName] or 0) + 1
                    end

                    if not configProps[propName] then
                        if not missingProps[propName] then
                            missingProps[propName] = {}
                        end
                        missingProps[propName][houseId] = (missingProps[propName][houseId] or 0) + 1
                    end

                    ::skipItem::
                end
            else
                fileAppend(logFile, string.format("House %d has no furniture data.\n", houseId))
            end

            ::continue::
        end

        fileAppend(logFile, "=== Global Prop Usage Summary ===\n")
        totalProps = 0
        for propName, count in pairs(propUsage) do
            fileAppend(logFile, string.format("Prop: %s | Used: %d times\n", propName, count))
            totalProps = totalProps + count
        end
        fileAppend(logFile, string.format("Total unique props: %d | Total instances: %d\n", tableCount(propUsage), totalProps))

        fileAppend(logFile, "\n=== Prop Usage Per House ===\n")
        for houseId, props in pairs(housePropCounts) do
            fileAppend(logFile, string.format("House ID: %d\n", houseId))
            houseTotal = 0
            for propName, count in pairs(props) do
                fileAppend(logFile, string.format("  Prop: %s | Count: %d\n", propName, count))
                houseTotal = houseTotal + count
            end
            fileAppend(logFile, string.format("  Total props in house: %d\n", houseTotal))
        end

        if next(housesWithInvalidProps) then
            fileAppend(logFile, "\n=== Houses Using Invalid Props ===\n")
            for houseId, invalidPropsInHouse in pairs(housesWithInvalidProps) do
                fileAppend(logFile, string.format("House ID: %d\n", houseId))
                for propName, count in pairs(invalidPropsInHouse) do
                    fileAppend(logFile, string.format("  Invalid Prop: %s | Count: %d\n", propName, count))
                end
            end
        else
            fileAppend(logFile, "\nNo houses found using invalid props.\n")
        end

        if next(missingProps) then
            fileAppend(logFile, "\n=== Props Missing from Furniture.Objects ===\n")
            for propName, houses in pairs(missingProps) do
                fileAppend(logFile, string.format("Prop: %s\n", propName))
                for houseId, count in pairs(houses) do
                    fileAppend(logFile, string.format("  Used in House ID: %d | Count: %d\n", houseId, count))
                end
            end
        else
            fileAppend(logFile, "\nNo props found in houses that are missing from Furniture.Objects.\n")
        end

        fileAppend(logFile, "Furniture analysis completed.\n")

        -- Print completion message in red after analysis
        print("^1[SCAN] Server-side analysis completed.^7")
    end)
end

-- Helper function to count table entries
function tableCount(tbl)
    count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

-- Helper function to append to a file in the resource folder
function fileAppend(filename, text)
    resourcePath = GetResourcePath(GetCurrentResourceName())
    fullPath = resourcePath .. "/" .. filename
    file, err = io.open(fullPath, "a")
    if file then
        file:write(text)
        file:close()
    else
        print("Error: Could not open file " .. fullPath .. " for writing. Reason: " .. (err or "unknown"))
    end
end

-- Helper function to overwrite a file in the resource folder
function fileOverwrite(filename, text)
    resourcePath = GetResourcePath(GetCurrentResourceName())
    fullPath = resourcePath .. "/" .. filename
    file, err = io.open(fullPath, "w") -- "w" mode overwrites the file
    if file then
        file:write(text)
        file:close()
    else
        print("Error: Could not overwrite file " .. fullPath .. ". Reason: " .. (err or "unknown"))
    end
end