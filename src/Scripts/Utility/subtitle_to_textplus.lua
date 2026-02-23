local function getResolve()
    local resolve = Resolve()
    if not resolve then
        print("Error: Please run this script inside DaVinci Resolve.")
        return nil
    end
    return resolve
end

local resolve = getResolve()
if not resolve then return end

local projectManager = resolve:GetProjectManager()
local project = projectManager:GetCurrentProject()
local timeline = project:GetCurrentTimeline()
local mediaPool = project:GetMediaPool()

if not timeline then
    print("Error: No timeline is currently active.")
    return
end

-- ==========================================
-- Helper: Find Text+ Generator in Media Pool
-- ==========================================
local function findTextPlusGenerator()
    local rootFolder = mediaPool:GetRootFolder()
    local function searchFolder(folder)
        local clips = folder:GetClipList()
        for _, clip in ipairs(clips) do
            if clip:GetName() == "Text+" then
                return clip
            end
        end
        local subFolders = folder:GetSubFolderList()
        for _, subFolder in ipairs(subFolders) do
            local found = searchFolder(subFolder)
            if found then return found end
        end
        return nil
    end
    return searchFolder(rootFolder)
end

-- ==========================================
-- Fetch available Video Tracks
-- ==========================================
local videoTrackCount = timeline:GetTrackCount("video")
if videoTrackCount == 0 then
    print("Error: No video tracks found on this timeline.")
    return
end

-- ==========================================
-- UI Dialog Definition
-- ==========================================
local ui = fu.UIManager
local disp = bmd.UIDispatcher(ui)
local dialogLayout = ui:VGroup{
    Spacing = 10,
    ui:HGroup{
        Weight = 0,
        ui:Label{ Text = "Target Video Track: ", Weight = 0 },
        ui:HGap(10),
        ui:ComboBox{ ID = "TrackIndexCombo", Weight = 1 }
    },
    ui:Label{
        Text = "Warning: The first Text+ clip on the target track will be used as the style template.\nPlease ensure you have placed and styled one Text+ clip on this track BEFORE running.",
        WordWrap = true,
        Weight = 1
    },
    ui:HGroup{
        Weight = 0,
        ui:Label{ ID = "Spacer", Text = "", Weight = 1 },
        ui:Button{ ID = "CancelBtn", Text = "Cancel", Weight = 0 },
        ui:HGap(10),
        ui:Button{ ID = "GenerateBtn", Text = "Generate", Weight = 0 }
    }
}

local win = disp:AddWindow({
    ID = "MainWin",
    WindowTitle = "Subtitle to Text+ Converter",
    Geometry = { 400, 300, 400, 150 }
}, dialogLayout)

-- Populate ComboBox
for i = 1, videoTrackCount do
    local trackName = timeline:GetTrackName("video", i) or ("Video " .. i)
    win:GetItems().TrackIndexCombo:AddItem("V" .. i .. " (" .. trackName .. ")")
end
win:GetItems().TrackIndexCombo.CurrentIndex = 0

-- ==========================================
-- Main Conversion Logic
-- ==========================================
local function convertSubtitles(targetTrackIndex)
    local subItems = timeline:GetItemListInTrack("subtitle", 1)
    if not subItems or #subItems == 0 then
        print("Error: No subtitles found on Subtitle Track 1.")
        return
    end

    local textPlusGenerator = findTextPlusGenerator()
    if not textPlusGenerator then
        print("Error: 'Text+' generator not found in Media Pool. Please add one to any bin first.")
        return
    end

    -- 1. Extract Target Style
    local targetItems = timeline:GetItemListInTrack("video", targetTrackIndex)
    local templateComp = nil
    if targetItems and #targetItems > 0 then
        for _, item in ipairs(targetItems) do
            if item:GetName() == "Text+" or item:GetFusionCompCount() > 0 then
                templateComp = item:GetFusionCompByIndex(1)
                print("Found template Text+ clip: " .. item:GetName())
                break
            end
        end
    end

    if not templateComp then
        print("Warning: No initial Text+ clip found on Video Track " .. targetTrackIndex .. " to act as a style template. Generated clips will use default styling.")
    end

    -- Extract template settings if available
    local templateSettings = nil
    if templateComp then
         local templateTool = templateComp:GetToolList()[1] -- usually Template tool is first or named "Template"
         if not templateTool then templateTool = templateComp:FindTool("Template") end
         if templateTool then
             templateSettings = templateTool:SaveSettings()
         end
    end

    -- Clear existing clips on target track to prevent overlap and remove the template
    if targetItems and #targetItems > 0 then
        print("Clearing " .. #targetItems .. " existing clips on Video Track " .. targetTrackIndex .. "...")
        timeline:DeleteClips(targetItems, false) 
    end

    -- 2. Build Append Info Array
    local appendInfo = {}
    local subtitleData = {} -- Keep track of text content

    for i, sub in ipairs(subItems) do
        local startFrame = sub:GetStart()
        local endFrame = sub:GetEnd()
        local text = sub:GetName() -- For subtitles, GetName() returns the text content
        
        table.insert(subtitleData, text)
        table.insert(appendInfo, {
            ["mediaPoolItem"] = textPlusGenerator,
            ["startFrame"] = 0,
            ["endFrame"] = endFrame - startFrame,
            ["trackIndex"] = targetTrackIndex,
            ["recordFrame"] = startFrame
        })
    end

    -- 3. Append to Timeline
    print("Appending " .. #appendInfo .. " Text+ clips to Video Track " .. targetTrackIndex .. "...")
    local newItems = mediaPool:AppendToTimeline(appendInfo)
    
    if not newItems or #newItems == 0 then
         print("Error: Failed to append Text+ clips to the timeline.")
         return
    end

    -- 4. Inject Text and Style
    print("Injecting text and applying styles...")
    for i, newItem in ipairs(newItems) do
        local comp = newItem:GetFusionCompByIndex(1)
        if comp then
            local textTool = comp:GetToolList()[1]
            if not textTool then textTool = comp:FindTool("Template") end
            
            if textTool then
                -- Apply saved style first
                if templateSettings then
                    textTool:LoadSettings(templateSettings)
                end
                
                -- Then explicitly set the specific subtitle text
                -- (Overwrites whatever text came from the template)
                local currentText = subtitleData[i]
                if currentText then
                    textTool:SetInput("StyledText", currentText)
                end
            end
        else
            print("Warning: Could not get Fusion comp for new item at index " .. i)
        end
    end

    print("Successfully converted " .. #newItems .. " subtitles to Text+ clips on Video Track " .. targetTrackIndex .. "!")
end

-- ==========================================
-- Event Handlers
-- ==========================================
function win.On.CancelBtn.Clicked(ev)
    disp:ExitLoop()
end

function win.On.MainWin.Close(ev)
    disp:ExitLoop()
end

function win.On.GenerateBtn.Clicked(ev)
    -- CurrentIndex is 0-based, but track indices are 1-based
    local trackIndex = win:GetItems().TrackIndexCombo.CurrentIndex + 1
    disp:ExitLoop()
    convertSubtitles(trackIndex)
end

-- ==========================================
-- Run UI
-- ==========================================
win:Show()
disp:RunLoop()
win:Hide()
