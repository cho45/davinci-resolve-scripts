local resolve = Resolve()
local fusion = resolve:Fusion()
local ui = fusion.UIManager
local dispatcher = bmd.UIDispatcher(ui)

local winID = "HelloWorldDialog"

-- ウィンドウの定義
local win = dispatcher:AddWindow({
    ID = winID,
    WindowTitle = "Hello World",
    Geometry = { 200, 200, 300, 150 },
}, ui:VGroup{
    ui:Label{
        ID = "MessageLabel",
        Text = "Hello, world!",
        Alignment = { AlignHCenter = true, AlignVCenter = true },
    },
    ui:HGroup{
        Weight = 0,
        ui:HGap(0, 1),
        ui:Button{
            ID = "CloseBtn",
            Text = "Close",
            Weight = 0,
        },
        ui:HGap(0, 1),
    },
})

-- UIアイテムの取得（イベントバインドに必要）
local itm = win:GetItems()

-- イベントハンドラー
win.On[winID].Close = function(ev)
    dispatcher:ExitLoop()
end

win.On.CloseBtn.Clicked = function(ev)
    dispatcher:ExitLoop()
end

-- UIの表示とループ実行
win:Show()
dispatcher:RunLoop()
win:Hide()

