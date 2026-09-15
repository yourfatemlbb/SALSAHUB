-- SALSAHUB V4. Self-contained; no web loader or external key.
-- This small outer runner reports compilation errors in the full script.
local player = game:GetService("Players").LocalPlayer
if not player then warn("SALSAHUB: LocalPlayer belum tersedia"); return end
local parent = player:WaitForChild("PlayerGui", 15)
if not parent then warn("SALSAHUB: PlayerGui belum tersedia"); return end
for _, name in ipairs({"SALSA_TEST", "SALSAHUB_RunStatus"}) do
    local old = parent:FindFirstChild(name)
    if old then old:Destroy() end
end
local gui = Instance.new("ScreenGui")
gui.Name = "SALSAHUB_RunStatus"
gui.ResetOnSpawn = false
gui.DisplayOrder = 2147483647
gui.Parent = parent
local panel = Instance.new("Frame")
panel.Size = UDim2.new(.85, 0, 0, 130)
panel.Position = UDim2.new(.075, 0, 0, 10)
panel.BackgroundColor3 = Color3.fromRGB(80, 30, 105)
panel.Parent = gui
local text = Instance.new("TextBox")
text.Size = UDim2.new(1, -20, 1, -45)
text.Position = UDim2.new(0, 10, 0, 5)
text.BackgroundTransparency = 1
text.TextColor3 = Color3.new(1, 1, 1)
text.TextSize = 15
text.TextWrapped = true
text.MultiLine = true
text.ClearTextOnFocus = false
text.TextXAlignment = Enum.TextXAlignment.Left
text.TextYAlignment = Enum.TextYAlignment.Top
text.Text = "SALSAHUB V4: kode mulai berjalan..."
text.Parent = panel
local copy = Instance.new("TextButton")
copy.Size = UDim2.new(.5, -15, 0, 30)
copy.Position = UDim2.new(0, 10, 1, -35)
copy.Text = "Salin pesan"
copy.Parent = panel
copy.Activated:Connect(function()
    if type(setclipboard) == "function" then pcall(setclipboard, text.Text)
    else text:CaptureFocus(); text.CursorPosition = #text.Text + 1; text.SelectionStart = 1 end
end)
local close = Instance.new("TextButton")
close.Size = UDim2.new(.5, -15, 0, 30)
close.Position = UDim2.new(.5, 5, 1, -35)
close.Text = "Tutup pesan"
close.Parent = panel
close.Activated:Connect(function() gui:Destroy() end)
local function report(value)
    warn("[SALSAHUB V4] " .. tostring(value))
    if gui.Parent then text.Text = tostring(value) end
