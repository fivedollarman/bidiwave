# bidiwave
wavetable synth for monome norns

https://youtu.be/ab8NMI8u-go

# requirments
norns, MIDI

# documentation
enc 1 -> change pages (hello, MIDI, wavetables, envelopes, modulations)<br>
key 2 and key 3 -> navigate page sections <br>
enc 2 -> select value <br>
enc 3 -> change value <br>

<b>hello page</b>
key 1 save and key 2 load the preset numer chosen with enc 2. 
With enc 3 you can navigate through wavetables while playing, a really nice one knob feature.

<b>MIDI page</b>
On the first section you can select velocity sensitivity, portamento in seconds, itch bend range in semitones and modwheel controlled lfo speed maximum.
On the second section you can activate an arpeggiator in three modes, "play" iterates in the order you play notes, up goes up and down goes on its way too. With "freez" the arpeggio continue plaing in background, if select it while playing.
You can select an action (octave up or step skip) the arpeggiator does every n cycles and another action the arpeggiator does every n steps (skip step or muting), so it's a little algo style arpeggiator.

<b>wtables page</b>
The synth use envelopes to interpolate between the eight wavetables you choose in this page, in the square you can set in order wave 1 table start and table end and wave 2 table start and end.
You can add your own waves, they have to be .wav audiofiles made by 512 samples and have to be placed in “wavetable” folder.

<b>envelopes page</b>
There are 4 envelopes, one for control amplitude and filter cut, two for navigate through the waves tables and the fourth is a fade between the two waves.
In the first line with enc 2 you can choose the envelope to show and edit, with enc 2 you can activate or deactivate editing. Every change in parameters will update the values of the active envelopes (the bright ones), it's done for fast editing in so much parameters.
At the end you can choose with enc 2 and 3 the loop and release points.

<b>modulation page</b>
Here add multi oscillators detune, similar to superwave, "nF" are random amplitudes lfos frequency and "/" destination q, it may be table interpolation, crossfading or detune q. There's a lowpass resonant filter too. Just listen what happen and enjoy.

# installation
Install from Matron: <code>;install https://github.com/fivedollarman/bidiwave</code>

# notes
The very first time you open it you have to set envelopes 

