-- bidiwave: bidimensional 
--                  wavetable
--       d('u')b       synthesizer
-- 1.0.0 @marcocinque 
--
-- enc1 > pages
-- key3 & key4 > page sections
-- enc3 & enc4 > values
--


engine.name = "BidiWave"
local bidiarp = require "bidiwave/lib/bidiarp"

local MusicUtil = require "musicutil"
local midi_in_device
local mpe_mode = false;
local bidinote = 0
local bidid = 0
local bididoff = {}
local counten = 0
local face = 5
local page = 0
local wavesel = -1
local wstartendsel = -1
local pagepart = 1
local envtargets = {"AmpFil", "Wave1", "Wave2", "Cross"}
local envedit = {1, 1, 1, 1}
local lvls = {0,0,0,0,0,0}
local tms = {0,0,0,0,0}
local crvs = {0,0,0,0,0}
local targetedit = 0
local valuedit = 0
local pagepos = 0
local modslist = {{"detuneq", "detunelfof", "detunelfoq"}, {"lfowavesfreq1", "lfoenvbal1"}, {"noteoffset", "lfowavesfreq2", "lfoenvbal2"}, {"crossmodql", "crossmodqr", "lfoxfreq", "lfoenvxbal"}, {"filtcut", "filtres", "filtenv"}}
local modslistnm = {{"det", "nF", "/"}, {"nF", "/"}, {"trnsp", "nF", "/"}, {"QL", "QR", "nF", "/"}, {"cut", "res", "env"}}
local lfowavesfreq = {0,0}
local lfoenvwavesbalance = {0,0}
local crossq = {0,0}
local wstart = {0,0}
local wend = {0,0}
local savecolor = 12
local loadcolor = 12
local psetnum = 1
local arparray = {}
local arp = {"off","on"}
local arpvoice = {}

