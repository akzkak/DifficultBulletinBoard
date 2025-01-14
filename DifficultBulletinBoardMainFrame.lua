DifficultBulletinBoard = DifficultBulletinBoard or {}
DifficultBulletinBoardVars = DifficultBulletinBoardVars or {}
DifficultBulletinBoardMainFrame = DifficultBulletinBoardMainFrame or {}

local string_gfind = string.gmatch or string.gfind

local mainFrame = DifficultBulletinBoardMainFrame

local groupScrollFrame
local groupScrollChild
local professionScrollFrame
local professionScrollChild
local hardcoreScrollFrame
local hardcoreScrollChild

local groupsButton = DifficultBulletinBoardMainFrameGroupsButton
local professionsButton = DifficultBulletinBoardMainFrameProfessionsButton
local hcMessagesButton = DifficultBulletinBoardMainFrameHCMessagesButton

local groupTopicPlaceholders = {}
local professionTopicPlaceholders = {}
local hardcoreTopicPlaceholders = {}

local function print(string) 
    --DEFAULT_CHAT_FRAME:AddMessage(string) 
end

-- function to reduce noise in messages and making matching easier
local function replaceSymbolsWithSpace(inputString)
    inputString = string.gsub(inputString, "[,/!%?]", " ")

    return inputString
end



local function topicPlaceholdersContainsCharacterName(topicPlaceholders, topicName, characterName)
    local topicData = topicPlaceholders[topicName]
    if not topicData or not topicData.FontStrings then
        print("Nothing in here yet")
        return false, nil
    end

    for index, row in ipairs(topicData.FontStrings) do
        local nameColumn = row[1]

        if nameColumn:GetText() == characterName then
            print("Already in there!")
            return true, index
        end
    end

    return false, nil
end

-- Updates the specified placeholder for a topic with new name, message, and timestamp,
-- then moves the updated entry to the top of the list, shifting other entries down.
local function UpdateTopicPlaceholderWithShift(topicPlaceholders, topic, numberOfPlaceholders, channelName, name, message, index)
    local topicData = topicPlaceholders[topic]
    local FontStringsList = {}

    if not topicData or not topicData.FontStrings then
        print("No FontStrings found for topic:", topic)
        return nil
    end

    for i, row in ipairs(topicData.FontStrings) do
        local entryList = {}

        for j, fontString in ipairs(row) do
            local text = fontString:GetText()
            table.insert(entryList, text)
        end

        table.insert(FontStringsList, entryList)
    end

    local currentTime = date("%H:%M:%S")
    FontStringsList[index][1] = name
    FontStringsList[index][2] = "[" .. channelName .. "] " .. message
    FontStringsList[index][3] = currentTime

    local tempFontStringsList = table.remove(FontStringsList, index)
    table.insert(FontStringsList, 1, tempFontStringsList)

    for i = 1, numberOfPlaceholders, 1 do
        local currentFontString = topicData.FontStrings[i]

        currentFontString[1]:SetText(FontStringsList[i][1])
        currentFontString[2]:SetText(FontStringsList[i][2])
        currentFontString[3]:SetText(FontStringsList[i][3])
    end
end

-- Function to update the first placeholder for a given topic with new name, message, and time and shift other placeholders down
local function UpdateFirstPlaceholderAndShiftDown(topicPlaceholders, topic, channelName, name, message)
    local topicData = topicPlaceholders[topic]
    if not topicData or not topicData.FontStrings or not topicData.FontStrings[1] then
        print("No placeholders found for topic: " .. topic)
        return
    end

    local currentTime = date("%H:%M:%S")

    local index = 0
    for i, _ in ipairs(topicData.FontStrings) do index = i end

    for i = index, 2, -1 do
        -- Copy the data from the previous placeholder to the current one
        local currentFontString = topicData.FontStrings[i]
        local previousFontString = topicData.FontStrings[i - 1]

        -- Update the current placeholder with the previous placeholder's data
        currentFontString[1]:SetText(previousFontString[1]:GetText())
        currentFontString[2]:SetText(previousFontString[2]:GetText())
        currentFontString[3]:SetText(previousFontString[3]:GetText())
    end

    -- Update the first placeholder with the new data
    local firstFontString = topicData.FontStrings[1]
    firstFontString[1]:SetText(name or "No Name")
    firstFontString[2]:SetText("[" .. channelName .. "] " .. message or "No Message")
    firstFontString[3]:SetText(currentTime or "No Time")
end

