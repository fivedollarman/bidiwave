local bidiarp = {}

bidistep = 0
countseq = 0

function bidiarp.seq(num,den,list,dur,vel,listmode)
  engine.noteOffAll()
  local rlist = {table.unpack(list)}
  local dursync = (num/den) * dur
  local oct = 0
  local mute = 1
  local skip = 0
  local stepcount = 0
  local cycount = 0

  while #list > 0 do
      countseq = (countseq+1) % 10
      bidistep = (bidistep+1) % #rlist
      bidid = rlist[bidistep+1] + (1000*(countseq+1))
      engine.noteOn(bidid,rlist[bidistep+1]+(oct*12),vel*mute)
      clock.sync(dursync)
      engine.noteOff(bidid)
      clock.sync((num/den)-dursync)
      
      if listmode then -- arpeggiator algos
        if listmode["cyc"][1] == 1 then -- for cycles
          if bidistep == 0 then
            if cycount == listmode["cyc"][2]-1 then
              oct = (oct+1)%listmode["cyc"][3]
              cycount = cycount+1%listmode["cyc"][2]
            end
        end
        elseif listmode["cyc"][1] == 2 then
          if bidistep == 0 then
            if cycount == 0 then
              skip = listmode["cyc"][3] 
              bidistep = bidistep + skip
              cycount = cycount+1%listmode["cyc"][2] 
            else 
              skip = 0
            end
        end
        else
          oct = 0
          cycount = 0
        end
        
        if listmode["step"][1] == 1 then -- for steps
          if stepcount == 0 then
            skip = listmode["step"][3]
            bidistep = bidistep + skip
            stepcount = stepcount+1%listmode["step"][2]
          else 
            skip = 0
          end 
        elseif listmode["step"][1] == 2 then
          if stepcount == 0 then
            mute = listmode["step"][3]/8
            stepcount = stepcount+1%listmode["step"][2]
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
