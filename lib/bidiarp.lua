local bidiarp = {}

bidistep = 0
countseq = 0

function bidiarp.seq(num,den,list,offnum,offden)
  engine.noteOffAll()
  local seqvel = 1
  local rlist = {table.unpack(list)}
  while #list > 0 do
      bidistep = (bidistep+1) % #rlist
      countseq = (countseq+1) % 10
      bidid = rlist[bidistep+1] + (1000*(countseq+1))
      engine.noteOn(bidid,rlist[bidistep+1],seqvel)
      clock.sync(offnum/offden)
      engine.noteOff(bidid)
      clock.sync((num/den)-(offnum/offden))
  end
  engine.noteOffAll()
end

return bidiarp
