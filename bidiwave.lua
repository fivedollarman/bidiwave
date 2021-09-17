-- bidiwave: bidimensional wavetable synthesizer
-- 1.0.0 @marcocinque
-- 
--
-- enc1 navigate
--


engine.name = "BidiWave"

local midi_in_device
local mpe_mode = false;
local page = 2
local wavesel = -1
local wstartendsel = -1
local pagepart = 1
local envtargets = {"Amp/Filt", "Wave 1", "Wave 2", "Cross"}
local lfowavesfreq = {0,0}
local lfoenvwavesbalance = {0,0}
local crossq = {0,0}
local wstart = {0,0}
local wend = {0,0}

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
      if mpe_mode then
        engine.noteOff(msg.note)
      else
        engine.noteOff(msg.note)
      end
    
    -- Note on
    elseif msg.type == "note_on" then
      if mpe_mode then
        engine.noteOn(msg.ch, msg.note, msg.vel / 127)
      else
        engine.noteOn(msg.note, msg.note, msg.vel / 127)
      end
      print("note " .. msg.note)

    -- Key pressure
    elseif msg.type == "key_pressure" then
      engine.pressure(msg.note, msg.note, msg.val / 127)
      
    -- Channel pressure
    elseif msg.type == "channel_pressure" then
      if mpe_mode then
        engine.pressure(msg.ch, msg.note, msg.val / 127)
      else
        engine.pressureAll(msg.val / 127)
      end
      
    -- Pitch bend
    elseif msg.type == "pitchbend" then
      local bend_st = (util.round(msg.val / 2)) / 8192 * 2 -1 -- Convert to -1 to 1
      local bend_range = params:get("bend_range")
      if mpe_mode then
        engine.pitchBend(msg.ch, MusicUtil.interval_to_ratio(bend_st * bend_range))
      else
        engine.pitchBendAll(MusicUtil.interval_to_ratio(bend_st * bend_range))
      end
      
    -- CC
    elseif msg.type == "cc" then
      -- Mod wheel
      if msg.cc == 1 then
        engine.timbreAll(msg.val / 127)
      elseif msg.cc == 74 and mpe_mode then
        engine.timbre(msg.ch, msg.val / 127)
      end
      
    end
  
  end
  
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
  
  params:add_separator("waves")
 
  for i = 1, 8 do
    params:add_file(i .. "wave", "wave " .. i, "/home/we/dust/audio/wavetables/sin_0001.wav")
    params:set_action(i .. "wave", function(file) engine.assignWave(i, file) end)
  end
  
  params:add_separator()
  
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
  
  params:add_control("detuneq", "detune interval", controlspec.new(0, 12, "lin", 0, 0, ""))
  params:set_action("detuneq", function(x) engine.detuneQ(x) end)
  
  params:add_control("filtcut", "filter cut", controlspec.new(-60, 60, "lin", 0, 0, ""))
  params:set_action("filtcut", function(x) engine.filtCut(x) end)
  
  params:add_control("filtenv", "filter envelope Q", controlspec.new(-60, 60, "lin", 0, 0, ""))
  params:set_action("filtenv", function(x) engine.filtCut(x) end)
  
  params:add_control("filtres", "filter resonance", controlspec.new(0.01, 1, "lin", 0, 1, ""))
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
  params:set_action("envoffset", function(x) envelopesoffset(msg.note,x) end)
  
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
  
end


function redraw()
  screen.clear()
  for i = 1, 4 do
    if i == page then
      screen.level(8)
    else
      screen.level(1)
    end
    screen.rect((i*3),0,2,4)
    screen.fill()
  end
  if page == 1 then
    screen.level(8)
    screen.move(20,5)
    screen.text("MIDI")
    screen.level(5)
    screen.circle(64, 32, 5)
    screen.fill()
  elseif page == 2 then
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
  elseif page == 3 then
    screen.level(8)
    screen.move(20,5)
    screen.text("envs")
  elseif page == 4 then
    screen.level(8)
    screen.move(20,5)
    screen.text("mods")
  end
  
  screen.update()
end
  
function cleanup()
end


function enc(n, d)
  if n == 1 then
    page = (page+d)%5
    redraw()
  elseif n == 2 then
    if page == 0 then
    elseif page == 1 then
    elseif page == 2 then
      if pagepart == 1 then
        wavesel = (wavesel+d)%8
      else
        wstartendsel = (wstartendsel+d)%4
      end
    redraw()
    elseif page == 3 then  
    elseif page == 4 then
    end
 
  elseif n == 3 then
    if page == 0 then
    elseif page == 1 then 
    elseif page == 2 then
      if pagepart == 1 then
      params:delta(wavesel+1 .. "wave", d)
      redraw()
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
      redraw()
      end
    end
  end
end


function key(n, z)
  if n == 1 then
  elseif n == 2 then
    if page == 2 then
      pagepart = 8
      wavesel = -1
      wstartendsel = -1
      redraw()
    end
  elseif n == 3 then
    if page == 2 then
      pagepart = 1
      wavesel = 0
      wstartendsel = -1
      redraw()
    end
  end
end