end
local source = [====[
-- SALSAHUB startup revision 4.
-- If the script starts, a separate startup panel appears before the main UI.
local startupPanel, startupText
local uiParent, uiParentName
local uiRoots = {}
local function addRoot(root, label)
    if typeof(root) ~= "Instance" then return end
    for _, entry in ipairs(uiRoots) do if entry.root == root then return end end
    table.insert(uiRoots, {root=root, label=label})
end
local function chooseUIParent(playerGui)
    -- PlayerGui visibility was confirmed by the user in this game.
    addRoot(playerGui, "PlayerGui")
    if type(gethui) == "function" then
        local ok, root = pcall(gethui)
        if ok then addRoot(root, "gethui") end
    end
    local ok, core = pcall(function() return game:GetService("CoreGui") end)
    if ok then addRoot(core, "CoreGui") end
    addRoot(playerGui, "PlayerGui")
    for _, entry in ipairs(uiRoots) do
        local probe = Instance.new("ScreenGui")
        local supported = pcall(function()
            probe.Name = "SALSAHUB_ParentTest"
            probe.Enabled = false
            probe.Parent = entry.root
        end)
        probe:Destroy()
        if supported then return entry.root, entry.label end
    end
    error("Tidak ada tempat GUI yang dapat dipakai")
end
local phase = "Mulai"
local function startupPhase(value)
    phase=tostring(value)
    print("[SALSAHUB] "..phase)
    if startupText and startupText.Parent then startupText.Text=phase end
end
local function startupHide()
    if startupPanel then startupPanel.Enabled=false end
end
local function startupReport(message)
    local value="SALSAHUB ERROR\nTahap: "..phase.."\n"..tostring(message)
    warn(value)
    if startupText and startupText.Parent then
        startupPanel.Enabled=true
        startupText.Text=value
    end
end
local bootOK,bootError=pcall(function()
    local players=game:GetService("Players")
    local p=players.LocalPlayer
    if not p then
        local deadline=os.clock()+10
        repeat task.wait(.1); p=players.LocalPlayer until p or os.clock()>=deadline
    end
    assert(p,"LocalPlayer belum tersedia")
    local playerGui=p:WaitForChild("PlayerGui",15)
    assert(playerGui,"PlayerGui belum tersedia")
    uiParent,uiParentName=chooseUIParent(playerGui)
    local parent=uiParent
    for _,entry in ipairs(uiRoots) do
        pcall(function()
            local old=entry.root:FindFirstChild("SALSAHUB_Startup")
            if old then old:Destroy() end
        end)
    end
    local screen=Instance.new("ScreenGui")
    screen.Name="SALSAHUB_Startup"
    screen.ResetOnSpawn=false
    screen.DisplayOrder=2147483646
    screen.Parent=parent
    startupPanel=screen
    local panel=Instance.new("Frame")
    panel.Size=UDim2.new(.85,0,.55,0)
    panel.Position=UDim2.new(.075,0,.225,0)
    panel.BackgroundColor3=Color3.fromRGB(30,23,40)
    panel.Parent=screen
    local box=Instance.new("TextBox")
    box.Size=UDim2.new(1,-20,1,-55)
    box.Position=UDim2.new(0,10,0,10)
    box.BackgroundTransparency=1
    box.TextColor3=Color3.new(1,1,1)
    box.TextSize=14
    box.Font=Enum.Font.Code
    box.TextWrapped=true
    box.MultiLine=true
    box.ClearTextOnFocus=false
    box.TextXAlignment=Enum.TextXAlignment.Left
    box.TextYAlignment=Enum.TextYAlignment.Top
    box.Text="SALSAHUB dimulai..."
    box.Parent=panel
    startupText=box
    local copy=Instance.new("TextButton")
    copy.Size=UDim2.new(.65,-15,0,30)
    copy.Position=UDim2.new(0,10,1,-37)
    copy.Text="Salin pesan"
    copy.Parent=panel
    copy.Activated:Connect(function()
        if type(setclipboard)=="function" then pcall(setclipboard,box.Text)
        else box:CaptureFocus(); box.CursorPosition=#box.Text+1; box.SelectionStart=1 end
    end)
    local close=Instance.new("TextButton")
    close.Size=UDim2.new(.35,-15,0,30)
    close.Position=UDim2.new(.65,5,1,-37)
    close.Text="Tutup"
    close.Parent=panel
    close.Activated:Connect(function() screen.Enabled=false end)
end)
if not bootOK then
    startupReport(bootError)
    return
end
local ok,err=xpcall(function()
-- SALSAHUB | Anime Dice -- first integrated build, executor runtime untested.
-- Based on user-supplied RollController, AutoSellController, PlotController,
-- UpgradeController and UnitUtil. Uses their Network client wrappers.
-- Does not bypass server roll limits. Money/s selling is intentionally unavailable
-- until the sale signature and income/lock semantics are established.
-- Equip Best uses the game's existing GUI handler (requires firesignal).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Input = game:GetService("UserInputService")
local LP = Players.LocalPlayer
assert(LP, "Jalankan di client")
local PG = LP:WaitForChild("PlayerGui", 15)
assert(PG, "PlayerGui belum tersedia")
for _,entry in ipairs(uiRoots) do
    for _,name in ipairs({"SALSAHUB", "HybridHub", "SALSAHUB_Addons"}) do
        pcall(function()
            local old=entry.root:FindFirstChild(name)
            if old then
                local stop=old:FindFirstChild("Unload")
                if stop and stop:IsA("BindableEvent") then stop:Fire() else old:Destroy() end
            end
        end)
    end
end
local alive, ready = true, false
local connections, toggles, pending = {}, {}, nil
local state = {Roll=false, Rarity=false, Equip=false, Upgrade=false, Level=false}
local config = {RollDelay=0.75, RarityLimit=0, Reserve=0, MaxLevel=50, EquipDelay=10}
local api = {}
local nativeRollBefore, rarityBefore, lastRaritySent
local nativeRollChanged = false
local initWorker, rollWorker, spendWorker, equipWorker
local logs = {"Build V4 | GUI parent: "..uiParentName}
local function on(signal, fn)
    local c=signal:Connect(fn); table.insert(connections,c); return c
end
local function make(class, props, parent)
    local o=Instance.new(class)
    for k,v in pairs(props) do o[k]=v end
    o.Parent=parent
    return o
end
local colors={bg=Color3.fromRGB(24,21,32), card=Color3.fromRGB(40,34,52),
    accent=Color3.fromRGB(173,111,225), text=Color3.fromRGB(247,240,255), muted=Color3.fromRGB(186,175,202)}
startupPhase("Membuat menu SALSAHUB melalui "..uiParentName)
local gui=make("ScreenGui",{Name="SALSAHUB",ResetOnSpawn=false,Enabled=true,DisplayOrder=2147483645,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},uiParent)
local stopEvent=make("BindableEvent",{Name="Unload"},gui)
local frame=make("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
    Size=UDim2.fromOffset(350,360),BackgroundColor3=colors.bg,BorderSizePixel=0},gui)
make("UICorner",{CornerRadius=UDim.new(0,14)},frame)
local scale=make("UIScale",{Scale=1},frame)
local function resize()
    local camera=workspace.CurrentCamera
    local size=camera and camera.ViewportSize or Vector2.new(800,600)
    if size.X>20 and size.Y>20 then scale.Scale=math.clamp(math.min((size.X-20)/350,(size.Y-20)/360),.1,1) end
end
on(workspace:GetPropertyChangedSignal("CurrentCamera"),resize)
local resizeCamera=workspace.CurrentCamera
if resizeCamera then on(resizeCamera:GetPropertyChangedSignal("ViewportSize"),resize) end
resize()
local function text(class,label,parent,pos,size)
    local o=make(class,{Text=label,Position=pos,Size=size,Font=Enum.Font.GothamMedium,TextSize=13,
        TextColor3=colors.text,BackgroundColor3=colors.card,BorderSizePixel=0},parent)
    make("UICorner",{CornerRadius=UDim.new(0,7)},o)
    return o
end
local title=text("TextLabel","SALSAHUB V4  /  ANIME DICE",frame,UDim2.fromOffset(12,10),UDim2.fromOffset(280,32))
title.Font=Enum.Font.GothamBold; title.Active=true
local mini=text("TextButton","−",frame,UDim2.fromOffset(303,10),UDim2.fromOffset(35,32))
local status=text("TextLabel","Menyiapkan modul...",frame,UDim2.fromOffset(12,294),UDim2.fromOffset(326,25))
status.TextSize=11; status.TextTruncate=Enum.TextTruncate.AtEnd
local stopButton=text("TextButton","STOP SEMUA",frame,UDim2.fromOffset(12,325),UDim2.fromOffset(158,25))
local unloadButton=text("TextButton","UNLOAD",frame,UDim2.fromOffset(180,325),UDim2.fromOffset(158,25))
local function log(message)
    message=tostring(message)
    table.insert(logs,os.date("%H:%M:%S").." | "..message)
    if #logs>50 then table.remove(logs,1) end
    if alive then status.Text=message end
end
local pages, tabs = {}, {}
for i,name in ipairs({"Otomatis", "Pengaturan", "Diagnostik"}) do
    local tab=text("TextButton",name,frame,UDim2.fromOffset(12+(i-1)*111,49),UDim2.fromOffset(104,29))
    tabs[name]=tab
    local page=make("ScrollingFrame",{Position=UDim2.fromOffset(12,87),Size=UDim2.fromOffset(326,198),
        CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3,
        BackgroundTransparency=1,BorderSizePixel=0,Visible=i==1},frame)
    make("UIListLayout",{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder},page)
    pages[name]=page
    tab.BackgroundColor3=i==1 and colors.accent or colors.card
    on(tab.Activated,function()
        for n,p in pairs(pages) do p.Visible=n==name; tabs[n].BackgroundColor3=n==name and colors.accent or colors.card end
    end)
end
local function note(page,label,height)
    local o=text("TextLabel",label,page,UDim2.new(),UDim2.new(1,-7,0,height or 42))
    o.TextWrapped=true; o.TextSize=11; o.TextColor3=colors.muted
    return o
end
local function repaint(key)
    local b=toggles[key]
    if b then
        b.button.Text=b.label..": "..(state[key] and "ON" or "OFF")
        b.button.BackgroundColor3=state[key] and colors.accent or colors.card
    end
end
local function disable(key,message)
    state[key]=false; repaint(key)
    if message then log(message) end
end
local function safeNumber(value)
    return type(value)=="number" and value==value and math.abs(value)~=math.huge
end
local function restoreRarity()
    if rarityBefore==nil then return end
    local old=rarityBefore
    rarityBefore=nil
    -- Do not overwrite a newer setting changed from the game's own menu.
    if api.Data.AutoSell()==lastRaritySent then api.AutoSell:Fire(old) end
    lastRaritySent=nil
end
local function restoreRoll()
    if not nativeRollChanged then return end
    nativeRollChanged=false
    if api.Data.AutoRoll()==false then api.NativeAutoRoll:Fire(nativeRollBefore) end
end
local function toggle(key)
    if not ready then log("Modul belum siap; lihat status"); return end
    if key=="Roll" and not state.Roll then
        if not nativeRollChanged then nativeRollBefore=api.Data.AutoRoll() end
        if type(nativeRollBefore)~="boolean" then error("Data AutoRoll belum siap") end
        nativeRollChanged=true
        api.NativeAutoRoll:Fire(false)
        state.Roll=true
        log("Roll ON; menunggu auto-roll bawaan berhenti")
    elseif key=="Roll" then
        state.Roll=false
        -- Restoration is handled by the single roll worker, after any RPC finishes.
        log("Roll OFF; permintaan yang sudah terkirim bisa tetap selesai")
    elseif key=="Rarity" and not state.Rarity then
        if config.RarityLimit<=0 then log("Isi batas 1 in X di Pengaturan dahulu"); return end
        rarityBefore=api.Data.AutoSell()
        if not safeNumber(rarityBefore) then rarityBefore=nil; error("Data AutoSell belum siap") end
        lastRaritySent=config.RarityLimit
        api.AutoSell:Fire(lastRaritySent)
        state.Rarity=true
        log("Auto-sell bawaan: batas 1 in "..lastRaritySent.." (server belum dikonfirmasi)")
    elseif key=="Rarity" then
        state.Rarity=false; restoreRarity(); log("Auto-sell: pengaturan sebelumnya dipulihkan jika masih cocok")
    elseif key=="Equip" and not state.Equip and type(firesignal)~="function" then
        log("Auto Equip belum tersedia: firesignal tidak didukung"); return
    else
        state[key]=not state[key]
        log(key..(state[key] and " ON" or " OFF"))
    end
    repaint(key)
end
for _,entry in ipairs({{"Roll","Auto Roll / tanpa animasi"},{"Rarity","Auto Sell / kelangkaan"},
    {"Equip","Auto Equip Best"},{"Upgrade","Auto Upgrade Tree"},{"Level","Auto Level Unit Base"}}) do
    local key,label=entry[1],entry[2]
    local b=text("TextButton","",pages.Otomatis,UDim2.new(),UDim2.new(1,-7,0,36))
    toggles[key]={button=b,label=label}; repaint(key)
    on(b.Activated,function()
        local ok,err=pcall(toggle,key)
        if not ok then disable(key,"Error "..key..": "..tostring(err)) end
    end)
end
note(pages.Otomatis,"Auto Sell money/s: BELUM TERSEDIA. Perlu SellController dan UnitConfig.",44)
note(pages.Otomatis,"Upgrade memakai saldo game. Semua fitur OFF saat dibuka. Kelangkaan memakai batas 1 in X, bukan nama tier.",47)
for _,entry in ipairs({{"RollDelay","Jeda percobaan roll (detik)",.25,30},
    {"RarityLimit","Jual di bawah 1 in X",0,1e18},{"Reserve","Saldo minimum disisakan",0,1e18},
    {"MaxLevel","Batas level unit",1,100000},{"EquipDelay","Jeda Equip Best (detik)",5,120}}) do
    local key,label,low,high=entry[1],entry[2],entry[3],entry[4]
    local row=make("Frame",{Size=UDim2.new(1,-7,0,39),BackgroundTransparency=1},pages.Pengaturan)
    local caption=text("TextLabel",label,row,UDim2.new(),UDim2.new(.65,0,1,0)); caption.TextSize=11
    local box=text("TextBox",tostring(config[key]),row,UDim2.new(.67,0,0,0),UDim2.new(.33,0,1,0))
    box.ClearTextOnFocus=false
    on(box.FocusLost,function()
        local n=tonumber(box.Text)
        if not safeNumber(n) then log("Gunakan angka penuh, contoh 1000000")
        elseif key=="RarityLimit" and state.Rarity then log("Matikan Auto Sell dahulu sebelum mengubah batas")
        else
            config[key]=math.clamp(n,low,high)
            if key=="MaxLevel" then config[key]=math.floor(config[key]) end
        end
        box.Text=tostring(config[key])
    end)
end
note(pages.Pengaturan,"Jeda lebih kecil tidak menjamin roll diterima lebih cepat. Saat dua upgrade aktif, pembelian bergantian dan menunggu pembaruan data.",51)
local function copyText(value)
    if type(setclipboard)~="function" then log("Clipboard tidak tersedia"); return end
    local ok,err=pcall(setclipboard,value)
    log(ok and "Tersalin; tempel hasilnya ke chat" or tostring(err))
end
local copyLog=text("TextButton","Salin log",pages.Diagnostik,UDim2.new(),UDim2.new(1,-7,0,34))
on(copyLog.Activated,function() copyText(table.concat(logs,"\n")) end)
local reading=false
for _,relative in ipairs({"Selling.SellController","Inventory.BackpackController","Inventory.Kinds.Unit.UnitConfig"}) do
    local path=relative
    local b=text("TextButton","Salin "..path:match("[^.]+$"),pages.Diagnostik,UDim2.new(),UDim2.new(1,-7,0,34))
    on(b.Activated,function()
        if reading then log("Masih membaca controller sebelumnya"); return end
        if type(decompile)~="function" then log("Decompiler tidak tersedia"); return end
        reading=true
        log("Membaca "..path)
        task.spawn(function()
            local ok,result=pcall(function()
                local module=RS.Framework.Features
                for name in path:gmatch("[^.]+") do module=assert(module:FindFirstChild(name),name.." tidak ditemukan") end
                return decompile(module)
            end)
            reading=false
            if not alive then return end
            if ok and type(result)=="string" then copyText("-- "..path.."\n"..result) else log("Gagal membaca: "..tostring(result)) end
        end)
    end)
end
note(pages.Diagnostik,"Controller tambahan diperlukan untuk money/s dan verifikasi Equip Best. Tidak dijalankan oleh tombol Salin.",48)

-- Candidate selection follows the exported client controllers.
local function upgradeCandidate()
    local seen={}
    local best
    local funds=api.Data.Money()-config.Reserve
    local function walk(parent)
        if seen[parent] then return end
        seen[parent]=true
        for _,name in pairs(api.Tree.GetChildren(parent)) do
            if api.Data.Upgrades[name]() then walk(name)
            else
                local item=api.Upgrades[name]
                local cost=item and item.price
                if safeNumber(cost) and cost>=0 and cost<=funds then
                    if not best or cost<best.cost or (cost==best.cost and tostring(name)<tostring(best.name)) then
                        best={kind="Upgrade",name=name,cost=cost}
                    end
                end
            end
        end
    end
    walk("Start")
    return best
end
local function levelCandidate()
    local plot=api.Plot.plot
    if not plot then return nil end
    local slots=plot:FindFirstChild("Slots")
    local roots={}
    if slots then table.insert(roots,slots) end
    -- PlotController moves distant slots into a folder under its ModuleScript.
    local hidden=api.PlotModule:FindFirstChild(plot.Name)
    if hidden then table.insert(roots,hidden) end
    local funds=api.Data.Money()-config.Reserve
    local best
    for _,root in ipairs(roots) do
        for _,model in ipairs(root:GetChildren()) do
            local slot=tonumber(model.Name)
            if model:IsA("Model") and slot and api.Data.Rebirth()>=api.PlotConfig.GetSlotRebirthRequirement(slot) then
                local s=api.Data.Slots[tostring(slot)]()
                local unit=s and s.unitId and api.Data.Inventory[s.unitId]()
                if unit and unit.attributes then
                    local level=unit.attributes.level or 1
                    local cost=api.UnitUtil.GetLevelPrice(unit.name,unit.attributes)
                    if safeNumber(cost) and cost>=0 and cost<=funds and level<config.MaxLevel then
                        if not best or cost<best.cost or (cost==best.cost and slot<best.slot) then
                            best={kind="Level",slot=slot,unitId=s.unitId,level=level,cost=cost}
                        end
                    end
                end
            end
        end
    end
    return best
end
local function acknowledged(action)
    if action.kind=="Upgrade" then return api.Data.Upgrades[action.name]()==true end
    local unit=api.Data.Inventory[action.unitId]()
    return unit and unit.attributes and (unit.attributes.level or 1)>action.level
end
local function stopAll()
    for key in pairs(state) do state[key]=false; repaint(key) end
    local ok,err=pcall(restoreRarity)
    if not ok then log("Pemulihan auto-sell gagal: "..tostring(err)) end
    log("Semua OFF; aksi yang sudah terkirim tidak bisa ditarik")
end
on(stopButton.Activated,stopAll)
local function unload()
    if not alive then return end
    stopAll()
    -- No new roll requests after this point. A request already sent may finish.
    pcall(restoreRoll)
    alive=false
    for _,c in ipairs(connections) do c:Disconnect() end
    gui:Destroy()
    if startupPanel then startupPanel:Destroy() end
end
on(stopEvent.Event,unload)
on(unloadButton.Activated,unload)
on(gui.Destroying,unload)
local collapsed=false
local activePage="Otomatis"
on(mini.Activated,function()
    collapsed=not collapsed
    if collapsed then for n,p in pairs(pages) do if p.Visible then activePage=n end end end
    for n,p in pairs(pages) do p.Visible=not collapsed and n==activePage end
    for _,b in pairs(tabs) do b.Visible=not collapsed end
    status.Visible=not collapsed; stopButton.Visible=not collapsed; unloadButton.Visible=not collapsed
    frame.Size=UDim2.fromOffset(350,collapsed and 52 or 360)
    mini.Text=collapsed and "+" or "−"
end)
local drag,start,origin
on(title.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
        drag=input; start=input.Position; origin=frame.Position
    end
end)
on(Input.InputChanged,function(input)
    if not drag then return end
    local mouse=drag.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement
    if input~=drag and not mouse then return end
    local delta=input.Position-start
    local size=gui.AbsoluteSize
    local half=frame.AbsoluteSize*.5
    local x=origin.X.Scale*size.X+origin.X.Offset+delta.X
    local y=origin.Y.Scale*size.Y+origin.Y.Offset+delta.Y
    frame.Position=UDim2.fromOffset(math.clamp(x,half.X,math.max(half.X,size.X-half.X)),
        math.clamp(y,half.Y,math.max(half.Y,size.Y-half.Y)))
end)
on(Input.InputEnded,function(input) if input==drag then drag=nil end end)

startupPhase("Menu dibuat; menghubungkan modul")
startupHide()
if game.GameId ~= 10708913337 and game.PlaceId ~= 113290951185459 then
    log("Map tidak cocok. PlaceId: "..game.PlaceId.." | GameId: "..game.GameId)
    return
end
local loadingModule="Framework"
local function loadModule(module, label)
    loadingModule=label
    log("Memuat "..label.."...")
    return require(module)
end
task.delay(15,function()
    if alive and not ready then
        log("Belum siap: "..loadingModule..". Gunakan Diagnostik > Salin log.")
    end
end)
initWorker=task.spawn(function()
    local ok,err=pcall(function()
        local F=RS.Framework.Features
        api.Data=loadModule(F.Data.DataController,"DataController")
        api.Tree=loadModule(F.Upgrades.TreeStructure,"TreeStructure")
        api.Upgrades=loadModule(F.Upgrades.Upgrades,"Upgrades")
        api.PlotModule=F.Plot.PlotController
        api.Plot=loadModule(api.PlotModule,"PlotController")
        api.PlotConfig=loadModule(F.Plot.PlotConfig,"PlotConfig")
        api.UnitUtil=loadModule(F.Inventory.Kinds.Unit.UnitUtil,"UnitUtil")
        local Network=loadModule(RS.Packages.Network,"Network")
        local roll=Network.ClientComm.new(RS.Network,false,"RollService")
        local sell=Network.ClientComm.new(RS.Network,false,"SellService")
        local plot=Network.ClientComm.new(RS.Network,false,"PlotService")
        api.RollDice=roll:GetFunction("RollDice")
        api.NativeAutoRoll=roll:GetSignal("SetAutoRoll")
        api.AutoSell=sell:GetSignal("UpdateAutoSell")
        api.LevelUp=plot:GetSignal("LevelUpSlot")
        api.BuyUpgrade=Network.Client.GetSignal(RS.Network,"BuyUpgrade")
        assert(safeNumber(api.Data.Money()),"Data uang belum siap")
    end)
    if not alive then return end
    if not ok then log("Inisialisasi gagal: "..tostring(err)); return end
    ready=true
    log("Siap. Semua fitur OFF; atur batas sebelum mengaktifkan.")
    rollWorker=task.spawn(function()
        local waitSince=nil
        while alive do
            if state.Roll then
                local success,result=pcall(function()
                    if api.Data.AutoRoll() then
                        waitSince=waitSince or os.clock()
                        if os.clock()-waitSince>4 then error("Auto-roll bawaan belum OFF; matikan dari menu game") end
                        return nil
                    end
                    waitSince=nil
                    -- Allow a native animation already in progress to finish.
                    local root=PG:FindFirstChild("Root")
                    local rolling=root and root:FindFirstChild("Rolling")
                    local rf=rolling and rolling:FindFirstChild("Frame")
                    local template=rf and rf:FindFirstChild("RollTemplate")
                    if rf then
                        for _,child in ipairs(rf:GetChildren()) do
                            if child~=template and child.Name=="RollTemplate" then return nil end
                        end
                    end
                    return api.RollDice()
                end)
                if not success then disable("Roll","Roll dihentikan: "..tostring(result)) end
                task.wait(config.RollDelay)
            else
                waitSince=nil
                local success,result=pcall(restoreRoll)
                if not success then log("Pemulihan AutoRoll gagal: "..tostring(result)) end
                task.wait(.2)
            end
        end
    end)
    spendWorker=task.spawn(function()
        local lastKind="Level"
        while alive do
            if pending then
                local ok,done=pcall(acknowledged,pending)
                if ok and done then log(pending.kind.." terkonfirmasi"); pending=nil
                elseif not ok or os.clock()-pending.sent>5 then
                    disable(pending.kind,"Upgrade belum terkonfirmasi; fitur dihentikan")
                    pending=nil
                end
            elseif state.Upgrade or state.Level then
                local ok,action=pcall(function()
                    local first=lastKind=="Level" and "Upgrade" or "Level"
                    local second=first=="Upgrade" and "Level" or "Upgrade"
                    for _,kind in ipairs({first,second}) do
                        if state[kind] then
                            local candidate=kind=="Upgrade" and upgradeCandidate() or nil
                            if kind=="Level" then candidate=levelCandidate() end
                            if candidate then return candidate end
                        end
                    end
                end)
                if not ok then
                    disable("Upgrade"); disable("Level","Pemeriksaan upgrade gagal: "..tostring(action))
                elseif action and state[action.kind] then
                    -- One shared pending action prevents spending the same balance twice.
                    local sent,errorMessage=pcall(function()
                        if action.kind=="Upgrade" then api.BuyUpgrade:Fire(action.name)
                        else api.LevelUp:Fire(action.slot) end
                    end)
                    if sent then action.sent=os.clock(); pending=action; lastKind=action.kind
                        log("Menunggu "..action.kind..": "..tostring(action.name or action.slot))
                    else disable(action.kind,tostring(errorMessage)) end
                end
            end
            task.wait(.5)
        end
    end)
    equipWorker=task.spawn(function()
        local nextEquip=0
        while alive do
            if state.Equip and not pending and os.clock()>=nextEquip then
                nextEquip=os.clock()+config.EquipDelay
                local success,errorMessage=pcall(function()
                    local b=PG.Root.Menus.Backpack.Units.Actions.EquipBest
                    assert(b:IsA("GuiButton"),"Tombol Equip Best tidak ditemukan")
                    assert(type(firesignal)=="function","firesignal tidak didukung")
                    firesignal(b.Activated)
                end)
                if not success then disable("Equip",tostring(errorMessage))
                else log("Equip Best: handler tombol dipanggil; hasil belum diverifikasi") end
            end
            task.wait(.5)
        end
    end)
end)

end, function(message)
    if debug and type(debug.traceback)=="function" then return debug.traceback(tostring(message),2) end
    return tostring(message)
end)
if not ok then startupReport(err) end
-- SALSAHUB_PAYLOAD_END_V4: copy the script through this final line.

]====]
if type(loadstring) ~= "function" then
    report("SALSAHUB V4: loadstring tidak tersedia di lingkungan ini")
    return
end
local callOK, compiled, compileError = pcall(loadstring, source, "SALSAHUB_AnimeDice_V4")
if not callOK then
    report("COMPILER ERROR: " .. tostring(compiled))
elseif type(compiled) ~= "function" then
    report("SYNTAX ERROR: " .. tostring(compileError))
else
    report("Kompilasi berhasil: " .. #source .. " byte. Menjalankan menu...")
    local runOK, runError = pcall(compiled)
    if not runOK then
        report("RUNTIME ERROR: " .. tostring(runError))
    else
        local startup = parent:FindFirstChild("SALSAHUB_Startup")
        if startup and startup.Enabled then
            report("Lihat panel SALSAHUB ERROR di tengah layar. Salin pesan dari panel itu.")
        elseif parent:FindFirstChild("SALSAHUB") then
            report("Menu SALSAHUB V4 dibuat. Tutup pesan ini untuk melihat menu.")
        else
            report("Kode selesai tetapi menu belum ditemukan. Kirim screenshot pesan ini.")
        end
    end
end
-- SALSAHUB_END_V4
