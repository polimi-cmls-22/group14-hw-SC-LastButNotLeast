// ***** Initialization (Execute First) ***** //

(
// --- GUI Classes Installation --- //
Quarks.clear;
~folderPath = "./";
Quarks.install(~folderPath);

// --- Server Initialization --- //
Server.killAll;

// Changes server default options to use external audio card
o = Server.default.options;
o.inDevice_("ASIO : Focusrite USB ASIO");
o.outDevice_("ASIO : Focusrite USB ASIO");
s.reboot;
s.doWhenBooted(onComplete: {

// ----- Synthetizers Definitions ----- //

// --- Octavers Synths Definition --- //
// - RM Octaver Synth - //
// args:
// - amp1: gain of (-2) octave
// - amp2: gain of (-1) octave
// - amp3: gain of (+1) octave
// - amp4: gain of (+2) octave
// - ampDry: gain of the dry input
// - busOut: output bus of the Synth
SynthDef.new(\RmOctaver , {
	arg amp1, amp2, amp3, amp4, ampDry, busOut, channelIn = 0;
	var in, an, freq;
	// Reads input
	in = SoundIn.ar(channelIn); // reads audio from input bus
	an = Pitch.kr(in);  // finds input signal's frequency
	freq = an[0];       // gets the frequency from the Array[frequency, boolean]

	// Writes on specified output bus
	Out.ar(busOut, Mix.new([
		SinOsc.ar(freq: 0.75*freq, mul: amp1)*in,            // octave (-2)
		SinOsc.ar(freq: 0.5*freq, mul: amp2)*in + (amp2*in), // octave (-1)
		SinOsc.ar(freq: 2*freq, mul: amp3)*in,               // octave (+1)
		SinOsc.ar(freq: 4*freq, mul: amp4)*in,               // octave (+2)
		ampDry * in;
	]));
}).add;

// - Polyphonic Octaver Synth - //
// args:
// - amp1: gain of (-2) octave
// - amp2: gain of (-1) octave
// - amp3: gain of (+1) octave
// - amp4: gain of (+2) octave
// - ampDry: gain of the dry input
// - busOut: output bus of the Synth
// - t1: time dispersion of (-2) octave
// - t2: time dispersion of (-1) octave
// - t3: time dispersion of (+1) octave
// - t4: time dispersion of (+2) octave
SynthDef.new(\PitchShiftOctaver , {
arg amp1, amp2, amp3, amp4, ampDry, busOut, channelIn = 0,
	t1 = 0.001, t2 = 0.001, t3 = 0.001, t4 = 0.001;
var sig1,sig2,sig3,sig4;
	sig1 = PitchShift.ar( // octave(-2)
        SoundIn.ar(channelIn), // audio from input bus
        0.4,           // grain size
        0.25,          // frequency multiplier
		0,             // pitch dispersion (=0)
        t1,            // time dispersion
		amp1           // gain
	);

   sig2 =  PitchShift.ar( // octave(-1)
        SoundIn.ar(channelIn), // audio from input bus
        0.4,           // grain size
        0.5,           // frequency multiplier
        0,             // pitch dispersion
        t2,            // time dispersion
		amp2           // gain
	);

    sig3 = PitchShift.ar( // octave(+1)
        SoundIn.ar(channelIn), // audio from input bus
        0.05,          // grain size
		2,             // frequency multiplier
        0,             // pitch dispersion
        t3,            // time dispersion
		amp3           // gain
	);

	sig4 = PitchShift.ar( // octave(+2)
        SoundIn.ar(channelIn), // audio from input bus
        0.05,          // grain size
        4,             // frequency multiplier
        0,             // pitch dispersion
        t4,            // time dispersion
		amp4           // gain
	);
	// Writes on specified output bus
	Out.ar(busOut, Mix.new([sig1, sig2, sig3, sig4, ampDry*SoundIn.ar(channelIn)]));
}).add;

// --- Effects Synths Definition --- //
// - Reverb - //
// args:
// - wetR: gain of the effect
// - room: room parameter of the effect
// - damp: damp parameter of the effect
// - busIn: input bus of the Synth
SynthDef.new(\Reverb,{
	arg wetR = 0, room = 0.1, damp = 0.1, busIn;
	var input,out;
	input=In.ar(busIn);

	out=FreeVerb.ar(input,1, room,damp);
	Out.ar([0, 1], out*wetR);
	Out.ar([0, 1], input);
}).add;

// - Delay - //
// args:
// - wet: gain of the effect
// - delayTime: delay time parameter of the effect
// - feedbacks: feedbacks parameter of the effect
// - busIn: input bus of the Synth
// var:
// - h: allocated buffer used to create the effect
SynthDef.new(\Delay,{
	arg wet = 0, delayTime = 0.1,feedbacks = 0.1, busIn,busOut;
	var input,out, h = Buffer.alloc(s,s.sampleRate*2,2);
	input=In.ar(busIn);
	out=PingPong.ar(h, [input,input], delayTime, feedbacks, rotate:0);

	Out.ar(busOut, out*wet);
	Out.ar(busOut, input);
}).add;
});
)

