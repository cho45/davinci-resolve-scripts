-- DaVinci Resolve Minimum Script
-- UI、ダイアログ、イベントループを一切含みません。
-- 100% 安全にコンソールへ出力するだけのコードです。

local resolve = Resolve()
local pm = resolve:GetProjectManager()
local proj = pm:GetCurrentProject()

print("\n[SUCCESS] Script connection verified.")
if proj then
    print("Working on Project: " .. proj:GetName())
else
    print("Resolve is open (No project loaded).")
end
print("No further actions being taken. Safe to continue.\n")
