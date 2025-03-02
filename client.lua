Citizen.CreateThread(function()
    Citizen.Wait(5000)

    if not Furniture or not Furniture.Objects then
        print("ERROR: Config table is not loaded! Check lua.")
        return
    end
end)

-- Function to check if a model exists
local function DoesModelExist(model)
    if type(model) ~= "string" then
        print("Invalid model type: " .. tostring(model))
        return false
    end
    local modelHash = GetHashKey(model)
    local inCdImage = IsModelInCdimage(modelHash)
    local isValid = IsModelValid(modelHash)
    
    if not (inCdImage and isValid) then
        print(string.format("Model check failed: %s | InCdImage: %s | IsValid: %s", 
            model, tostring(inCdImage), tostring(isValid)))
    end
    
    return inCdImage and isValid
end

-- Function to scan props and send results to server
local function ScanProps()
    print("Starting prop scan...")
    local totalProps = 0
    local validProps = 0
    local invalidProps = {}

    for category, objects in pairs(Furniture.Objects) do
        print("Scanning category: " .. category)
        for _, prop in pairs(objects) do
            totalProps = totalProps + 1
            local objectName = prop.object
            local modelExists = DoesModelExist(objectName)

            if modelExists then
                validProps = validProps + 1
            else
                table.insert(invalidProps, {
                    category = category,
                    object = objectName,
                    name = prop.name
                })
            end

            if totalProps % 25 == 0 then
                print(string.format("Progress: Checked %d props (%d valid)", totalProps, validProps))
            end

            Citizen.Wait(0)
        end
    end

    print("=== Prop Scan Completed ===")
    print(string.format("Total Props Checked: %d", totalProps))
    print(string.format("Valid Props: %d (%.2f%%)", validProps, (validProps / totalProps) * 100))
    print(string.format("Invalid Props: %d", #invalidProps))

    if #invalidProps > 0 then
        print("Invalid Props Found:")
        for i, invalidProp in ipairs(invalidProps) do
            print(string.format("%d. Category: %s | Object: %s | Name: %s", 
                i, invalidProp.category, invalidProp.object, invalidProp.name))
        end
    else
        print("No invalid props found!")
    end

    -- Send invalid props to server
    TriggerServerEvent('ak47_scan_props:clientScanCompleted', invalidProps)
end

-- Client-side command to initiate the scan
RegisterCommand("scanprops", function(source, args, rawCommand)
    if not Furniture or not Furniture.Objects then
        print("ERROR: Config table is not loaded! Check lua.")
        return
    end
    ScanProps()
end, false)