// ***** Main Code ***** //
(
// --- Variables Definition --- //
var sOctave, sReverb, sDelay, octaveChange, changeReverb, changeDelay,
    ampOctavesArray = Array.new(maxSize: 4), ampDry, tdArray = Array.new(maxSize: 4);

ampOctavesArray.add(0); // Array initialization
ampOctavesArray.add(0);
ampOctavesArray.add(0);
ampOctavesArray.add(0);
ampDry = 0;

tdArray.add(0.004); // Array initialization
tdArray.add(0.004);
tdArray.add(0.004);
tdArray.add(0.004);

// --- Main Code --- //
~myBus = Bus.audio(s, 2); // created secondary busses
~effectBus = Bus.audio(s,2);
~range = 3; // Multiplication factor of the gain
~inputChannel = 0;

// - Functions to change the octaves gains - //
~s1ChangeAmp = { arg p;
	ampOctavesArray[0] = ~range*p.value;
	sOctave.set(\amp1, ampOctavesArray[0]);
};
~s2ChangeAmp = { arg p;
	ampOctavesArray[1] = ~range*p.value;
	sOctave.set(\amp2, ampOctavesArray[1]);
};
~s3ChangeAmp = { arg p;
	ampOctavesArray[2] = ~range*p.value;
	sOctave.set(\amp3, ampOctavesArray[2]);
};
~s4ChangeAmp = { arg p;
	ampOctavesArray[3] = ~range*p.value;
	sOctave.set(\amp4, ampOctavesArray[3]);
};

// - Functions to change the octaves time dispersion (polyphonic octaver) - //
~changet1 = { arg p;
	tdArray[0] = p.value;
	sOctave.set(\t1, tdArray[0]);
};

~changet2 = { arg p;
	tdArray[1] = p.value;
	sOctave.set(\t2, tdArray[1]);
};

~changet3 = { arg p;
	tdArray[2] = p.value;
	sOctave.set(\t3, tdArray[2]);
};

~changet4 = { arg p;
	tdArray[3] = p.value;
	sOctave.set(\t4, tdArray[3]);
};

// - Function to change dry gain - //
~dryChangeAmp = { arg p;
	ampDry = ~range*p.value;
	sOctave.set(\ampDry, ampDry);
};

// - Function to change the octaver type - //
~changeOctaver = { arg p;
	if(p.value == 1, {
		sOctave.run(false);
		sOctave.free;
		sOctave = Synth.new("RmOctaver", [\busOut, ~myBus, \ampDry, ampDry,
			\amp1, ampOctavesArray[0], \amp2, ampOctavesArray[1],
			\amp3, ampOctavesArray[2], \amp4, ampOctavesArray[3],
			\channelIn, ~inputChannel
		]);
	}, {
		sOctave.run(false);
		sOctave.free;
		sOctave = Synth.new("PitchShiftOctaver", [\busOut, ~myBus, \ampDry, ampDry,
			\amp1, ampOctavesArray[0], \amp2, ampOctavesArray[1],
			\amp3, ampOctavesArray[2], \amp4, ampOctavesArray[3],
			\t1, tdArray[0], \t2, tdArray[1], \t3, tdArray[2], \t4, tdArray[4],
			\channelIn, ~inputChannel
		]);
	});

};

// - Functions to change reverb effect parameters - //
~changeReverbWet = { arg p;
	sReverb.set(\wetR, p.value);
};

~changeReverbRoom = { arg p;
	sReverb.set(\room, p.value);
};

~changeReverbDamp = { arg p;
	sReverb.set(\damp, p.value);
};

// - Functions to change delay effect parameters - //
~changeDelayWet = { arg p;
	sDelay.set(\wet, p.value);
};

~changeDelayTime = { arg p;
	sDelay.set(\delayTime, p.value);
};

~changeDelayFeedbacks = { arg p;
	sDelay.set(\feedbacks, p.value);
};

// - Dictionaries containing functions to be passed onto GUI classes - //
octaveChange = Dictionary[
	"-2" -> [~s1ChangeAmp, ~changet1],
	"-1" -> [~s2ChangeAmp, ~changet2],
	"+1" -> [~s3ChangeAmp, ~changet3],
	"+2" -> [~s4ChangeAmp, ~changet4],
];

changeReverb = Dictionary[
	"WET"  -> ~changeReverbWet,
	"ROOM" -> ~changeReverbRoom,
	"DAMP" -> ~changeReverbDamp,
];

changeDelay = Dictionary[
	"WET"       -> ~changeDelayWet,
	"DTIME"     -> ~changeDelayTime,
	"FEEDBACKS" -> ~changeDelayFeedbacks,
];

// Creation of the synths
sReverb = Synth.new("Reverb", [\busIn, ~effectBus]);
sDelay = Synth.new("Delay", [\busIn, ~myBus,\busOut,~effectBus]);
sOctave = Synth.new("PitchShiftOctaver", [\busOut, ~myBus]);

~inputChanged = {
	|i|
	~inputChannel = i;
	sOctave.set(\channelIn, ~inputChannel);
};

~emergency = {
	|btn|

	if(btn.value == 1, {
		sOctave.run(false);
		sDelay.run(false);
		sReverb.run(false);
	}, {
		sOctave.run(true);
		sDelay.run(true);
		sReverb.run(true);
	});
};

// GUI creation and start of the the program
OctaverPanel.new(
	onReverbChange: changeReverb,
	onDelayChange:  changeDelay,
	onDryChange: ~dryChangeAmp,
	onOctaveChanges: octaveChange,
	onOctaverChange: ~changeOctaver,
	onWindowClose: {'closed'.postln; s.quit;}, // stops the server
	onInputChannelChanged: ~inputChanged,
	onEmergencyBtnClicked: ~emergency,
).render;
)


(
// ServerOptions.devices.dump;
Server.default.options.numInputBusChannels
)