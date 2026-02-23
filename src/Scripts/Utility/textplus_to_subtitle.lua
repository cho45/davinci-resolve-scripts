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
-- Timecode Math Helper
-- ==========================================
local function formatTimecode(frames, frameRate)
    -- Calculate total seconds
    local totalSeconds = frames / frameRate
    
    local hours = math.floor(totalSeconds / 3600)
    local remainder = totalSeconds % 3600
    local minutes = math.floor(remainder / 60)
    local seconds = math.floor(remainder % 60)
    
    -- Extract milliseconds
    local milliseconds = math.floor((totalSeconds - math.floor(totalSeconds)) * 1000 + 0.5)
    
    return string.format("%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
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
        ui:Label{ Text = "Source Video Track: ", Weight = 0 },
        ui:HGap(10),
        ui:ComboBox{ ID = "TrackIndexCombo", Weight = 1 }
    },
    ui:HGroup{
        Weight = 0,
        ui:Label{ Text = "Output Mode: ", Weight = 0 },
        ui:HGap(10),
        ui:ComboBox{ ID = "OutputModeCombo", Weight = 1 }
    },
    ui:Label{
        Text = "Note: 'Apply to Subtitle Track' will overwrite the targeted Subtitle Track.",
        WordWrap = true,
        Weight = 1
    },
    ui:HGroup{
        Weight = 0,
        ui:Label{ ID = "Spacer", Text = "", Weight = 1 },
        ui:Button{ ID = "CancelBtn", Text = "Cancel", Weight = 0 },
        ui:HGap(10),
        ui:Button{ ID = "GenerateBtn", Text = "Convert", Weight = 0 }
    }
}

local win = disp:AddWindow({
    ID = "MainWin",
    WindowTitle = "Text+ to Subtitle (SRT) Converter",
    Geometry = { 400, 300, 400, 150 }
}, dialogLayout)

-- Populate ComboBoxes
for i = 1, videoTrackCount do
    local trackName = timeline:GetTrackName("video", i) or ("Video " .. i)
    win:GetItems().TrackIndexCombo:AddItem("V" .. i .. " (" .. trackName .. ")")
end
win:GetItems().TrackIndexCombo.CurrentIndex = 0

win:GetItems().OutputModeCombo:AddItem("Save as SRT File")
win:GetItems().OutputModeCombo:AddItem("Apply to Subtitle Track 1")
win:GetItems().OutputModeCombo.CurrentIndex = 0

-- ==========================================
-- Main Conversion Logic
-- ==========================================
local function escapeSRTText(text)
    -- Remove rich text tags if any, very simple strip
    if not text then return "" end
    return text
end

