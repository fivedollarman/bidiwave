// CroneEngine_BidiWave
//
// v1.0.0 
// marcocinque d('u')b

Engine_BidiWave : CroneEngine {

  classvar maxNumVoices = 7;
  var voiceGroup;
  var voiceList;

  var pitchBendRatio = 1;
  var modwheel = 0, modwF = 8;
  var velQ = 0.75;
  var out=0, offsetnote=0, prevnote=0, slideT=0, amp=0.25;
  var detQ=0.0125, lfdetF=0.5, lfdetQ=0.1, cut=0, filtEnvQ=12, reson=1, xfilt=1, lfxF=0.125, xlfEnvQ=0.5;
  var lfwaveF, xQ, lfEnvQ, waveStart, waveEnd, buf;
  var l1, l2, l3, l4, l5, l6;
  var t1, t2, t3, t4, t5;
  var c1, c2, c3, c4, c5;
  var relP=3, loopP=1, offset=1;
	
  var warray;
  var wbuff;
  var wload;
	
  *new { arg context, doneCallback;
	^super.new(context, doneCallback);
  }

  alloc {
	
       warray = Array.newClear(12);
       wbuff = Buffer.allocConsecutive(12,context.server,1024);
       buf=wbuff[0].bufnum;
	  
       wload = {
       arg index, pt;
       var file, arr;
       file = SoundFile.openRead(pt);
       arr = FloatArray.newClear(file.numFrames);
       file.readData(arr);
       file.close;
       arr = arr.as(Signal);
       arr = arr.asWavetable;
       warray[index] = arr;
    };

    voiceGroup = Group.new(context.xg);
    voiceList = List.new();
		
    lfwaveF=Array.newClear(2);
    xQ=Array.newClear(2);
    lfEnvQ=Array.newClear(2);
    waveStart=Array.newClear(2);
    waveEnd=Array.newClear(2);
    l1=Array.newClear(4);
    l2=Array.newClear(4);
    l3=Array.newClear(4);
    l4=Array.newClear(4);
    l5=Array.newClear(4);
    l6=Array.newClear(4);
    t1=Array.newClear(4);
    t2=Array.newClear(4);
    t3=Array.newClear(4);
    t4=Array.newClear(4);
    t5=Array.newClear(4);
    c1=Array.newClear(4);
    c2=Array.newClear(4);
    c3=Array.newClear(4);
    c4=Array.newClear(4);
    c5=Array.newClear(4);

		// Synth voice
	SynthDef(\BidiWave, {
	arg out, buf, gate=0, killGate=1, note=64, offsetnote=0, prevnote=64, pitchBendRatio=1, modw, modwF, slideT, amp, xfilt, 
	detQ, lfdetF, lfdetQ, lfxF, lfwaveF=#[0.25,0.8], lfEnvQ=#[1,1], waveStart=#[0,3], waveEnd=#[4,7], xlfEnvQ, xQ=#[-1,1], cut, filtEnvQ, reson,
	l1=#[0,0,0,0], l2=#[1,1,1,1], l3=#[0.5,0.25,0.5,0.25], l4=#[0.125,0.5,0.25,0.5], l5=#[0.5,0.5,0.5,0.5], l6=#[0,1,0,1],
        t1=#[0.01,0.02,0.1,0.5], t2=#[4,3,2,1], t3=#[1,2,3,4], t4=#[2,1.5,1,0.5], t5=#[8,6,4,2],
        c1=#[0,0,0,0], c2=#[0,0,0,0], c3=#[0,0,0,0], c4=#[0,0,0,0], c5=#[0,0,0,0],
      	relP, loopP, offset=1;
        var envelope, killEnvelope, signal, signalF, envp, bufpos, xfade, detSig, notesli, modwLfo;

	killGate = killGate + Impulse.kr(0); 
	killEnvelope = EnvGen.kr(envelope: Env.asr( 0, 1, 0.05), gate: killGate, doneAction: Done.freeSelf);
			
	envp = Env.new([l1,l2,l3,l4,l5,l6],[t1,t2,t3,t4,t5],[c1,c2,c3,c4,c5],relP,loopP,offset);
	envelope = EnvGen.kr(envelope: envp, gate: gate, doneAction: [Done.freeSelf,0,0,0]);
			
    	modwLfo = 1-LFPar.kr(modw*modwF).unipolar(modw);
    	detSig = ((detQ*[0,1,2] * modwLfo) + LFNoise2.kr(lfdetF!6).bipolar(lfdetQ*modwLfo)).midiratio;
    	notesli = XLine.kr(prevnote, note, slideT);
     	bufpos = buf + envelope[1..2].range(Lag.kr(waveStart,0.05),abs(Lag.kr(waveEnd,0.05)-lfEnvQ)) + LFNoise2.kr(lfwaveF).unipolar(lfEnvQ);
     	xfade = envelope[3].bipolar((1-xlfEnvQ)*xQ) + LFNoise2.kr(lfxF).bipolar(xlfEnvQ*xQ);
     	
    	signal = LinXFade2.ar(VOsc.ar(bufpos[0], notesli.midicps * detSig * pitchBendRatio), VOsc.ar(bufpos[1], (notesli+offsetnote).midicps * detSig * pitchBendRatio), xfade);
    	signal = Splay.ar(signal) * envelope[0] * amp * 0.125;
    	signalF = RLPF.ar(signal,(Lag.kr(0.618 + note + cut, 0.05) + envelope[0].range(0, filtEnvQ*amp)).midicps * modwLfo, reson);
    	signal = LinXFade2.ar(signal, signalF, xfilt);
        Out.ar(out, signal);
	}).add;

		// Commands

		// noteOn(id, freq, vel)
		this.addCommand(\noteOn, "iff", { arg msg;
			var id = msg[1], note = msg[2], vel = msg[3];
			var voiceToRemove, newVoice;

			// Remove voice if ID matches or there are too many
			voiceToRemove = voiceList.detect{arg item; item.id == id};
			if(voiceToRemove.isNil && (voiceList.size >= maxNumVoices), {
				voiceToRemove = voiceList.detect{arg v; v.gate == 0};
				if(voiceToRemove.isNil, {
					voiceToRemove = voiceList.last;
				});
			});
			if(voiceToRemove.notNil, {
			  voiceToRemove.theSynth.set(\gate, 0);
				voiceToRemove.theSynth.set(\killGate, 0);
				voiceList.remove(voiceToRemove);
			});

			// Add new voice
			context.server.makeBundle(nil, {
		   	newVoice = (id: id, theSynth: Synth.new(defName: \BidiWave, args: [
		  		\buf, buf,
		  		\note, note,
		  		\offsetnote, offsetnote,
	  			\prevnote, prevnote,
	  			\slideT, slideT,
	  			\pitchBendRatio, pitchBendRatio,
	  			\modwF, modwF,
	  			\gate, 1,
	  			\amp, vel.linlin(0, 1, 1-velQ, 1),
	  			\cut, cut,
	  			\reson, reson,
	  			\xfilt, xfilt,
	  			\detQ, detQ, 
	  			\lfdetF, lfdetF, 
	  			\lfdetQ, lfdetQ,
	  			\cut, cut,
	  			\filtEnvQ, filtEnvQ,
	  			\reson, reson,
	  			\lfwaveF, lfwaveF,
	  			\lfEnvQ, lfEnvQ,
	  			\lfxF, lfxF,
	  			\xlfEnvQ, xlfEnvQ,
	  			\waveStart, waveStart,
	  			\waveEnd, waveEnd,
		  		\l1, l1,
	  			\l2, l2,
		  		\l3, l3,
		  		\l4, l4,
		  		\l5, l5,
		  		\l6, l6,
		  		\t1, t1,
		  		\t2, t2,
		  		\t3, t3,
		  		\t4, t4,
		  		\t5, t5,
		  		\c1, c1,
		  		\c2, c2,
		  		\c3, c3,
		  		\c4, c4,
		  		\c5, c5,
		  		\relP, relP,
		  		\loopP, loopP,
		  		\offset, offset
		  	], target: voiceGroup).onFree({ voiceList.remove(newVoice); }), gate: 1);
		  	voiceList.addFirst(newVoice);
		  	prevnote = note;
		  });
		});

		// noteOff(id)
		this.addCommand(\noteOff, "i", { arg msg;
			var voice = voiceList.detect{arg v; v.id == msg[1]};
			if(voice.notNil, {
				voice.theSynth.set(\gate, 0);
				voice.gate = 0;
			});
		});

		// noteOffAll()
		this.addCommand(\noteOffAll, "", { arg msg;
			voiceGroup.set(\gate, 0);
			voiceList.do({ arg v; v.gate = 0; });
		});

		// noteKill(id)
		this.addCommand(\noteKill, "i", { arg msg;
			var voice = voiceList.detect{arg v; v.id == msg[1]};
			if(voice.notNil, {
				voice.theSynth.set(\killGate, 0);
				voiceList.remove(voice);
			});
		});

		// noteKillAll()
		this.addCommand(\noteKillAll, "", { arg msg;
			voiceGroup.set(\killGate, 0);
			voiceList.clear;
		});
				
		// velQ(ratio)
		this.addCommand(\velQ, "f", { arg msg;
			velQ = msg[1];
		});

		// pitchBend(ratio)
		this.addCommand(\pitchBend, "f", { arg msg;
			pitchBendRatio = msg[1];
			voiceGroup.set(\pitchBendRatio, pitchBendRatio);
		});

		// modwheel(timbre)
		this.addCommand(\modwheel, "f", { arg msg;
			modwheel = msg[1];
			voiceGroup.set(\modw, modwheel);
		});
		
		// modwheelLfoFreq(hz)
		this.addCommand(\modwheelLfoFreq, "f", { arg msg;
			modwF = msg[1];
			voiceGroup.set(\modwF, modwF);
		});
		
	  // assignWave(id,path)
		this.addCommand(\assignWave, "is", { arg msg;
		  var idbu = msg[1], pt = msg[2].asString;
      wload.value(idbu,pt);
      wbuff[idbu].loadCollection(warray[idbu]);
    });
    
    // envL(id, target, value)
		this.addCommand(\envL, "iif", { arg msg;
		  var id = msg[2]-1;
		  switch(msg[1])
        {1} {
          l1[id]=msg[3];
          } 
        {2} {
          l2[id]=msg[3];
          } 
        {3} {
          l3[id]=msg[3];
          } 
        {4} {
          l4[id]=msg[3];
          } 
        {5} {
          l5[id]=msg[3];
          }           
        {6} {
          l6[id]=msg[3];
          };
		});
		
		// envT(id, target, value)
		this.addCommand(\envT, "iif", { arg msg;
		  var id = msg[2]-1;
		  switch(msg[1])
        {1} {
          t1[id]=msg[3];
          } 
        {2} {
          t2[id]=msg[3];
          } 
        {3} {
          t3[id]=msg[3];
          } 
        {4} {
          t4[id]=msg[3];
          } 
        {5} {
          t5[id]=msg[3];
          };
		});
		
		// envC(id, target, value)
		this.addCommand(\envC, "iif", { arg msg;
		  var id = msg[2]-1;
		  switch(msg[1])
        {1} {
          c1[id]=msg[3];
          } 
        {2} {
          c2[id]=msg[3];
          } 
        {3} {
          c3[id]=msg[3];
          } 
        {4} {
          c4[id]=msg[3];
          } 
        {5} {
          c5[id]=msg[3];
          };
		});
		
		// loopPoint(value)
		this.addCommand(\loopPoint, "i", { arg msg;
			loopP = msg[1];
			voiceGroup.set(\loopP, loopP);
		});
		
		// releasePoint(value)
		this.addCommand(\releasePoint, "i", { arg msg;
			relP = msg[1];
			voiceGroup.set(\relP, relP);
		});
		
		// envelopesOffset(value)
		this.addCommand(\envelopesOffset, "f", { arg msg;
			offset = msg[1];
		});
		
		// noteOffset(note)
		this.addCommand(\noteOffset, "f", { arg msg;
			offsetnote = msg[1];
			voiceGroup.set(\offsetnote, offsetnote);
		});
		
		// detuneQ(value)
		this.addCommand(\detuneQ, "f", { arg msg;
			detQ = msg[1];
			voiceGroup.set(\detQ, detQ);
		});
		
		// detuneLfoF(value)
		this.addCommand(\detuneLfoF, "f", { arg msg;
			lfdetF = msg[1];
			voiceGroup.set(\lfdetF, lfdetF);
		});

		// detuneLfoQ(value)
		this.addCommand(\detuneLfoQ, "f", { arg msg;
			lfdetQ = msg[1];
			voiceGroup.set(\lfdetQ, lfdetQ);
		});
		
		// filtCut(note)
		this.addCommand(\filtCut, "f", { arg msg;
			cut = msg[1];
			voiceGroup.set(\cut, cut);
		});
		
		// filtEnvQ(value)
		this.addCommand(\filtEnvQ, "f", { arg msg;
			filtEnvQ = msg[1];
			voiceGroup.set(\filtEnvQ, filtEnvQ);
		});
		
		// filtRes(value)
		this.addCommand(\filtRes, "f", { arg msg;
			reson = msg[1];
			voiceGroup.set(\reson, reson);
		});
		
		// filtMix(value)
		this.addCommand(\filtMix, "f", { arg msg;
			xfilt = msg[1];
			voiceGroup.set(\xfilt, xfilt);
		});

		// lfoWavesFreq(freq,freq)
		this.addCommand(\lfoWavesFreq, "ff", { arg msg;
			lfwaveF = [msg[1],msg[2]];
			voiceGroup.set(\lfwaveF, lfwaveF);
		});
		
		// lfoEnvWavesBalance(value,value)
		this.addCommand(\lfoEnvWavesBalance, "ff", { arg msg;
			lfEnvQ = [msg[1],msg[2]];
			voiceGroup.set(\lfEnvQ, lfEnvQ);
		});
		
		// lfoXFreq(freq)
		this.addCommand(\lfoXFreq, "f", { arg msg;
			lfxF = msg[1];
			voiceGroup.set(\lfxF, lfxF);
		});
		
		// lfoXBalance(value)
		this.addCommand(\lfoXBalance, "f", { arg msg;
			xlfEnvQ = msg[1];
			voiceGroup.set(\xlfEnvQ, xlfEnvQ);
		});
		
		// crossWavesQ(value,value)
		this.addCommand(\crossWavesQ, "ff", { arg msg;
			xQ = [msg[1],msg[1]];
			voiceGroup.set(\xQ, xQ);
		});
		
		// waveStart(value,value)
		this.addCommand(\waveStart, "ff", { arg msg;
			waveStart = [msg[1],msg[2]];
			voiceGroup.set(\waveStart, waveStart);
		});
		
		// waveEnd(value,value)
		this.addCommand(\waveEnd, "ff", { arg msg;
			waveEnd = [msg[1],msg[2]];
			voiceGroup.set(\waveEnd, waveEnd);
		});
		
		// portam(value)
		this.addCommand(\portam, "f", { arg msg;
			slideT = msg[1];
			voiceGroup.set(\slideT, slideT);
		});

	}

	free {
		voiceGroup.free;
	}
}