-- Function to update the first placeholder for a given topic with new name, message, and time and shift other placeholders down
local function UpdateFirstSystemPlaceholderAndShiftDown(topicPlaceholders, topic, message)
    local topicData = topicPlaceholders[topic]
    if not topicData or not topicData.FontStrings or not topicData.FontStrings[1] then
        print("No placeholders found for topic: " .. topic)
        return
    end

    local currentTime = date("%H:%M:%S")

    local index = 0
    for i, _ in ipairs(topicData.FontStrings) do index = i end
        for i = index, 2, -1 do
            -- Copy the data from the previous placeholder to the current one
            local currentFontString = topicData.FontStrings[i]
            local previousFontString = topicData.FontStrings[i - 1]

            -- Update the current placeholder with the previous placeholder's data
            currentFontString[2]:SetText(previousFontString[2]:GetText())
            currentFontString[3]:SetText(previousFontString[3]:GetText())
        end

    -- Update the first placeholder with the new data
    local firstFontString = topicData.FontStrings[1]
    firstFontString[2]:SetText(message or "No Message")
    firstFontString[3]:SetText(currentTime or "No Time")
end

-- Searches the passed topicList for the passed words. If a match is found the topicPlaceholders will be updated
local function analyzeChatMessage(channelName, characterName, chatMessage, words, topicList, topicPlaceholders, numberOfPlaceholders)
    for _, topic in ipairs(topicList) do
        local matchFound = false -- Flag to control breaking out of nested loops

        for _, tag in ipairs(topic.tags) do
            for _, word in ipairs(words) do
                if word == string.lower(tag) then
                    print("Tag '" .. tag .. "' matches Topic: " .. topic.name)
                    local found, index =
                        topicPlaceholdersContainsCharacterName(topicPlaceholders, topic.name, characterName)
                    if found then
                        print("An entry for that character already exists at " .. index)
                        UpdateTopicPlaceholderWithShift(topicPlaceholders, topic.name, numberOfPlaceholders, channelName, characterName, chatMessage, index)
                    else
                        print("No entry for that character exists. Creating one...")
                        UpdateFirstPlaceholderAndShiftDown(topicPlaceholders, topic.name, channelName, characterName, chatMessage)
                    end

                    matchFound = true -- Set the flag to true to break out of loops
                    break
                end
            end

            if matchFound then break end
        end
    end
end

function DifficultBulletinBoard.OnChatMessage(arg1, arg2, arg9)
    local chatMessage = arg1
    local characterName = arg2
    local channelName = arg9
    
    print(chatMessage)
    print(channelName)

    local stringWithoutNoise = replaceSymbolsWithSpace(chatMessage)

    print(stringWithoutNoise)

    local words = DifficultBulletinBoard.SplitIntoLowerWords(stringWithoutNoise)

    analyzeChatMessage(channelName, characterName, chatMessage, words, DifficultBulletinBoardVars.allGroupTopics, groupTopicPlaceholders, DifficultBulletinBoardVars.numberOfGroupPlaceholders)
    analyzeChatMessage(channelName, characterName, chatMessage, words, DifficultBulletinBoardVars.allProfessionTopics, professionTopicPlaceholders, DifficultBulletinBoardVars.numberOfProfessionPlaceholders)
end

-- Searches the passed topicList for the passed words. If a match is found the topicPlaceholders will be updated
local function analyzeSystemMessage(chatMessage, words, topicList, topicPlaceholders)
    for _, topic in ipairs(topicList) do
        local matchFound = false -- Flag to control breaking out of nested loops

        for _, tag in ipairs(topic.tags) do
            for _, word in ipairs(words) do
                if word == string.lower(tag) then
                    print("Tag '" .. tag .. "' matches Topic: " .. topic.name)
                    print("Creating one...")
                    UpdateFirstSystemPlaceholderAndShiftDown(topicPlaceholders,topic.name, chatMessage)

                    matchFound = true -- Set the flag to true to break out of loops
                    break
                end
            end

            if matchFound then break end
        end
    end
end

function DifficultBulletinBoard.OnSystemMessage(arg1)
    local systemMessage = arg1

    local stringWithoutNoise = replaceSymbolsWithSpace(systemMessage)

    local words = DifficultBulletinBoard.SplitIntoLowerWords(stringWithoutNoise)

    analyzeSystemMessage(systemMessage, words, DifficultBulletinBoardVars.allHardcoreTopics, hardcoreTopicPlaceholders)
end

local function configureTabSwitching()
    local tabs = {
        { button = groupsButton, frame = groupScrollFrame },
        { button = professionsButton, frame = professionScrollFrame },
        { button = hcMessagesButton, frame = hardcoreScrollFrame },
    }

    local function ResetButtonStates()
        for _, tab in ipairs(tabs) do
            tab.button:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
            tab.frame:Hide()
        end
    end

    local function ActivateTab(activeTab)
        activeTab.button:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Down")
        activeTab.frame:Show()
    end

    for _, tab in ipairs(tabs) do
        local currentTab = tab
        tab.button:SetScript("OnClick", function()
            ResetButtonStates()
            ActivateTab(currentTab)
        end)
    end

    -- set groups as the initial tab
    ActivateTab(tabs[1])