local function convertTextPlusToSubtitle(sourceTrackIndex, outputModeIndex)
    local items = timeline:GetItemListInTrack("video", sourceTrackIndex)
    if not items or #items == 0 then
        print("Error: No clips found on Video Track " .. sourceTrackIndex .. ".")
        return
    end

    local frameRateStr = project:GetSetting("timelineFrameRate")
    local frameRate = tonumber(frameRateStr) or tonumber(project:GetSetting("timelinePlaybackFrameRate"))
    if not frameRate or frameRate == 0 then
        -- fallback
        frameRate = 24.0
    end
    print("Using Frame Rate: " .. frameRate)

    local timelineStartFrame = timeline:GetStartFrame()
    print("Timeline Start Frame: " .. timelineStartFrame)

    local srtContent = ""
    local srtIndex = 1

    for _, item in ipairs(items) do
        local compCount = item:GetFusionCompCount()
        if item:GetName() == "Text+" or compCount > 0 then
            local comp = item:GetFusionCompByIndex(1)
            if comp then
                -- Try to find Template tool
                local textTool = comp:GetToolList()[1]
                if not textTool then textTool = comp:FindTool("Template") end
                
                if textTool then
                    local text = textTool:GetInput("StyledText")
                    if text and text ~= "" then
                        local startFrame = item:GetStart()
                        local endFrame = item:GetEnd()
                        
                        -- If applying directly to the timeline, the imported SRT must be 0-based 
                        -- to avoid a double offset (timeline start + subtitle internal offset)
                        if outputModeIndex > 0 then
                            startFrame = startFrame - timelineStartFrame
                            endFrame = endFrame - timelineStartFrame
                            
                            if startFrame < 0 then startFrame = 0 end
                            if endFrame < 0 then endFrame = 0 end
                        end
                        
                        local startTimecode = formatTimecode(startFrame, frameRate)
                        local endTimecode = formatTimecode(endFrame, frameRate)

                        srtContent = srtContent .. srtIndex .. "\n"
                        srtContent = srtContent .. startTimecode .. " --> " .. endTimecode .. "\n"
                        srtContent = srtContent .. escapeSRTText(text) .. "\n\n"
                        
                        srtIndex = srtIndex + 1
                    end
                end
            end
        end
    end

    if srtContent == "" then
        print("Error: No valid Text+ content found on Video Track " .. sourceTrackIndex .. ".")
        return
    end

    -- Output Mode Handling
    if outputModeIndex == 0 then
        -- Mode 0: Save to File (Native Fusion Open/Save Dialog)
        local userProfile = os.getenv("USERPROFILE") or os.getenv("HOME")
        local defaultPath = userProfile .. "\\textplus_export.srt"
        
        -- Use DaVinci Resolve's native Fusion UI dialog
        local savePath = fu:RequestFile(defaultPath, "Save", {
            FReqS_Title = "Save SRT File",
            FReqS_Filter = "Subtitles (*.srt)|*.srt"
        })

        if savePath and savePath ~= "" then
            local f = io.open(savePath, "w")
            if f then
                f:write(srtContent)
                f:close()
                print("Successfully saved SRT to: " .. savePath)
            else
                print("Error: Could not write to file " .. savePath)
            end
        else
            print("Export cancelled by user.")
        end

    elseif outputModeIndex == 1 then
        -- Mode 1: Apply to Subtitle Track 1
        -- DaVinci Resolve caches imported files. We must use a unique filename every time.
        local uniqueStr = tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
        local tempPath = os.getenv("TEMP") .. "\\textplus_export_" .. uniqueStr .. ".srt"
        local f = io.open(tempPath, "w")
        if f then
            f:write(srtContent)
            f:close()
        else
            print("Error: Could not write temp SRT file.")
            return
        end

        -- Import Media
        local importedItems = mediaPool:ImportMedia({tempPath})

        -- Clean up temp file immediately after import
        os.remove(tempPath)

        if not importedItems or #importedItems == 0 then
            print("Error: Failed to import generated SRT file into Media Pool.")
            return
        end
        local newSrtClip = importedItems[1]

        -- Clear existing subtitles on Track 1
        local existingSubtitles = timeline:GetItemListInTrack("subtitle", 1)
        if existingSubtitles and #existingSubtitles > 0 then
            print("Clearing existing subtitles on Track 1...")
            timeline:DeleteClips(existingSubtitles, false)
        end

        -- Append new SRT clip
        -- Note: DaVinci Resolve's AppendToTimeline completely ignores trackIndex and recordFrame for subtitles.
        -- It ALWAYS appends to the currently *ACTIVE* subtitle track, at the *END* of its current clips.
        -- We cleared Track 1 above, so if Track 1 is active, it adds perfectly at 01:00:00:00.
        local result = mediaPool:AppendToTimeline({newSrtClip})

        if result and #result > 0 then
            print("Successfully requested subtitle append.")
            print("WARNING: DaVinci Resolve API always appends to the currently 'Active' Subtitle Track (usually Track 1) regardless of script parameters. If the clip landed at the wrong time/track, please manually delete it, explicitly click 'Subtitle 1' track header to make it active, and run again.")
        else
            print("Error: Failed to append SRT to timeline.")
        end
        
        -- Clean up: Remove the imported SRT clip from the Media Pool so we don't spam the user's bin
        pcall(function() mediaPool:DeleteClips({newSrtClip}) end)

    end
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
    local trackIndexCombo = win:GetItems().TrackIndexCombo
    local outputModeCombo = win:GetItems().OutputModeCombo
    
    local trackIndex = trackIndexCombo.CurrentIndex + 1
    local outputModeIndex = outputModeCombo.CurrentIndex
    
    disp:ExitLoop()
    convertTextPlusToSubtitle(trackIndex, outputModeIndex)
end

-- ==========================================
-- Run UI
-- ==========================================
win:Show()
disp:RunLoop()
win:Hide()