-- MIDI input
local function midi_event(data)
  
  local msg = midi.to_msg(data)
  local channel_param = params:get("midi_channel")

  if channel_param == 18 then
    channel_param = 1
    mpe_mode = true
  end

  if channel_param == 1 or (channel_param > 1 and msg.ch == channel_param - 1) then
    
    -- Note off
    if msg.type == "note_off" then
      bidinote = msg.note
      
      if params:get("arpeggiator") == 2 then
        if #arparray > 1 then
          for i=1,#arparray do
            if arparray[i] == bidinote then
              table.remove(arparray,i)
            end
          end
        else 
          clock.cancel(arpvoice[1])
          arparray = {}
        end
      else
        engine.noteOff(bididoff[bidinote])
      end
    
    -- Note on
    elseif msg.type == "note_on" then
      face = (face+1)%16
      if page == 0 then redraw() end
      bidinote = msg.note
      
      if params:get("arpeggiator") == 2 then
        arparray[#arparray+1] = bidinote
        arpvoice[1] = clock.run(bidiarp.seq,1,4,#arparray,arparray,1,8)
      else
        counten = (counten+1)%10
        bidid = bidinote + (1000*(counten+1))
        bididoff[bidinote] = bidid
        engine.noteOn(bidid, bidinote, msg.vel / 127)
      end
      
    -- Pitch bend
    elseif msg.type == "pitchbend" then
      local bend_st = (util.round(msg.val / 2)) / 8192 * 2 -1 -- Convert to -1 to 1
      local bend_range = params:get("bend_range")
      if mpe_mode then
        engine.pitchBend(MusicUtil.interval_to_ratio(bend_st * bend_range))
      else
        engine.pitchBend(MusicUtil.interval_to_ratio(bend_st * bend_range))
      end
      
    -- CC
    elseif msg.type == "cc" then
      -- Mod wheel
      if msg.cc == 1 then
        engine.modwheel(msg.val / 127)
      end
      
    end
  
  end
  
end

function fround(number, decimals)
  local scale = 10^decimals
  local c = 2^52 + 2^51
  return ((number * scale + c ) - c) / scale
end

-- envelopes
local function envelopes(param,point,target,value)
  if(param==1) then
    engine.envL(point,target,value)
  elseif(param==2) then
    engine.envT(point,target,value)
  elseif(param==3) then
    engine.envC(point,target,value)
  end
end

local function envelopesoffset(note,value)
  local noteoffset
  noteoffset = math.abs(value-((note*value)/127))
  engine.envelopesOffset(noteoffset)
end

-- lofos
local function lfowf(id,freq)
  lfowavesfreq[id] = freq
  engine.lfoWavesFreq(lfowavesfreq[1],lfowavesfreq[2])
end

local function lfoenvw(id,q)
  lfowavesfreq[id] = q
  engine.lfoEnvWavesBalance(lfoenvwavesbalance[1],lfoenvwavesbalance[2])
end

-- waves
local function crossmod(id,q)
  crossq[id] = q
  engine.crossWavesQ(crossq[1],crossq[2])
end

local function wavestart(id,number)
  wstart[id] = number
  engine.waveStart(wstart[1],wstart[2])
end

local function wavend(id,number)
  wend[id] = number
  engine.waveEnd(wend[1],wend[2])
end


function init()
  
  midi_in_device = midi.connect(1)
  midi_in_device.event = midi_event
  
  params:add{type = "number", id = "midi_device", name = "MIDI Device", min = 1, max = 4, default = 1, action = function(value)
    midi_in_device.event = nil
    midi_in_device = midi.connect(value)
    midi_in_device.event = midi_event
  end}
  
  local channels = {"All"}
  for i = 1, 16 do 
    table.insert(channels, i) 
  end
  
  table.insert(channels, "MPE")
  params:add{type = "option", id = "midi_channel", name = "MIDI Channel", options = channels}
  params:add{type = "number", id = "bend_range", name = "Pitch Bend Range", min = 1, max = 48, default = 2}
  params:add_option("arpeggiator","arpeggiator",arp,1)
  
  params:add_separator("waves")
 
  for i = 1, 8 do
    params:add_file(i .. "wave", "wave " .. i, "/home/we/dust/audio/wavetables/sin_0001.wav")
    params:set_action(i .. "wave", function(file) engine.assignWave(i, file) end)
  end
  
  params:add_separator()
  
  params:add_control("portamento", "portamento", controlspec.new(0, 5, "lin", 0, 0, "s"))
  params:set_action("portamento", function(x) engine.portam(x) end)
  
  params:add_control("noteoffset", "osc 2 note offset", controlspec.new(-36, 36, "lin", 1, 0, ""))
  params:set_action("noteoffset", function(x) engine.noteOffset(x) end)
  
  params:add_control("crossmodql", "cross modulation left", controlspec.new(-1, 1, "lin", 0, 0, ""))
  params:set_action("crossmodql", function(x) crossmod(1,x) end)
  
  params:add_control("crossmodqr", "cross modulation right", controlspec.new(-1, 1, "lin", 0, 0, ""))
  params:set_action("crossmodqr", function(x) crossmod(2,x) end)
  
  params:add_control("wave1start", "wave 1 start", controlspec.new(0, 7, "lin", 1, 0, ""))
  params:set_action("wave1start", function(x) wavestart(1,x) end)
  
  params:add_control("wave2start", "wave 2 start", controlspec.new(0, 7, "lin", 1, 0, ""))
  params:set_action("wave2start", function(x) wavestart(2,x) end)
  
  params:add_control("wave1end", "wave 1 end", controlspec.new(0, 7, "lin", 1, 0, ""))
  params:set_action("wave1end", function(x) wavend(1,x) end)
  
  params:add_control("wave2end", "wave 2 end", controlspec.new(0, 7, "lin", 1, 0, ""))
  params:set_action("wave2end", function(x) wavend(2,x) end)
  
  params:add_control("detuneq", "detune interval", controlspec.new(0, 0.5, "lin", 0, 0, ""))
  params:set_action("detuneq", function(x) engine.detuneQ(x) end)
  
  params:add_control("filtcut", "filter cut", controlspec.new(-24, 96, "lin", 0, 0, ""))
  params:set_action("filtcut", function(x) engine.filtCut(x) end)
  
  params:add_control("filtenv", "filter envelope Q", controlspec.new(-60, 60, "lin", 0, 0, ""))
  params:set_action("filtenv", function(x) engine.filtEnvQ(x) end)
  
  params:add_control("filtres", "filter resonance", controlspec.new(0.01, 1, "lin", 0.01, 1, ""))
  params:set_action("filtres", function(x) engine.filtRes(x) end)
    
  params:add_separator("envelopes")
  
  for i = 1, 6 do
    for ii = 1, 4 do
      params:add_control("l" .. i .. envtargets[ii], i .. " Env level " .. envtargets[ii], controlspec.new(0, 1, "lin", 0, 0.5, ""))
      params:set_action("l" .. i .. envtargets[ii], function(x) envelopes(1,i,ii,x) end)
    end
  end

  for i = 1, 5 do
    for ii = 1, 4 do
      params:add_control("t" .. i .. envtargets[ii], i .. " Env time " .. envtargets[ii], controlspec.new(0.001, 5, "exp", 0, 0.001, "s"))
      params:set_action("t" .. i .. envtargets[ii], function(x) envelopes(2,i,ii,x) end)
    end
  end

  for i = 1, 5 do
    for ii = 1, 4 do
      params:add_control("c" .. i .. envtargets[ii], i .. " Env curve " .. envtargets[ii], controlspec.new(-10, 10, "lin", 0, 0, ""))
      params:set_action("c" .. i .. envtargets[ii], function(x) envelopes(3,i,ii,x) end)
    end
  end
  
  params:add_control("looppoint", "loop point", controlspec.new(0, 5, "lin", 1, 0, ""))
  params:set_action("looppoint", function(x) engine.loopPoint(x) end)
  
  params:add_control("relpoint", "release point", controlspec.new(0, 5, "lin", 1, 0, ""))
  params:set_action("relpoint", function(x) engine.releasePoint(x) end)
  
  params:add_control("envoffset", "envelopes offset", controlspec.new(-5, 5, "lin", 0, 0, ""))
  -- params:set_action("envoffset", function(x) envelopesoffset(msg.note,x) end)
  
  params:add_separator("lfos")
  
  params:add_control("detunelfof", "detune lfo freq", controlspec.new(0, 8, "lin", 0, 0, "hz"))
  params:set_action("detunelfof", function(x) engine.detuneLfoF(x) end)
  
  params:add_control("detunelfoq", "detune lfo Q", controlspec.new(0, 1, "lin", 0, 0, ""))
  params:set_action("detunelfoq", function(x) engine.detuneLfoQ(x) end)
  
  params:add_control("lfowavesfreq1", "lfo wavetable 1 mod freq", controlspec.new(0, 8, "lin", 0, 0, "hz"))
  params:set_action("lfowavesfreq1", function(x) lfowf(1,x) end)
  
  params:add_control("lfowavesfreq2", "lfo wavetable 2 mod freq", controlspec.new(0, 8, "lin", 0, 0, "hz"))
  params:set_action("lfowavesfreq2", function(x) lfowf(2,x) end)
  
  params:add_control("lfoenvbal1", "lfo env wavetable 1 bal", controlspec.new(0, 1, "lin", 0, 0, ""))
  params:set_action("lfoenvbal1", function(x) lfoenvw(1,x) end)
  
  params:add_control("lfoenvbal2", "lfo env wavetable 2 bal", controlspec.new(0, 1, "lin", 0, 0, ""))
  params:set_action("lfoenvbal2", function(x) lfoenvw(2,x) end)
  
  params:add_control("lfoxfreq", "lfo cross mod freq", controlspec.new(0, 8, "lin", 0, 0, "hz"))
  params:set_action("lfoxfreq", function(x) engine.lfoXFreq(x) end)
  
  params:add_control("lfoenvxbal", "lfo env cross mod bal", controlspec.new(0, 1, "lin", 0, 0, ""))
  params:set_action("lfoenvxbal", function(x) engine.lfoXFreq(x) end)
  
  -- load default pset
  params:read()
  params:bang()
  
end


function redraw()
  screen.clear()
  
  for i = 1, 4 do
    if i == page then
      screen.level(8)
    elseif page == 0 then
      screen.level(0)
    else
      screen.level(1)
    end
    screen.rect((i*3),0,2,4)
    screen.fill()
  end
  
  if page == 0 then -- hello page
    screen.move(64, 32)
    for i = 1, face do
      screen.line_width(1)
      screen.level(math.floor(i*0.35)+1)
      screen.circle(64, 32, math.floor(i*i*0.5))
      screen.stroke()
    end
    screen.line_width(1)
    screen.level(12)
    screen.font_face(face)
    screen.font_size(32)
    screen.move(0,46)
    screen.text("bidiwave")
    screen.font_face(0)
    screen.font_size(8)
    screen.level(1)
    screen.rect(0,54,128,10)
    screen.fill()
    screen.move(2,62)
    screen.level(savecolor)
    screen.text("SAVE")
    screen.move(21,62)
    screen.level(12)
    screen.text("/")
    screen.move(26,62)
    screen.level(loadcolor)
    screen.text("LOAD")
    screen.move(48,62)
    screen.level(12)
    screen.text("->")
    screen.move(60,62)
    screen.level(12)
    screen.text(psetnum)
    
  elseif page == 1 then -- MIDI page
    screen.level(8)
    screen.move(20,5)
    screen.text("MIDI")
    screen.level(5)
    screen.circle(64, 32, 5)
    screen.fill()
    
  elseif page == 2 then -- wavetables page
    screen.level(8)
    screen.level(8)
    screen.move(20,5)
    screen.text("wtables")
    screen.level(2)
    screen.move(10,12)
    screen.text(".wav 512")
    screen.level(pagepart)
    screen.rect(4,18,44,44)
    screen.stroke()
    if wstartendsel == 0 then screen.level(8) else screen.level(1) end
    screen.move(15,32)
    screen.text(params:get("wave1start")+1)
    if wstartendsel == 1 then screen.level(8) else screen.level(1) end
    screen.move(33,32)
    screen.text(params:get("wave1end")+1)
    if wstartendsel == 2 then screen.level(8) else screen.level(1) end
    screen.move(15,52)
    screen.text(params:get("wave2start")+1)
    if wstartendsel == 3 then screen.level(8) else screen.level(1) end
    screen.move(33,52)
    screen.text(params:get("wave2end")+1)
    for i = 1, 8 do
      if i == wavesel+1 then
        screen.level(8)
      else
        screen.level(1) 
      end
      screen.move(54,0+(i*8))
      screen.text(i .. string.sub(params:get(i .. "wave"), 31))
    end
    
  elseif page == 3 then -- envelopes page
    for i = 1, 4 do
      if envedit[i] == 1 then screen.level(8) else screen.level(1) end
      screen.move(20+(i-1)*28,5)
      screen.text(envtargets[i])
    end
    if pagepos == 0 then screen.level(12) else screen.level(2) end
    screen.move(20+targetedit*28,7)
    screen.line(30+targetedit*28,7)
    screen.stroke()
    screen.level(4)
    screen.move(0,14)
    screen.text("L")
    for i = 1, 6 do
      if valuedit+1 == i and pagepos == 1 then screen.level(8) else screen.level(1) end
      screen.move(7+(i-1)*22,14)
      lvls[i]=params:get("l" .. i .. envtargets[targetedit+1])
      screen.text(lvls[i])
    end
    screen.level(4)
    screen.move(0,21)
    screen.text("Time")
    for i = 1, 5 do
      if valuedit+1 == i and pagepos == 2 then screen.level(8) else screen.level(1) end
      screen.move(19+(i-1)*22,21)
      tms[i]=params:get("t" .. i .. envtargets[targetedit+1])
      screen.text(fround(tms[i],2))
    end
    screen.level(4)
    screen.move(0,28)
    screen.text("Curv")
    for i = 1, 5 do
      if valuedit+1 == i and pagepos == 3 then screen.level(8) else screen.level(1) end
      screen.move(19+(i-1)*22,28)
      crvs[i]=params:get("c" .. i .. envtargets[targetedit+1])
      screen.text(crvs[i])
    end
    -- draw envelope
    if pagepos == 4 then screen.level(12) else screen.level(4) end
    screen.aa(1)
    screen.move(0,60-(lvls[1]*25))
    screen.curve_rel(0, 0, tms[1]*2.5, (lvls[1]-lvls[2]-(crvs[1]/20))*12.5, tms[1]*5, (lvls[1]-lvls[2])*25)
    if params:get("looppoint")==1 then screen.text("L") end
    if params:get("relpoint")==1 then screen.text("R") end
    screen.curve_rel(0, 0, tms[2]*2.5, (lvls[2]-lvls[3]-(crvs[2]/20))*12.5, tms[2]*5, (lvls[2]-lvls[3])*25)
    if params:get("looppoint")==2 then screen.text("L") end
    if params:get("relpoint")==2 then screen.text("R") end
    screen.curve_rel(0, 0, tms[3]*2.5, (lvls[3]-lvls[4]-(crvs[3]/20))*12.5, tms[3]*5, (lvls[3]-lvls[4])*25)
    if params:get("looppoint")==3 then screen.text("L") end
    if params:get("relpoint")==3 then screen.text("R") end
    screen.curve_rel(0, 0, tms[4]*2.5, (lvls[4]-lvls[5]-(crvs[4]/20))*12.5, tms[4]*5, (lvls[4]-lvls[5])*25)
    if params:get("looppoint")==4 then screen.text("L") end
    if params:get("relpoint")==4 then screen.text("R") end
    screen.curve_rel(0, 0, tms[5]*2.5, (lvls[5]-lvls[6]-(crvs[5]/20))*12.5, tms[5]*5, (lvls[5]-lvls[6])*25)
    screen.stroke()
    screen.aa(0)

  elseif page == 4 then -- modulations page
    screen.level(8)
    screen.move(20,5)
    screen.text("mods")
    if pagepos == 0 or pagepos == 1 then screen.level(8) else screen.level(2) end
    screen.move(4,25)
    screen.text("wave1")
    screen.level(8)
    screen.move(33,24)
    screen.line(42,33)
    screen.stroke()
    if pagepos == 0 or pagepos == 2 then screen.level(8) else screen.level(2) end
    screen.move(4,45)
    screen.text("wave2")
    screen.level(8)
    screen.move(33,42)
    screen.line(42,33)
    screen.stroke()
    if pagepos == 3 then screen.level(8) else screen.level(2) end
    screen.move(45,35)
    screen.text("x")
    screen.level(8)
    screen.move(52,33)
    screen.line(67,33)
    screen.stroke()
    screen.level(3)
    screen.move(70,35)
    screen.text("amp")
    screen.level(8)
    screen.move(87,33)
    screen.line(97,33)
    screen.stroke()
    if pagepos == 4 then screen.level(8) else screen.level(2) end
    screen.move(100,35)
    screen.text("filt")
    
      for i = 1, #modslist[pagepos+1] do
        if valuedit+1 == i then screen.level(8) else screen.level(2) end
        screen.move(((i-1)*34),60)
        screen.text(modslistnm[pagepos+1][i])
        screen.move(screen.text_extents(modslistnm[pagepos+1][i])+2+((i-1)*34),60)
        screen.text(params:get(modslist[pagepos+1][i]))
      end
  end
  
  screen.update()
end


function enc(n, d)
  if n == 1 then
    page = (page+d)%5
    pagepos = 0
    
  elseif n == 2 then
    if page == 0 then
      psetnum = (psetnum+d)%128
      
    elseif page == 1 then
      -- clock.cancel(arpvoice[1])
      
    elseif page == 2 then
      if pagepart == 1 then
        wavesel = (wavesel+d)%8
      else
        wstartendsel = (wstartendsel+d)%4
      end
      
    elseif page == 3 and pagepos == 0 then  
      targetedit = (targetedit+d)%4
    elseif page == 3 and pagepos == 1 then  
      valuedit = (valuedit+d)%6
    elseif page == 3 and pagepos > 1 and pagepos < 4 then  
      valuedit = (valuedit+d)%5
    elseif page == 3 and pagepos == 4 then
      params:delta("looppoint", d)
      
    elseif page == 4 then
      valuedit = (valuedit+d) % #modslist[pagepos+1]
    end
 
  elseif n == 3 then
    if page == 0 then
      face = (face+d)%16
      
    elseif page == 1 then 
      
    elseif page == 2 then
      if pagepart == 1 then
      params:delta(wavesel+1 .. "wave", d)
      else
        if wstartendsel == 0 then
          params:delta("wave1start", d)
        elseif wstartendsel == 1 then
          params:delta("wave1end", d)
        elseif wstartendsel == 2 then
          params:delta("wave2start", d)
        elseif wstartendsel == 3 then
          params:delta("wave2end", d)
        end 
      end
    
    elseif page == 3 then
      if pagepos == 0 then
          envedit[targetedit+1] = (envedit[targetedit+1]+d)%2
      elseif pagepos == 1 then
        for i = 1, 4 do
          if envedit[i] == 1 then
            params:delta("l" .. valuedit+1 .. envtargets[i], d)
          end
        end
      elseif pagepos == 2 then
        for i = 1, 4 do
          if envedit[i] == 1 then
            params:delta("t" .. valuedit+1 .. envtargets[i], d)
          end
        end
     elseif pagepos == 3 then
        for i = 1, 4 do
          if envedit[i] == 1 then
            params:delta("c" .. valuedit+1 .. envtargets[i], d)
          end
        end
     elseif pagepos == 4 then
       params:delta("relpoint", d)
     end
     
   elseif page == 4 then
     params:delta(modslist[pagepos+1][valuedit+1], d)
   end
 end
 redraw()
end


function key(n, z)
  if n == 1 then
    
  elseif n == 2 then
    
    if page == 0 and z==1 then
      savecolor = 0
    elseif page == 0 and z==0 then
      savecolor = 12
      params:write(psetnum)

    elseif page == 2 and z==1 then
      pagepart = 8
      wavesel = -1
      wstartendsel = -1
    
    elseif page == 3 and z==1 then
      pagepos = (pagepos-1)%5
      
    elseif page == 4 and z==1 then
      pagepos = (pagepos-1)%5
    end
    
  elseif n == 3 then
    
    if page == 0 and z==1 then
      loadcolor = 0
    elseif page == 0 and z==0 then
      loadcolor = 12
      params:read(psetnum)
      params:bang()
    
    elseif page == 2 and z==1 then
      pagepart = 1
      wavesel = 0
      wstartendsel = -1
    
    elseif page == 3 and z==1 then
      pagepos = (pagepos+1)%5
      
    elseif page == 4 and z==1 then
      pagepos = (pagepos+1)%5
      
    end
  end
  redraw()
end

function cleanup()
end
