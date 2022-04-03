OctaverPanel {

	var onReverbChange, onDelayChange; // These are variables possibly passed down
	var onDryChange;
	var onOctaveChanges;
	var onOctaverChange;
	var onWindowClose;
	var onInputChannelChanged;
	var onEmergencyBtnClicked;
	var win, childComponents;

	*new {
		arg onReverbChange = nil, onDelayChange = nil, onDryChange = nil, onOctaveChanges = nil, onOctaverChange = nil, onWindowClose = nil, onInputChannelChanged = nil, onEmergencyBtnClicked = nil;

		^super.newCopyArgs(onReverbChange, onDelayChange, onDryChange, onOctaveChanges, onOctaverChange, onWindowClose, onInputChannelChanged, onEmergencyBtnClicked);
	}

	drawOnResize {
		~drawFunc = {
			|view|
			Pen.strokeColor = Color.white;
			~w = view.bounds.right;
			~arrY = Array.fill(11, {|i| view.bounds.height / 10 * i });
			~arrY.do({|y| Pen.line(0@y,~w@y)});
			Pen.stroke;
		};
		win.drawFunc = {
			|p|
			~drawFunc.value(p.bounds);
		};
		win.view.onResize_(win.refresh);
	}

	init {
		win = Window(bounds: Rect.new(width: 600, height: 600)); // assuming this is the top level
		win.onClose = onWindowClose;

		// You can right click and set the different input devices

		~inputDeviceActions = [0, 1].collect({
			|i| MenuAction("Channel " + i.asString, {
					onInputChannelChanged.value(i);
				})
			});
		win.view.setContextMenuActions(
			Menu(*~inputDeviceActions).title_("Select Input Channel"),
		);

		this.drawOnResize;

		// Child components for rendering
		~octaveCbs = if (onOctaveChanges == nil, {Dictionary.new}, {onOctaveChanges}); // so that octaveCbs[i] is always defined
		~octaves = [
			OctaveController(win, "-2", onSlideChange: ~octaveCbs["-2"][0], onKnobChange: ~octaveCbs["-2"][1]),
			OctaveController(win, "-1", onSlideChange: ~octaveCbs["-1"][0], onKnobChange: ~octaveCbs["-1"][1]),
			OctaveController(win, "Dry", onSlideChange: onDryChange, showKnob: false),
			OctaveController(win, "+1", onSlideChange: ~octaveCbs["+1"][0], onKnobChange: ~octaveCbs["+1"][1]),
			OctaveController(win, "+2", onSlideChange: ~octaveCbs["+2"][0], onKnobChange: ~octaveCbs["+2"][1]),
		];
		~octaves[0].setKnobRange(0.001, 0.4, 0.001);
		~octaves[1].setKnobRange(0.001, 0.4, 0.001);
		~octaves[3].setKnobRange(0.001, 0.05, 0.001);
		~octaves[4].setKnobRange(0.001, 0.02, 0.001);

		~modeSelect = ModeButton(win, onValChanges: [
			{
				~octaves.reject({|oct| oct.label.string == "Dry"}).do({|oct| oct.showKnob_(oct.showKnob.not)});
			},
			onOctaverChange
		]);

		~effects = [
			EffectController(win, "REVERB", ["WET", "ROOM", "DAMP"], onReverbChange),
			EffectController(win, "DELAY", ["WET", "DTIME", "FEEDBACKS"], onDelayChange),
		];
		~effects[1].setKnobRange("DTIME", 0.1, 1, 0.1);

		childComponents = ~octaves ++ ~effects;
	}

	render {
		this.init;

		~emergencyBtn = Button(win).states_([["ON"], ["OFF"]]).action_(onEmergencyBtnClicked);
		~title = StaticText(win).string_("LBNL-O").font_(Font("Monaco", 70)).background_(Color.new255(red: 255, green: 213, blue: 135)).align_(\center);
		~grid = GridLayout.rows(
			[[HLayout(~title), columns: childComponents.size - 1], [~emergencyBtn]],
			childComponents.collect({|item, i| [item.render]}),
			[[~modeSelect.render, columns: childComponents.size]],
		);
		~grid.hSpacing = 10;
		win.layout_(~grid);

		win.background_(Color.red);
		win.front;
	}

}

OctaveController {
	var slider, <label, knob;

	*new {
		|
		parent
		tag = ""
		onSlideChange = nil // Callbacks passed down from parents
		onKnobChange = nil
		showKnob = true
		|

		~slider = Slider(parent);
		~label = StaticText(parent);
		~knob = EZKnob(parent);

		~label.string = tag;
		~label.align_(\center);
		~label.stringColor_(Color.white);

		~slider.action_(onSlideChange);
		~slider.value_(0);

		~knob.numberView.visible_(false);
		~knob.knobView.visible_(showKnob);
		~knob.action_(onKnobChange);

		^super.newCopyArgs(~slider, ~label, ~knob);
	}

	showKnob {
		^knob.knobView.visible;
	}

	showKnob_ {
		|val| knob.knobView.visible_(val);
	}

	setKnobRange {
		arg minVal, maxVal, default;

		~knob.controlSpec = ControlSpec.new(minVal, maxVal, default: default);
	}

	render {
		^VLayout(slider, label, knob.knobView);
	}
}

EffectController {
	var label, knobs;

	*new {
		|
		parent
		name = ""
		params = ([])
		callbacks = (Dictionary[])
		|

		~label = StaticText(parent);
		~label.string_(name).stringColor_(Color.white);
		~label.background_(Color.grey).align_(\center).font_("Helvetica-Bold");

		~knobs = params.collect({
			|param|

			~k = EZKnob(parent, label: param).action_(callbacks[param]);
			~k.numberView.visible_(false);
			~k.labelView.stringColor_(Color.white);
			~k.labelView.align_(\center);
			~k;
		});

		^super.newCopyArgs(~label, ~knobs);
	}

	setKnobRange {
		arg param, minVal, maxVal, default;

		knobs.select({|k| k.labelView.string == param}).do({|k| k.controlSpec = ControlSpec.new(minVal, maxVal, default: default)});
	}

	render {
		~knobViews = knobs.collect({|k| VLayout(k.view)});
		^VLayout(label, *~knobViews).spacing_(10);
	}
}

ModeButton {
	var button;

	*new {
		|
		parent,
		onValChanges = nil
		|

		~button = Button(parent);
		~button.states_([["PitchShift"], ["RM Synth"]]);
		~button.mouseUpAction_(onValChanges[0]);
		~button.action_(onValChanges[1]);

		^super.newCopyArgs(~button);
	}

	render {
		^VLayout(button);
	}
}