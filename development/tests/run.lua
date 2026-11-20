-- Runtime simulation, not a substitute for the Forever client's secret-value UI.
local ns, allFrames, now, combat = {}, {}, 0, false
local assertions = 0
local function eq(actual, expected, label)
    assertions = assertions + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local methods = {}
local function Object(kind, parent)
    local f = {kind = kind, parent = parent, shown = true, scripts = {}, width = 1, height = 1, points = {}}
    setmetatable(f, {__index = methods})
    allFrames[#allFrames + 1] = f
    return f
end
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetCenter() return self.x or 0, self.y or 0 end
function methods:GetEffectiveScale() return 1 end
function methods:GetFontString() self.fontString=self.fontString or Object("FontString", self); return self.fontString end
function methods:SetPoint(...) self.points[#self.points + 1] = {...} end
function methods:ClearAllPoints() self.points = {} end
function methods:SetAllPoints() end
function methods:SetShown(v) self.shown=v end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:IsShown() return self.shown end
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:SetFrameStrata(v) self.strata=v end
function methods:SetToplevel(v) self.toplevel=v end
function methods:LockHighlight() self.highlight=true end
function methods:UnlockHighlight() self.highlight=false end
function methods:HookScript(k,v) local old=self.scripts[k]; self.scripts[k]=old and function(...) old(...); v(...) end or v end
function methods:RegisterEvent(e) self.events=self.events or {}; self.events[e]=true end
function methods:SetText(v) self.text=v end
function methods:GetText() return self.text or "" end
function methods:SetChecked(v) self.checked=v end
function methods:GetChecked() return self.checked end
function methods:SetMinMaxValues(lo,hi) self.lo,self.hi=lo,hi end
function methods:GetMinMaxValues() return self.lo,self.hi end
function methods:GetValue() return self.value end
function methods:SetAlpha(a) self.alpha=a end
function methods:SetAlphaFromBoolean(v) self.alpha=v and 1 or 0 end
function methods:SetStatusBarColor(r,g,b,a) self.color={r,g,b,a} end
function methods:SetValue(v) self.value=v; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v) end end
function methods:SetFont(path,size) self.fontPath,self.fontSize=path,size end
function methods:GetFrameLevel() return self.level or 1 end
function methods:SetFrameLevel(v) self.level=v end
function methods:CreateTexture() return Object("Texture",self) end
function methods:CreateFontString() return Object("FontString",self) end
function methods:SetIcon(icon) self.icon=icon end
function methods:SetSpellName(label) self.label=label end
function methods:SetDurationText(text) self.time=text end
function methods:SetDurationBar(bar, options) self.bar=bar; self.timerOptions=options end
function methods:SetTimerDuration(duration, interpolation, direction)
    self.duration=duration; self.direction=direction
    self:SetMinMaxValues(0,duration.total)
    self:SetValue(duration.expires-now)
end
function methods:SetFlowLayoutGrowthDirection(x,y) self.flowX,self.flowY=x,y end
function methods:SetFlowLayoutAnchorPoint(v) self.flowPoint=v end
function methods:SetFlowLayoutMaximumLineSize(v) self.maxLine=v end
-- Blizzard_CustomAuraContainer: several groups share one flow layout, ordered by layoutIndex.
function methods:SetAuraGroupLayout(key,v) self.groups[key].options.layout=v; self.layoutCalls=(self.layoutCalls or 0)+1 end
function methods:SetAuraGroupFilterString(key,v) self.groups[key].filter=v end
function methods:SetAuraGroupCandidateFilters(key,v) self.groups[key].options.candidateFilters=v end
function methods:SetAuraGroupEnabled(key,v) self.groups[key].enabled=v end
function methods:SetAuraSlotFilterString(key,v) self.groups[key].filter=v end
function methods:SetAuraSlotCandidateFilters(key,v) self.groups[key].options.candidateFilters=v end
function methods:AddAuraGroup(key,filter,options,frames)
    self.groups=self.groups or {}; self.groupList=self.groupList or {}
    assert(not self.groups[key], "must reuse groups")
    local grp={key=key,filter=filter,options=options,buttons={},enabled=true}
    self.groups[key]=grp; self.groupList[#self.groupList+1]=grp
    self.group=self.group or grp
    for i=1,frames or 8 do
        local b=Object("AuraButton",self); b:Hide()
        options.initializeFrame(b)
        grp.buttons[i]=b
    end
end
function methods:AddAuraSlot(key,filter,options)
    -- Blizzard_AuraContainerSlots: a slot owns exactly one aura frame.
    self:AddAuraGroup(key,filter,options,1)
end
local auras={}
function methods:SetUnit(unit) self.unit=unit; self:UpdateAllAuras() end
function methods:UpdateAllAuras()
    if not self.groupList then return end
    local ordered={}
    for i,grp in ipairs(self.groupList) do
        for _, b in ipairs(grp.buttons) do b:Hide() end
        if grp.enabled then ordered[#ordered+1]={grp=grp,i=i} end
    end
    local function Index(o) local l=o.grp.options.layout; return l and l.layoutIndex or 0 end
    table.sort(ordered,function(x,y) if Index(x)~=Index(y) then return Index(x)<Index(y) end return x.i<y.i end)
    self.shown={}
    for _,o in ipairs(ordered) do
        local grp,count=o.grp,0
        for _,a in ipairs(auras[self.unit] or {}) do
            if a.harmful and grp.options.candidateFilters.includeSpellIDs[a.id]
                and (grp.filter == "HARMFUL" or a.mine) then
                count=count+1
                local b=grp.buttons[count]
                if b then
                    b:Show(); b.bar:SetTimerDuration({total=a.remaining,expires=now+a.remaining},nil,b.timerOptions.direction)
                    b.label:SetText(a.name)
                    self.shown[#self.shown+1]=b
                end
            end
        end
    end
    self.visibleCount=#self.shown
end
function methods:SetStatusBarTexture(path)
    if self.forbidden then error("Attempt to access forbidden object from code tainted by an AddOn") end
    self.texture=path
end
function methods:SetVertexColor() end
local timers={}
C_Timer={After=function(delay,fn) timers[#timers+1]=fn end}
local function RunTimers() local list=timers; timers={}; for _,fn in ipairs(list) do fn() end end
for _,name in ipairs({"SetColorTexture","SetTexCoord","SetTexture",
    "SetJustifyH","SetTextColor","SetWordWrap","SetMouseClickEnabled","SetMouseMotionEnabled",
    "SetMovable","SetResizable","SetResizeBounds","SetClampedToScreen","EnableMouse","RegisterForDrag",
    "SetBackdrop","SetBackdropColor","SetBackdropBorderColor","StartMoving","StopMovingOrSizing","StartSizing",
    "SetValueStep","SetObeyStepOnDrag","SetAutoFocus","SetMaxLetters","ClearFocus","SetScrollChild",
    "SetNormalTexture","SetHighlightTexture","SetPushedTexture","RegisterForClicks"}) do
    methods[name]=function() end
end
function CreateFrame(kind,name,parent,template)
    local f=Object(kind,parent)
    if name then _G[name]=f end
    if template == "OptionsSliderTemplate" then f.Low=Object("FontString",f);f.High=Object("FontString",f) end
    return f
end
UIParent=Object("Frame"); UIParent:SetSize(1920,1080)
Minimap=Object("Frame",UIParent); Minimap:SetSize(140,140)
UISpecialFrames={}; SlashCmdList={}
Enum={StatusBarTimerDirection={RemainingTime=1,ElapsedTime=0},StatusBarInterpolation={Immediate=0}}
AnchorUtil={FlowDirection={Right=1,Up=2,Down=3}}
C_XMLUtil={GetTemplateInfo=function() return {} end}
C_AddOns={IsAddOnLoaded=function() return true end, LoadAddOn=function() end}
C_Spell={GetSpellInfo=function(id) if id~=999999 then return {name="Spell "..id,iconID=id} end end, RequestLoadSpellData=function() end}
function UnitClass() return "Warlock","WARLOCK" end
function InCombatLockdown() return combat end
function GetTime() return now end
function GetCursorPosition() return 400,300 end
function IsMouseButtonDown() return false end
function MouseIsOver() return false end
cursor=nil;popup=nil
function GetCursorInfo() if cursor then return unpack(cursor) end end
function ClearCursor() cursor=nil end
function StaticPopup_Show(name,a1,a2,data) popup={name=name,data=data} end
CANCEL="Cancel"
function GetBuildInfo() return "1.60.1","70790","",16001 end
function issecretvalue(v) return type(v)=="table" and v.secret == true end
-- Lua 5.3 test runtime compatibility; the distributed addon is parsed as 5.1.
unpack=table.unpack
for _,file in ipairs({"Locale","Data","Core","Bars","Launcher","SpellTray","Options"}) do
    assert(loadfile("../DoTBarsForever/"..file..".lua"))("DoTBarsForever",ns)
end
ns.events.ADDON_LOADED(nil,"AnotherAddon")
eq(ns.db,nil,"ignore other addon load")
ns.events.ADDON_LOADED(nil,"DoTBarsForever")
ns.events.PLAYER_LOGIN()
eq(ns.class,"WARLOCK","class presets")
eq(#ns.Entries(),5,"warlock damaging presets")
eq(ns.SelectedIDs()[702],nil,"no generic utility curse")
eq(ns.SelectedIDs()[5782],nil,"no Fear")
eq(ns.SelectedIDs()[172],true,"Corruption preset")
for _,unit in ipairs(ns.units) do eq(ns.views[unit].stack.visibleCount,0,"no placeholder "..unit) end
auras.target={{id=172,harmful=true,mine=true,name="Corruption",remaining=12},
    {id=348,harmful=true,mine=false,name="Other Immolate",remaining=9},
    {id=172,harmful=false,mine=true,name="Fake helpful aura",remaining=5},
    {id=5782,harmful=true,mine=true,name="Fear",remaining=5}}
auras.targettarget={{id=348,harmful=true,mine=true,name="Immolate",remaining=8}}
auras.focus={{id=980,harmful=true,mine=true,name="Agony",remaining=18}}
ns.RefreshUnits()
eq(ns.views.target.stack.visibleCount,1,"only own active damage aura")
local liveBar=ns.views.target.stack.shown[1].bar
eq(liveBar.direction,Enum.StatusBarTimerDirection.RemainingTime,"native remaining-time binding")
eq(liveBar.texture,ns.textures[1].path,"flat texture by default")
now=now+2
liveBar:SetValue(liveBar.duration.expires-now)
eq(liveBar.value,10,"native timer simulation drains with elapsed time")
eq(ns.views.targettarget.stack.visibleCount,1,"target of target isolation")
eq(ns.views.focus.stack.shown[1].label.text,"Agony","focus isolation")
auras.target={}
ns.events.PLAYER_TARGET_CHANGED()
eq(ns.views.target.stack.visibleCount,0,"target switch clears old DoTs")
eq(ns.views.focus.stack.visibleCount,1,"focus survives target switch")
auras.targettarget={}
ns.events.UNIT_TARGET(nil,"target")
eq(ns.views.targettarget.stack.visibleCount,0,"target of target change clears")
ns.db.mine=false;ns.Apply()
auras.target={{id=348,harmful=true,mine=false,name="Immolate",remaining=3}}
ns.RefreshUnits()
eq(ns.views.target.stack.visibleCount,0,"other players' DoTs always hidden, even with the old setting off")
eq(ns.InitializeDB({mine=false}).mine,nil,"old only-my-DoTs setting dropped")
ns.db.disabled.immolate=true;ns.Apply()
eq(ns.views.target.stack.visibleCount,0,"disabled spell hidden")
local stack=ns.views.target.stack
local count=#allFrames
ns.db.groups.target.width=400;ns.Apply();ns.Apply()
eq(ns.views.target.stack,stack,"reuse aura containers")
eq(#allFrames,count,"style changes do not allocate frames")
eq(stack.groups["dot:corruption"].buttons[1].width,400,"width updates live widgets")
eq(stack.groups["dot:corruption"].options.layout.elementWidth,400,"width updates engine layout")
combat=true;ns.db.groups.target.width=450;ns.Apply()
eq(stack.groups["dot:corruption"].buttons[1].width,400,"combat defers layout changes")
eq(ns.pending,true,"pending combat update")
combat=false;ns.events.PLAYER_REGEN_ENABLED()
eq(stack.groups["dot:corruption"].buttons[1].width,450,"apply after combat")
ns.SetEditing(true)
eq(ns.views.target.editors.stack.shown,true,"explicit layout handle")
local sample=ns.views.target.editors.stack
local sampleValue=sample.preview.value
sample.scripts.OnUpdate(sample,1)
assert(sample.preview.value < sampleValue,"preview must animate")
eq(SmoothAnimatedBars,nil,"no external renderer")
ns.db.groups.target.growUp=true;ns.Apply()
eq(ns.views.target.stack.flowY,AnchorUtil.FlowDirection.Up,"upward layout engine")
eq(ns.views.target.stack.flowPoint,"BOTTOMLEFT","upward origin")
ns.db.groups.target.growUp=false;ns.Apply()
eq(ns.views.target.stack.flowY,AnchorUtil.FlowDirection.Down,"downward layout engine")
ns.ToggleSpellTray()
eq(ns.spellTray.shown,true,"spell tray opens")
combat=true;ns.events.PLAYER_REGEN_DISABLED()
eq(ns.views.target.editors.stack.shown,false,"combat hides layout handles")
eq(ns.spellTray.shown,false,"combat hides spell tray")
eq(ns.SetSlot("corruption",1),false,"combat blocks slot changes")
combat=false
ns.db.groups.target.free=true;ns.Apply()
eq(ns.views.target.stack.unit,"none","stack deactivated in free mode")
eq(ns.views.target.slots.corruption.unit,"target","free spell bound to own unit")
eq(ns.views.target.slots.corruption.visibleCount,0,"free mode no inactive placeholder")
local ok=ns.AddCustom("77777",false);eq(ok,false,"custom needs DoT verification")
ok=ns.AddCustom("172",true);eq(ok,false,"reject duplicate preset")
ok=ns.AddCustom("abc",true);eq(ok,false,"reject invalid ID")
ok=ns.AddCustom("999999",true);eq(ok,false,"uncached ID retry")
ok=ns.AddCustom("77777, 77778",true);eq(ok,true,"custom rank family")
eq(ns.SelectedIDs()[77778],true,"custom rank selected")
auras.target={{id=77778,harmful=true,mine=true,name="Custom DoT",remaining=5}}
ns.RefreshUnits()
eq(ns.views.target.slots.custom77777.visibleCount,1,"custom DoT active")
auras.target={};ns.RefreshUnits()
eq(ns.views.target.slots.custom77777.visibleCount,0,"custom expiration/removal")
-- Bar textures: options, previews and live bars follow the choice.
ns.db.texture="Classic";ns.Apply()
local slotBar=ns.views.target.slots.custom77777.group.buttons[1].bar
eq(slotBar.texture,ns.textures[2].path,"live bar takes the chosen texture")
eq(ns.views.target.editors.stack and ns.views.target.editors.stack.preview.texture or ns.textures[2].path,ns.textures[2].path,"layout sample takes the chosen texture")
-- A live bar locked by an assigned aura is restyled once it is free again.
slotBar.forbidden=true;ns.db.texture="Raid";ns.Apply()
eq(slotBar.texture,ns.textures[2].path,"locked live bar left alone")
eq(#timers>0,true,"restyle retry scheduled")
RunTimers();eq(slotBar.texture,ns.textures[2].path,"still locked: not restyled")
slotBar.forbidden=nil;RunTimers()
eq(slotBar.texture,ns.textures[3].path,"restyled after the aura ends")
eq(ns.InitializeDB({texture=2}).texture,"Classic","old texture position migrates by name")
eq(ns.InitializeDB({texture=99}).texture,"Skill","out-of-range old position clamped")
eq(ns.InitializeDB({}).texture,"Flat","flat texture name by default")
-- DoT Bars Forever's own textures ship in Media/ and are built-in choices.
for _,key in ipairs({"Smooth","Glass","Gloss"}) do
    local t=ns.FindTexture(key)
    eq(t and t.own,true,key.." texture is built in")
    eq(t and t.path:find("DoTBarsForever",1,true)~=nil,true,key.." texture ships with the addon")
end
eq(ns.InitializeDB({texture=7}).texture,"Skill","old positions never map onto new textures")
-- SharedMedia: optional, loaded by some other addon; its statusbars join the list.
eq(#ns.TextureList(),#ns.textures,"no SharedMedia: built-in textures only")
local lsmCallbacks,lsmMedia={},{["Blizzard"]=ns.textures[2].path,["Silk"]="Interface/AddOns/Pack/Silk"}
local lsmFonts={["Expressway"]="Interface/AddOns/Pack/Expressway.ttf"}
local function Media(kind) return kind=="font" and lsmFonts or lsmMedia end
local lsm={List=function(self,kind) local t={} for k in pairs(Media(kind)) do t[#t+1]=k end table.sort(t) return t end,
    Fetch=function(self,kind,key) return Media(kind)[key] end,
    Register=function(self,kind,key,path) Media(kind)[key]=path end,
    RegisterCallback=function(owner,event,fn) lsmCallbacks[event]=fn end}
LibStub=setmetatable({},{__call=function(_,name,silent) if name=="LibSharedMedia-3.0" then return lsm end end})
ns.events.ADDON_LOADED(nil,"SomePackWithLSM")
eq(ns.watchingMedia,true,"late SharedMedia picked up")
eq(lsmMedia["DoT Bars Forever Glass"],ns.FindTexture("Glass").path,"own textures offered to other addons")
eq(ns.FindTexture("DoT Bars Forever Glass"),nil,"own textures not listed twice")
eq(ns.FindTexture("Silk") and ns.FindTexture("Silk").shared,true,"pack texture listed")
eq(ns.FindTexture("Blizzard"),nil,"duplicate of built-in art skipped")
ns.db.texture="Satin";ns.Apply()
eq(slotBar.texture,ns.textures[1].path,"missing pack texture falls back to flat")
eq(ns.db.texture,"Satin","missing pack texture choice kept")
lsmMedia.Satin="Interface/AddOns/Pack/Satin"
lsmCallbacks.LibSharedMedia_Registered("LibSharedMedia_Registered","statusbar","Satin")
eq(slotBar.texture,"Interface/AddOns/Pack/Satin","pack registered later applies saved choice")
ns.ToggleOptions()
local shown=0;for _,r in ipairs(ns.textureRows) do if r.shown then shown=shown+1 end end
eq(shown,#ns.TextureList(),"options lists every texture")
local silkRow;for _,r in ipairs(ns.textureRows) do if r.key=="Silk" then silkRow=r end end
silkRow.scripts.OnClick(silkRow)
eq(ns.db.texture,"Silk","picking a pack texture saves its name")
eq(slotBar.texture,"Interface/AddOns/Pack/Silk","live bar uses the pack texture")
-- Fonts: built-in game fonts plus SharedMedia fonts; bars and samples follow the choice.
eq(ns.FindFont("Expressway") and ns.FindFont("Expressway").shared,true,"pack font listed")
local fontRow;for _,r in ipairs(ns.fontRows) do if r.key=="Expressway" then fontRow=r end end
fontRow.scripts.OnClick(fontRow)
eq(ns.db.font,"Expressway","picking a pack font saves its name")
local slotLabel=ns.views.target.slots.custom77777.group.buttons[1].label
eq(slotLabel.fontPath,"Interface/AddOns/Pack/Expressway.ttf","live bar text uses the chosen font")
ns.db.fontSize=17;ns.Apply()
eq(slotLabel.fontSize,17,"live bar text size follows the slider")
local sampleBar=ns.previews[1].bar
eq(sampleBar.dbfLabel.fontSize..","..sampleBar.dbfTime.fontSize,"17,17","sample text size follows the slider")
eq(sampleBar.dbfLabel.fontPath,"Interface/AddOns/Pack/Expressway.ttf","sample text uses the chosen font")
ns.db.font="Gone";ns.Apply()
eq(slotLabel.fontPath,ns.Font(),"missing pack font falls back to the game default")
eq(ns.InitializeDB({}).font,"Default","game default font by default")
ns.ToggleOptions()
LibStub=nil;ns.ResetTextures()
ns.db.texture="Flat";ns.db.font="Default";ns.db.fontSize=12;ns.Apply()
eq(ns.InitializeDB({liquid=true}).liquid,nil,"old liquid setting dropped")
ns.db.groups.focus.enabled=false;ns.Apply()
for _,c in ipairs(ns.views.focus.active) do eq(c.unit,"none","disabled focus unbound") end
eq(ns.minimapButton.shown,true,"minimap button default visible")
ns.db.minimap=false;ns.Apply();eq(ns.minimapButton.shown,false,"minimap hide setting")
ns.ToggleOptions()
eq(DoTBarsForeverOptions.shown,true,"options opens")
ns.ToggleOptions()
eq(DoTBarsForeverOptions.shown,false,"options closes")
-- Spell tray slot bar: one shared order; drops from the spellbook or action bars; reorder; remove.
local watcherFrame
for _,f in ipairs(allFrames) do if f.events and f.events.CURSOR_CHANGED then watcherFrame=f end end
local function Fire(e) watcherFrame.scripts.OnEvent(watcherFrame,e) end
local function Slots()
    local list={}
    for _,f in ipairs(allFrames) do if f.parent==ns.spellTray and f.isSlot and f.shown then list[#list+1]=f end end
    table.sort(list,function(a,b) return tonumber(a.number.text)<tonumber(b.number.text) end)
    return list
end
local function OrderKeys() local t={} for i,e in ipairs(ns.OrderedEntries()) do t[i]=e.key end return table.concat(t,",") end
ns.ToggleSpellTray()
eq(ns.spellTray.shown,true,"spell tray reopens after combat")
local n=#ns.OrderedEntries()
eq(Slots()[n].entry~=nil,true,"slots show tracked spells")
eq(Slots()[n+1].entry,nil,"an empty slot follows the last spell")
local pal
for _,f in ipairs(allFrames) do if f.parent==ns.spellTray and f.isSlot==false and f.shown and f.entry and f.entry.key=="immolate" then pal=f end end
eq(pal~=nil,true,"unslotted class DoT offered")
pal.scripts.OnMouseDown(pal);pal.scripts.OnClick(pal,"LeftButton")
eq(ns.OrderedEntries()[n+1].key,"immolate","clicking a class DoT fills the next slot")
eq(ns.db.disabled.immolate,nil,"slotting enables tracking")
cursor={"spell",3,"spell",348};Fire("CURSOR_CHANGED")
local s=Slots();s[1].scripts.OnReceiveDrag(s[1])
eq(ns.OrderedEntries()[1].key,"immolate","spellbook drop moves spell to slot 1")
eq(cursor,nil,"spellbook spell cleared from cursor")
eq(ns.db.groups.target.spells.immolate.y,ns.db.groups.target.y,"slot 1 is the first independent bar")
Fire("CURSOR_CHANGED")
cursor={"spell",9,"spell",172};Fire("CURSOR_CHANGED");Fire("ACTIONBAR_SLOT_CHANGED")
s=Slots();s[3].scripts.OnMouseDown(s[3]);s[3].scripts.OnClick(s[3],"LeftButton")
eq(ns.OrderedEntries()[3].key,"corruption","click with action bar spell fills slot 3")
eq(cursor and cursor[4],172,"action bar spell stays on cursor to put back")
cursor=nil;Fire("CURSOR_CHANGED")
cursor={"macro",5};Fire("CURSOR_CHANGED")
local before=OrderKeys();s=Slots();s[1].scripts.OnReceiveDrag(s[1])
eq(cursor and cursor[1],"macro","macro never cleared from cursor")
eq(OrderKeys(),before,"macro changes no slot")
cursor=nil;Fire("CURSOR_CHANGED")
s=Slots();local moving=s[1].entry.key
s[1].scripts.OnMouseDown(s[1]);s[1].scripts.OnDragStart(s[1])
local dropTarget=s[2];local realMouseIsOver=MouseIsOver;MouseIsOver=function(f) return f==dropTarget end
s[1].scripts.OnDragStop(s[1]);MouseIsOver=realMouseIsOver
eq(ns.OrderedEntries()[2].key,moving,"dragging between slots reorders")
before=OrderKeys();s[1].scripts.OnClick(s[1],"RightButton")
eq(OrderKeys(),before,"click after a slot drag is suppressed")
s=Slots();local removed=s[1].entry.key
s[1].scripts.OnMouseDown(s[1]);s[1].scripts.OnClick(s[1],"RightButton")
eq(ns.db.disabled[removed],true,"right-click removes a slot")
local count=#ns.OrderedEntries()
ok=ns.AddCustom("88888",true);eq(ok,true,"custom added while tray open")
eq(Slots()[count+1].entry and Slots()[count+1].entry.key,"custom88888","open tray refreshes after spell list change")
cursor={"spell",4,"spell",55555};Fire("CURSOR_CHANGED")
s=Slots();s[2].scripts.OnReceiveDrag(s[2])
eq(ns.confirmFrame and ns.confirmFrame.shown,true,"unknown spell asks before tracking")
eq(popup,nil,"never uses Blizzard's shared StaticPopup")
eq(StaticPopupDialogs,nil,"never writes Blizzard's StaticPopupDialogs")
ns.confirmFrame.accept.scripts.OnClick(ns.confirmFrame.accept)
eq(ns.confirmFrame.shown,false,"confirm window closes on accept")
eq(ns.OrderedEntries()[2].key,"custom55555","confirmed spell lands in the dropped slot")
s=Slots();cursor={"spell",4,"spell",55556};Fire("CURSOR_CHANGED");s[2].scripts.OnReceiveDrag(s[2])
ns.confirmFrame.cancel.scripts.OnClick(ns.confirmFrame.cancel)
eq(ns.confirmFrame.shown,false,"cancel closes confirm window")
eq(ns.OrderedEntries()[2].key,"custom55555","cancel tracks nothing")
cursor=nil;Fire("CURSOR_CHANGED")
cursor=nil;Fire("CURSOR_CHANGED")
-- A newly slotted bar matches the bars the player already resized.
local tg=ns.db.groups.target
for _,e in ipairs(ns.OrderedEntries()) do local p=tg.spells[e.key]; p.width,p.height=310,28 end
ok=ns.AddCustom("66666",true);eq(ok,true,"another custom added")
eq(ns.SetSlot("custom66666",1),true,"new spell slotted first")
eq(tg.spells.custom66666.width,310,"new bar matches existing width")
eq(tg.spells.custom66666.height,28,"new bar matches existing height")
local second=ns.OrderedEntries()[2].key
eq(tg.spells.custom66666.y-tg.spells[second].y,28+tg.gap,"bars step by their real height plus spacing")
tg.spells.custom66666.width=150;ns.ClearSlot("custom66666");ns.SetSlot("custom66666",1)
eq(tg.spells.custom66666.width,310,"re-slotted bar drops its stale size")
eq(ns.InitializeDB({order={"a",5,"b"}}).order[2],"b","saved slot order sanitized")
-- Layout handles: live-following sample bar, whole-pixel saves, top-level layering.
local editor=ns.views.target.editors.stack or select(2,next(ns.views.target.editors))
eq(editor.strata,"FULLSCREEN_DIALOG","layout handles above ordinary windows")
eq(editor.toplevel,true,"layout handle raises on click")
local anchored=0
for _,p in ipairs(editor.preview.points) do if p[1]=="TOPLEFT" or p[1]=="BOTTOMRIGHT" then anchored=anchored+1 end end
eq(anchored,2,"sample bar follows handle size while resizing")
editor.width,editor.height=233.6,20.1666851;editor.x,editor.y=12.4,-7.6
editor.scripts.OnDragStop(editor)
eq(editor.config.width,234,"resize saves whole-pixel width")
eq(editor.config.height,20,"resize saves whole-pixel height")
eq(editor.config.x,12,"move saves whole-pixel x")
eq(ns.InitializeDB({groups={target={height=20.1666851}}}).groups.target.height,20,"saved fractional height rounded")
eq(DoTBarsForeverOptions.strata,"HIGH","options window is an ordinary window")
eq(DoTBarsForeverOptions.toplevel,true,"options window raises on click")
local mb=ns.minimapButton
mb.scripts.OnMouseDown(mb);mb.scripts.OnDragStart(mb);mb.scripts.OnDragStop(mb)
mb.scripts.OnMouseDown(mb);mb.scripts.OnClick(mb,"LeftButton")
eq(DoTBarsForeverOptions.shown,true,"minimap click after drag opens options")
mb.scripts.OnClick(mb,"LeftButton")
eq(DoTBarsForeverOptions.shown,false,"minimap click toggles options")
ns.SetEditing(false)
eq(ns.spellTray.shown,false,"locking layout closes spell tray")
-- Per-DoT colors: one stack group per DoT, colored by school or override; cast order.
ns.db.groups.target.free=false;ns.db.colorBySchool=true
ns.db.disabled.immolate=nil;ns.db.disabled.corruption=nil;ns.db.disabled.siphon=nil;ns.Apply()
local st=ns.views.target.stack
eq(st.groups["dot:corruption"]~=nil and st.groups["dot:immolate"]~=nil,true,"one stack group per DoT")
local function Col(b) return string.format("%.2f,%.2f,%.2f",b.color[1],b.color[2],b.color[3]) end
eq(Col(st.groups["dot:corruption"].buttons[1].bar),"0.64,0.43,0.96","shadow DoT uses shadow color")
eq(Col(st.groups["dot:immolate"].buttons[1].bar),"1.00,0.48,0.20","fire DoT uses fire color")
ns.db.spellColors.immolate={.1,.2,.3};ns.Apply()
eq(Col(st.groups["dot:immolate"].buttons[1].bar),"0.10,0.20,0.30","per-spell override wins")
ns.db.spellColors.immolate=nil;ns.db.colorBySchool=false;ns.db.color=2;ns.Apply()
eq(Col(st.groups["dot:immolate"].buttons[1].bar),string.format("%.2f,%.2f,%.2f",ns.colors[2][1],ns.colors[2][2],ns.colors[2][3]),"school colors off: bar color")
ns.db.colorBySchool=true;ns.db.color=1;ns.Apply()
local cleaned=ns.InitializeDB({spellColors={x={2,-1,.5,9},y="bad"}}).spellColors
eq(cleaned.x[1]..","..cleaned.x[2]..","..tostring(cleaned.x[4]),"1,0,nil","saved spell color clamped")
eq(cleaned.y,nil,"bad saved spell color dropped")
ns.db.disabled.siphon=true;ns.Apply()
eq(st.groups["dot:siphon"].enabled,false,"untracked DoT group disabled")
ns.db.disabled.siphon=nil;ns.Apply()
eq(st.groups["dot:siphon"].enabled,true,"re-tracked DoT group enabled")
ns.SetSlot("corruption",1);ns.SetSlot("immolate",2)
auras.target={{id=172,harmful=true,mine=true,name="Corruption",remaining=12},{id=348,harmful=true,mine=true,name="Immolate",remaining=9}}
ns.RefreshUnits()
eq(st.shown[1].label.text,"Corruption","slot order before any cast")
combat=true
ns.events.UNIT_SPELLCAST_SUCCEEDED(nil,"player","cast1",172)
st:UpdateAllAuras()
eq(st.shown[1].label.text.."/"..st.shown[2].label.text,"Immolate/Corruption","in-combat cast moves that DoT to the end")
ns.events.UNIT_SPELLCAST_SUCCEEDED(nil,"player","cast2",{secret=true})
ns.events.UNIT_SPELLCAST_SUCCEEDED(nil,"party1","cast3",348)
st:UpdateAllAuras()
eq(st.shown[2].label.text,"Corruption","secret spell IDs and other casters ignored")
st.SetAuraGroupLayout=function() error("blocked") end
ns.events.UNIT_SPELLCAST_SUCCEEDED(nil,"player","cast4",348)
eq(ns.castOrderUnavailable,true,"refused reorder falls back to slot order")
st.SetAuraGroupLayout=nil
combat=false;ns.castOrderUnavailable=nil;ns.lastCast={};auras.target={}
-- Copy a unit's layout style to other units; each keeps its own anchor.
local tg,tt,fo=ns.db.groups.target,ns.db.groups.targettarget,ns.db.groups.focus
tg.width,tg.height,tg.gap,tg.growUp,tg.free=333,22,7,true,true
tg.spells={corruption={x=tg.x+10,y=tg.y-40,width=300,height=24}}
local ttX,ttY=tt.x,tt.y
eq(ns.CopyLayout("target",{"targettarget"}),true,"copy layout to one unit")
eq(tt.width..","..tt.height..","..tt.gap..","..tostring(tt.growUp)..","..tostring(tt.free),"333,22,7,true,true","style copied")
eq(tt.x..","..tt.y,ttX..","..ttY,"target unit keeps its own anchor")
eq(tt.spells.corruption.x..","..tt.spells.corruption.y,(ttX+10)..","..(ttY-40),"independent bars keep offsets from the anchor")
eq(tt.spells.corruption.width,300,"independent bar size copied")
tt.spells.corruption.width=150
eq(tg.spells.corruption.width,300,"copy is independent of the source")
combat=true
eq(ns.CopyLayout("target",{"focus"}),false,"no layout copy in combat")
combat=false
ns.ToggleOptions()
local bothButton;for _,f in ipairs(allFrames) do if f.text=="Both" then bothButton=f end end
eq(bothButton~=nil,true,"copy to both button shown")
bothButton.scripts.OnClick(bothButton)
eq(fo.width..","..tt.spells.corruption.width,"333,300","copy to both updates every other unit")
ns.ToggleOptions()
-- Profiles: class-named profile on first load; create, copy, switch, delete, reset; migration.
eq(ns.CurrentProfile(),"Warlock","first load uses a profile named after the class")
eq(DoTBarsForeverProfiles.profiles.Warlock,ns.db,"settings live in the profile")
local warlockWidth=ns.db.groups.target.width
eq(ns.CreateProfile("Raid",false),true,"create a profile from class defaults")
eq(ns.CurrentProfile(),"Raid","new profile in use")
eq(ns.db.groups.target.width,260,"new profile starts at defaults")
eq(#ns.OrderedEntries()>=5,true,"new profile autopopulates the class DoTs")
ns.db.groups.target.width=500
eq(ns.CreateProfile("Raid copy",true),true,"copy the current profile")
eq(ns.db.groups.target.width,500,"copy keeps current settings")
ns.db.groups.target.width=444
eq(DoTBarsForeverProfiles.profiles.Raid.groups.target.width,500,"copy is independent")
local dupOk,dupMsg=ns.CreateProfile("Raid",false)
eq(dupOk==false and dupMsg~=nil,true,"duplicate profile name refused")
eq(ns.CreateProfile("   ",false),false,"blank profile name refused")
eq(ns.UseProfile("Warlock"),true,"switch profile")
eq(ns.db.groups.target.width,warlockWidth,"switching restores that profile's settings")
eq(ns.DeleteProfile("Warlock"),false,"profile in use can't be deleted")
ns.ToggleOptions()
local delRow;for _,r in ipairs(ns.profileRows) do if r.name=="Raid copy" and r.shown then delRow=r end end
delRow.delete.scripts.OnClick(delRow.delete)
eq(ns.confirmFrame.shown,true,"delete asks first in the addon's own window")
eq(DoTBarsForeverProfiles.profiles["Raid copy"]~=nil,true,"nothing deleted before confirming")
ns.confirmFrame.accept.scripts.OnClick(ns.confirmFrame.accept)
eq(DoTBarsForeverProfiles.profiles["Raid copy"],nil,"confirmed delete removes the profile")
ns.ToggleOptions()
ns.UseProfile("Raid");ns.db.groups.target.width=333;ns.db.texture="Glass"
eq(ns.ResetProfile(),true,"reset profile")
eq(ns.db.groups.target.width..","..ns.db.texture,"260,Flat","reset returns to class defaults")
eq(ns.CurrentProfile(),"Raid","reset keeps the profile")
combat=true
eq(ns.UseProfile("Warlock"),false,"no profile switch in combat")
combat=false
local char,store=ns.ResolveProfiles({groups={target={width=410}},texture="Glass"},{profiles={}})
eq(char.profile,"Warlock","pre-profile save becomes the class profile")
eq(store.profiles.Warlock.groups.target.width..","..store.profiles.Warlock.texture,"410,Glass","old settings kept in that profile")
eq(char.groups.target.width,410,"old settings stay as a backup in the character save")
-- A /reload before the full restart: the profile store was not saved, so it comes back
-- empty. The backup migrates again; nothing is lost.
local again,store3=ns.ResolveProfiles(char,nil)
eq(store3.profiles.Warlock.groups.target.width,410,"unsaved profile store: settings migrate again")
-- With the store saved, the next load does not migrate a second time.
local count=0;for _ in pairs(store.profiles) do count=count+1 end
ns.ResolveProfiles(char,store)
local count2=0;for _ in pairs(store.profiles) do count2=count2+1 end
eq(count2,count,"saved profile store: no duplicate migration")
local char2=ns.ResolveProfiles({groups={}},{profiles={Warlock={}}})
eq(char2.profile~="Warlock",true,"a second migrated character gets its own profile")
ns.ResolveProfiles(DoTBarsForeverDB,DoTBarsForeverProfiles)
ns.UseProfile("Warlock")
ns.db.enabled=false;ns.Apply()
eq(ns.views.target.root.shown,false,"master disable")
eq(ns.InitializeDB({fontSize=100}).fontSize,20,"saved data sanitized")
print("PASS: "..assertions.." assertions; all three unit bindings, filtering, custom spells, layout, textures, options.")
