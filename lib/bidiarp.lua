local bidiarp = {}

bidistep = 0
countseq = 0

function bidiarp.seq(num,den,list,dur,vel,listmode)
  engine.noteOffAll()
  local rlist = {table.unpack(list)}
  local dursync = ((num/den)/4) * dur
  local oct = 0
  local mute = 1
  local skip = 0
  local stepcount = 0
  local cycount = 0
  
  if listmode["mode"] == 1 then
    table.sort(rlist, function(a,b)
    	return a > b
    end)
  elseif listmode["mode"] == 2 then
        table.sort(rlist, function(a,b)
    	return a < b
    end)
  end

  while #rlist > 0 do
      countseq = (countseq+1) % 25
      bidistep = (bidistep+1+skip) % #rlist
      bidid = rlist[bidistep+1] + (1000*(countseq+1))
      if mute > 0 then
        engine.noteOn(bidid,rlist[bidistep+1]+(oct*12),vel*mute)
      end
      clock.sync(dursync)
      if mute > 0 then
        engine.noteOff(bidid)
      end
      clock.sync((num/den)-dursync)
      if listmode then -- arpeggiator algos
        if listmode["cyc"][1] == 1 then -- for cycles
          if bidistep == 0 then
            cycount = (cycount+1)%(listmode["cyc"][2]+1)
          end
          if cycount == 0 then
            oct = (oct+1)%(listmode["cyc"][3]+1)
          end
        elseif listmode["cyc"][1] == 2 then
          if bidistep == 0 then
            cycount = (cycount+1)%(listmode["cyc"][2]+1)
          end
          if cycount == 0 then
            skip = listmode["cyc"][3] 
          else 
            skip = 0
          end
        else
          oct = 0
          cycount = 0
        end
        
        if listmode["step"][1] == 1 then -- for steps
          stepcount = (stepcount+1)%(listmode["step"][2]+1)
          if stepcount == 0 then
            skip = listmode["step"][3]
          else 
            skip = 0
          end 
        elseif listmode["step"][1] == 2 then
          stepcount = (stepcount+1)%(listmode["step"][2]+1)
          if stepcount == 0 then
            mute = listmode["step"][3]/8
          else 
            mute = 1
          end 
        else
          stepcount = 0
        end
      end
  end
  engine.noteOffAll()
end

return bidiarp
