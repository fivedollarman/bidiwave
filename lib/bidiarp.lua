local bidiarp = {}

bidistep = 0
countseq = 0
cycount = 0
stepcount = 0

function bidiarp.seq(num,den,list,dur,vel,listmode)
  engine.noteOffAll()
  local rlist = {table.unpack(list)}
  local dursync = (num/den) * dur
  local oct = 0
  local mute = 1
  while #list > 0 do
      countseq = (countseq+1) % 10
      bidid = rlist[bidistep+1] + (1000*(countseq+1))
      engine.noteOn(bidid,rlist[bidistep+1]+(oct*12),vel*mute)
      clock.sync(dursync)
      engine.noteOff(bidid)
      clock.sync((num/den)-dursync)
      bidistep = (bidistep+1) % #rlist
      if listmode then -- arpeggiator algos
        if listmode["cyc"][1] == 1 then -- for cycles
          oct = oct(bidistep,listmode["cyc"][2],listmode["cyc"][3])
        elseif listmode["cyc"][1] == 2 then
          bidistep = bidistep+skipcyc(bidistep,listmode["cyc"][2],listmode["cyc"][3])
        else
          oct = 0
        end
        if listmode["step"][1] == 1 then -- for steps
          mute = mute(bidistep,listmode["step"][2],listmode["step"][3])
        elseif listmode["step"][1] == 2 then
          bidistep = bidistep+skip(bidistep,listmode["step"][2],listmode["step"][3])
        else
          oct = 0
        end
      end
  end
  engine.noteOffAll()
end

function oct(step,every,nfor)
  local octave = 0
    if step == 0 then
      if cycount == every-1 then
        octave = (octave+1)%nfor
        cyccount = cyccount+1%every
      end
    end
  return octave
end

function skipcyc(step,every,skip)
    if step == 0 then
      if cycount == 0 then
        skip = skip
        cycount = cycount+1%every
      else 
        skip = 0
      end
    end
  return skip
end

function skip(step,every,skip)
    if stepcount == 0 then
      skip = skip
      stepcount = stepcount+1%every
    else 
      skip = 0
    end 
  return skip
end

function mute(step,every,mute)
    if stepcount == 0 then
      mute = mute/8
      stepcount = stepcount+1%every
    else 
      mute = 1
    end 
  return mute
end

return bidiarp
