local resolve = Resolve()
local pm = resolve:GetProjectManager()
local proj = pm:GetCurrentProject()

local fusion = resolve:Fusion()
local ui = fusion.UIManager
local dispatcher = bmd.UIDispatcher(ui)

local winID = "YouTubeChapterGenerator"

local win = dispatcher:AddWindow({
    ID = winID,
    WindowTitle = "YouTube Chapter Generator",
    Geometry = { 200, 200, 500, 400 },
}, ui:VGroup{
    ui:HGroup{
        Weight = 0,
        ui:Label{ Text = "Marker Color: ", Weight = 0 },
        ui:ComboBox{ ID = "ColorCombo" },
    },
    ui:VGap(5),
    ui:Label{ Text = "Generated Chapters:", Weight = 0 },
    ui:TextEdit{
        ID = "ResultText",
        ReadOnly = true,
        Font = ui:Font{ Family = "Consolas", PixelSize = 13 }
    },
    ui:VGap(5),
    ui:HGroup{
        Weight = 0,
        ui:HGap(0, 1),
        ui:Button{ ID = "GenerateBtn", Text = "生成してコピー (Generate & Copy)", Weight = 0, MinimumSize = {200, 30} },
        ui:HGap(0, 5),
        ui:Button{ ID = "CloseBtn", Text = "閉じる", Weight = 0, MinimumSize = {100, 30} },
        ui:HGap(0, 1),
    }
})

local itm = win:GetItems()

-- Define marker colors
local colors = {
    "All", "Blue", "Cyan", "Green", "Yellow", "Red", "Pink", "Purple",
    "Fuchsia", "Rose", "Lavender", "Sky", "Mint", "Lemon", "Sand", "Cocoa", "Cream"
}

for i, color in ipairs(colors) do
    itm.ColorCombo:AddItem(color)
end

-- Func to copy string to clipboard using Fusion's native UI dispatcher toolkit
local function copyToClipboard(text)
    -- bmd.setclipboard() is the native way to copy to clipboard in Resolve's Lua API
    bmd.setclipboard(text)
end

-- Event Handlers
win.On.CloseBtn.Clicked = function(ev)
    dispatcher:ExitLoop()
end

win.On[winID].Close = function(ev)
    dispatcher:ExitLoop()
end

win.On.GenerateBtn.Clicked = function(ev)
    if not proj then
        itm.ResultText.PlainText = "プロジェクトが開かれていません。"
        return
    end

    local timeline = proj:GetCurrentTimeline()
    if not timeline then
        itm.ResultText.PlainText = "タイムラインが開かれていません。"
        return
    end

    -- Get frame rate
    local frameRateStr = timeline:GetSetting("timelineFrameRate")
    print("[YouTube Chapter Generator] Retrieved timelineFrameRate: '" .. tostring(frameRateStr) .. "'")

    local fps = tonumber(frameRateStr)
    if not fps then
        print("[YouTube Chapter Generator] Direct conversion failed. Parsing DF/NDF strings...")
        local cleanedStr = string.gsub(frameRateStr, " DF", "")
        cleanedStr = string.gsub(cleanedStr, " NDF", "")
        fps = tonumber(cleanedStr)
        print("[YouTube Chapter Generator] Parsed frameRate (fallback parsing path): " .. tostring(fps))
    else
        print("[YouTube Chapter Generator] Parsed frameRate (direct conversion path): " .. tostring(fps))
    end

    if not fps or fps == 0 then
        local errMsg = "エラー: フレームレートが取得・解析できませんでした (" .. tostring(frameRateStr) .. ")"
        print(errMsg)
        itm.ResultText.PlainText = errMsg
        return
    end

    local markers = timeline:GetMarkers()
    if not markers then
        itm.ResultText.PlainText = "マーカーが見つかりませんでした。"
        return
    end

    local targetColorIndex = itm.ColorCombo.CurrentIndex
    local targetColor = colors[(targetColorIndex or 0) + 1]

    local c = {}
    local hasHourMarker = false

    -- 1st pass: フィルタリングと秒数計算、最大時間の確認
    for frameId, v in pairs(markers) do
        if targetColor == "All" or v.color == targetColor then
            local sec = math.floor(frameId / fps + 0.5)
            if sec >= 3600 then
                hasHourMarker = true
            end

            c[#c + 1] = {
                frame = tonumber(frameId),
                sec = sec,
                name = v.name
            }
        end
    end

    if #c == 0 then
        itm.ResultText.PlainText = "指定された色のマーカーが見つかりませんでした。"
        return
    end

    -- 順序をフレームIDでソートする
    table.sort(c, function(a, b) return a.frame < b.frame end)

    local result = {}
    local zeroAdded = false

    -- 2nd pass: 文字列のフォーマット
    for i, v in ipairs(c) do
        local h = math.floor(v.sec / 3600)
        local min = math.floor((v.sec % 3600) / 60)
        local s = v.sec % 60

        local timeStr
        if hasHourMarker then
            timeStr = string.format("%d:%02d:%02d", h, min, s)
        else
            timeStr = string.format("%02d:%02d", min, s)
        end

        if timeStr == "00:00" or timeStr == "0:00:00" then
            zeroAdded = true
        end

        local name = v.name
        if name == nil or name == "" then
            name = "Chapter " .. tostring(i)
        end

        table.insert(result, timeStr .. " " .. name)
    end

    -- YouTube requires at least one timestamp at exactly 00:00
    if not zeroAdded then
        local startFormat = hasHourMarker and "0:00:00 Start" or "00:00 Start"
        -- 既にある場合は置き換えではなく先頭に挿入
        table.insert(result, 1, startFormat)
    end

    local finalStr = table.concat(result, "\n")
    itm.ResultText.PlainText = finalStr
    
    -- Copy to clipboard
    bmd.setclipboard(finalStr)
end

win:Show()
dispatcher:RunLoop()
win:Hide()