end

-- function to create the placeholders and font strings for a topic
local function createNameMessageDateTopicList(contentFrame, topicList, topicPlaceholders, numberOfPlaceholders)
    -- initial Y-offset for the first header and placeholder
    local yOffset = 0

    for _, topic in ipairs(topicList) do
        if topic.selected then
            local header = contentFrame:CreateFontString("$parent_" .. topic.name .. "Header", "OVERLAY", "GameFontNormal")
            header:SetText(topic.name)
            header:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 10, yOffset)
            header:SetWidth(200)
            header:SetJustifyH("LEFT")
            header:SetTextColor(1, 1, 0)
            header:SetFont("Fonts\\FRIZQT__.TTF", 12)

            -- Store the header Y offset for the current topic
            local topicYOffset = yOffset - 20 -- space between header and first placeholder
            yOffset = topicYOffset - 110 -- space between headers

            topicPlaceholders[topic.name] = topicPlaceholders[topic.name] or {FontStrings = {}}

            for i = 1, numberOfPlaceholders do
                -- create Name column as a button
                local nameButton = CreateFrame("Button", "$parent_" .. topic.name .. "Placeholder" .. i .. "_Name", contentFrame, nil)
                nameButton:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 10, topicYOffset)
                nameButton:SetWidth(150)
                nameButton:SetHeight(14)

                -- Set the text of the button
                local buttonText = nameButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                buttonText:SetText("-")
                buttonText:SetPoint("LEFT", nameButton, "LEFT", 5, 0)
                buttonText:SetFont("Fonts\\FRIZQT__.TTF", 12)
                buttonText:SetTextColor(1, 1, 1)
                nameButton:SetFontString(buttonText)

                -- Set scripts for hover behavior
                nameButton:SetScript("OnEnter", function()
                    buttonText:SetFont("Fonts\\FRIZQT__.TTF", 12) -- Highlight font
                    buttonText:SetTextColor(1, 1, 0) -- Highlight color (e.g., yellow)
                end)

                nameButton:SetScript("OnLeave", function()
                    buttonText:SetFont("Fonts\\FRIZQT__.TTF", 12) -- Normal font
                    buttonText:SetTextColor(1, 1, 1) -- Normal color (e.g., white)
                end)

                -- Add an example OnClick handler
                nameButton:SetScript("OnClick", function()
                    print("Clicked on: " .. nameButton:GetText())
                    local pressedButton = arg1
                    local targetName = nameButton:GetText()

                    -- dont do anything when its a placeholder
                    if targetName == "-" then return end

                    if pressedButton == "LeftButton" then
                        if IsShiftKeyDown() then
                            print("who")
                            SendWho(targetName)
                        else
                            print("whisp")
                            ChatFrame_OpenChat("/w " .. targetName)
                        end
                    end
                end)

                -- OnClick doesnt support right clicking... so lets just check OnMouseDown instead
                nameButton:SetScript("OnMouseDown", function()
                    local pressedButton = arg1
                    local targetName = nameButton:GetText()

                    -- dont do anything when its a placeholder
                    if targetName == "-" then return end

                    if pressedButton == "RightButton" then
                        ChatFrame_OpenChat("/invite " .. targetName)
                    end
                end)

                -- create Message column
                local messageColumn = contentFrame:CreateFontString("$parent_" .. topic.name .. "Placeholder" .. i .. "_Message", "OVERLAY", "GameFontNormal")
                messageColumn:SetText("-")
                messageColumn:SetPoint("TOPLEFT", nameButton, "TOPRIGHT", 50, 0)
                messageColumn:SetWidth(650)
                messageColumn:SetHeight(10)
                messageColumn:SetJustifyH("LEFT")
                messageColumn:SetTextColor(1, 1, 1)
                messageColumn:SetFont("Fonts\\FRIZQT__.TTF", 12)

                -- create Time column
                local timeColumn = contentFrame:CreateFontString("$parent_" .. topic.name .. "Placeholder" .. i .. "_Time", "OVERLAY", "GameFontNormal")
                timeColumn:SetText("-")
                timeColumn:SetPoint("TOPLEFT", messageColumn, "TOPRIGHT", 20, 0)
                timeColumn:SetWidth(100)
                timeColumn:SetJustifyH("LEFT")
                timeColumn:SetTextColor(1, 1, 1)
                timeColumn:SetFont("Fonts\\FRIZQT__.TTF", 12)

                table.insert(topicPlaceholders[topic.name].FontStrings, {nameButton, messageColumn, timeColumn})

                -- Increment the Y-offset for the next placeholder
                topicYOffset = topicYOffset - 18 -- space between placeholders
            end

            -- After the placeholders, adjust the main yOffset for the next topic
            yOffset = topicYOffset - 10 -- space between topics
        end
    end
end

    -- function to create the placeholders and font strings for a topic
local function createMessageDateTopicList(contentFrame, topicList, topicPlaceholders, numberOfPlaceholders)
    -- initial Y-offset for the first header and placeholder
    local yOffset = 0

    for _, topic in ipairs(topicList) do
        if topic.selected then
            local header = contentFrame:CreateFontString("$parent_" .. topic.name ..  "Header", "OVERLAY", "GameFontNormal")
            header:SetText(topic.name)
            header:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 10, yOffset)
            header:SetWidth(200)
            header:SetJustifyH("LEFT")
            header:SetTextColor(1, 1, 0)
            header:SetFont("Fonts\\FRIZQT__.TTF", 12)

            -- Store the header Y offset for the current topic
            local topicYOffset = yOffset - 20 -- space between header and first placeholder
            yOffset = topicYOffset - 110 -- space between headers

            topicPlaceholders[topic.name] = topicPlaceholders[topic.name] or {FontStrings = {}}

            for i = 1, numberOfPlaceholders do

                -- create Message column
                local messageColumn = contentFrame:CreateFontString("$parent_" .. topic.name .. "Placeholder" .. i .. "_Message", "OVERLAY", "GameFontNormal")
                messageColumn:SetText("-")
                messageColumn:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 15, topicYOffset)
                messageColumn:SetWidth(846)
                messageColumn:SetHeight(14)
                messageColumn:SetJustifyH("LEFT")
                messageColumn:SetTextColor(1, 1, 1)
                messageColumn:SetFont("Fonts\\FRIZQT__.TTF", 12)

                -- create Time column
                local timeColumn = contentFrame:CreateFontString("$parent_" .. topic.name .. "Placeholder" .. i .. "_Time", "OVERLAY", "GameFontNormal")
                timeColumn:SetText("-")
                timeColumn:SetPoint("TOPLEFT", messageColumn, "TOPRIGHT", 19, 0)
                timeColumn:SetWidth(100)
                timeColumn:SetJustifyH("LEFT")
                timeColumn:SetTextColor(1, 1, 1)
                timeColumn:SetFont("Fonts\\FRIZQT__.TTF", 12)

                table.insert( topicPlaceholders[topic.name].FontStrings, {nil, messageColumn, timeColumn})

                -- Increment the Y-offset for the next placeholder
                topicYOffset = topicYOffset - 18 -- space between placeholders
            end

            -- After the placeholders, adjust the main yOffset for the next topic
            yOffset = topicYOffset - 10 -- space between topics
        end
    end
end

local function createScrollFrameForMainFrame(scrollFrameName)
    -- Create the ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", scrollFrameName, mainFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:EnableMouseWheel(true)

    -- Set ScrollFrame anchors
    scrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 0, -80)
    scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -26, 10)

    -- Create the ScrollChild (content frame)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetHeight(1)
    scrollChild:SetWidth(980)

    -- Attach the ScrollChild to the ScrollFrame
    scrollFrame:SetScrollChild(scrollChild)

    -- Default Hide, because the default tab shows the correct frame later
    scrollFrame:Hide()

    return scrollFrame, scrollChild
end

function DifficultBulletinBoardMainFrame.InitializeMainFrame()
    groupScrollFrame, groupScrollChild = createScrollFrameForMainFrame("DifficultBulletinBoardMainFrame_Group_ScrollFrame")
    createNameMessageDateTopicList(groupScrollChild, DifficultBulletinBoardVars.allGroupTopics, groupTopicPlaceholders, DifficultBulletinBoardVars.numberOfGroupPlaceholders)
    professionScrollFrame, professionScrollChild = createScrollFrameForMainFrame("DifficultBulletinBoardMainFrame_Profession_ScrollFrame")
    createNameMessageDateTopicList(professionScrollChild, DifficultBulletinBoardVars.allProfessionTopics, professionTopicPlaceholders, DifficultBulletinBoardVars.numberOfProfessionPlaceholders)
    hardcoreScrollFrame, hardcoreScrollChild = createScrollFrameForMainFrame("DifficultBulletinBoardMainFrame_Hardcore_ScrollFrame")
    createMessageDateTopicList(hardcoreScrollChild, DifficultBulletinBoardVars.allHardcoreTopics, hardcoreTopicPlaceholders, DifficultBulletinBoardVars.numberOfHardcorePlaceholders)

    -- add topic group tab switching
    configureTabSwitching()
end