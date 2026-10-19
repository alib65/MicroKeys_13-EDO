(
s.boot;
s.waitForBoot {
	SynthDef(\edoTone, { |freq = 130.81, amp = 0.1, pan = 0, decay = 0.7|
		var env = EnvGen.kr(Env.perc(0.01, decay, 1, -4), doneAction: 2);
		var strikeEnv = EnvGen.kr(Env.perc(0.001, 0.018));
		var strike = BPF.ar(PinkNoise.ar, (freq * 5).clip(1000, 8000), 0.7) * strikeEnv;
		var strings = SinOsc.ar(freq) * 0.72
			+ SinOsc.ar(freq * 2.003) * 0.24
			+ SinOsc.ar(freq * 3.009) * 0.12
			+ SinOsc.ar(freq * 4.019) * 0.06
			+ SinOsc.ar(freq * 5.04) * 0.025
			+ SinOsc.ar(freq * 1.002) * 0.12;
		var tone = strings + (strike * 0.2);
		Out.ar(0, Pan2.ar(LeakDC.ar(tone) * env * amp, pan));
	}).add;

	SynthDef(\edoLead, { |freq = 261.63, amp = 0.13, gate = 1|
		var env = EnvGen.kr(Env.asr(0.02, 1, 0.08), gate, doneAction: 2);
		var strikeEnv = EnvGen.kr(Env.perc(0.001, 0.018));
		var strike = BPF.ar(PinkNoise.ar, (freq * 5).clip(1000, 8000), 0.7) * strikeEnv;
		var strings = SinOsc.ar(freq) * 0.72
			+ SinOsc.ar(freq * 2.003) * 0.24
			+ SinOsc.ar(freq * 3.009) * 0.12
			+ SinOsc.ar(freq * 4.019) * 0.06
			+ SinOsc.ar(freq * 5.04) * 0.025
			+ SinOsc.ar(freq * 1.002) * 0.12;
		var tone = strings + (strike * 0.2);
		Out.ar(0, Pan2.ar(LeakDC.ar(tone) * env * amp, 0));
	}).add;

	s.sync;
	{
		var window, tonicMenu, harmonyMenu, meterMenu, tempoSlider, tempoLabel;
		var playButton, clearButton, degreeBoxes, progressionInfo, nowInfo;
		var melodyView, melodyInfo, scaleInfo;
		var updateMelody, playHarmony, setTonic, updateProgressionInfo;
		var showNote, isPressed, keyNoteOn, keyNoteOff, updateKeyInfo;

		~tonicStep = 0;
		~harmonySteps = [2, 4, 5, 8];
		~selectedHarmony = 1;
		~progression = List[];
		~bpm = 84;
		~accompOn = false;
		~melodySynth = nil;

		// Each bar is split into groups; the first pulse of a group plays a bass note,
		// the remaining pulses play the chord. BPM always refers to the quarter note.
		~meters = [
			(label: "2/4", groups: [2], unit: 4),
			(label: "3/4", groups: [3], unit: 4),
			(label: "4/4", groups: [2, 2], unit: 4),
			(label: "5/4", groups: [3, 2], unit: 4),
			(label: "6/8", groups: [3, 3], unit: 8),
			(label: "7/8", groups: [2, 2, 3], unit: 8),
			(label: "9/8", groups: [3, 3, 3], unit: 8),
			(label: "11/8", groups: [3, 3, 3, 2], unit: 8),
			(label: "12/8", groups: [3, 3, 3, 3], unit: 8)
		];
		~meterIndex = 2;

		~frequency = { |octave, degree|
			65.406391 * (2 ** ((~tonicStep + (octave * 13) + degree) / 13));
		};

		window = Window("13-EDO | Left Hand + Melody", Rect(120, 120, 800, 640)).front;
		window.view.decorator = FlowLayout(window.view.bounds, 14@12, 8@8);

		StaticText(window, 770@30)
			.string_("13-EDO PIANO | Left-hand chord loop and a mouse / computer-keyboard melody")
			.font_(Font("Helvetica", 17));

		StaticText(window, 90@24).string_("Tonic (C4 base)");
		tonicMenu = PopUpMenu(window, 160@24)
			.items_(["C", "C +1", "C +2", "C +3", "C +4", "C +5", "C +6", "C +7", "C +8", "C +9", "C +10", "C +11", "C +12"]);

		StaticText(window, 70@24).string_("Harmony");
		harmonyMenu = PopUpMenu(window, 210@24)
			.items_(["2nd  |  2 steps", "3rd  |  4 steps", "4th  |  5 steps", "5th  |  8 steps"])
			.value_(1);

		StaticText(window, 50@24).string_("Meter");
		meterMenu = PopUpMenu(window, 110@24)
			.items_(~meters.collect { |meter| meter[\label] })
			.value_(~meterIndex);

		playButton = Button(window, 130@28)
			.states_([["Start left hand"], ["Stop left hand"]]);

		StaticText(window, 65@24).string_("Tempo");
		tempoSlider = Slider(window, 170@24).value_(0.24);
		tempoLabel = StaticText(window, 70@24).string_("84 BPM");

		StaticText(window, 770@22)
			.string_("Chord loop: tick degrees in the order you want them played (one chord per bar)")
			.font_(Font("Helvetica", 13));

		degreeBoxes = 13.collect { |index|
			CheckBox(window, 51@24).string_((index + 1).asString);
		};

		progressionInfo = StaticText(window, 600@24)
			.font_(Font("Helvetica", 14));
		clearButton = Button(window, 100@24).states_([["Clear"]]);

		nowInfo = StaticText(window, 770@24)
			.string_("Now: stopped")
			.font_(Font("Helvetica", 14));

		scaleInfo = StaticText(window, 770@24)
			.string_("")
			.font_(Font("Helvetica", 12));

		melodyInfo = StaticText(window, 770@28)
			.string_("Melody: click and drag to play")
			.font_(Font("Helvetica", 14));

		melodyView = UserView(window, 770@260)
			.background_(Color.new(0.09, 0.12, 0.16));

		// Degrees 1, 3, 5, 7, 9, 11 and 13 of each octave are white keys; the rest are black.
		~whiteDegrees = [1, 3, 5, 7, 9, 11, 13];
		~mouseStep = nil;
		~keyNotes = Dictionary.new;
		~keyOctave = 0;
		// Computer keys for degrees 1-13.
		~keyDegrees = Dictionary[
			$a -> 1, $w -> 2, $s -> 3, $e -> 4, $d -> 5, $r -> 6, $f -> 7,
			$t -> 8, $g -> 9, $y -> 10, $h -> 11, $u -> 12, $j -> 13
		];

		isPressed = { |step|
			step == ~mouseStep or: { ~keyNotes.values.any { |note| note[\step] == step } }
		};

		melodyView.drawFunc_({ |view|
			var width = view.bounds.width;
			var height = view.bounds.height;
			var keyWidth = width / 27;
			27.do { |step|
				var degree = (step % 13) + 1;
				var isWhite = ~whiteDegrees.includes(degree);
				var rect = Rect(step * keyWidth, 0, keyWidth, height);
				Pen.fillColor = case
					{ isPressed.value(step + (~keyOctave * 13)) } { Color.new(0.82, 0.72, 0.43) }
					{ isWhite } { Color.new(0.95, 0.94, 0.9) }
					{ Color.new(0.1, 0.1, 0.12) };
				Pen.fillRect(rect);
				Pen.strokeColor = Color.new(0.35, 0.35, 0.38);
				Pen.width = 1;
				Pen.strokeRect(rect);
				Pen.stringCenteredIn(
					degree.asString,
					Rect(rect.left, height - 28, keyWidth, 20),
					Font("Helvetica", 11),
					if(isWhite or: { isPressed.value(step + (~keyOctave * 13)) }, { Color.black }, { Color.new(0.85, 0.85, 0.85) })
				);
			};
			// Gold lines mark each octave of the tonic.
			[0, 13, 26].do { |step|
				Pen.strokeColor = Color.new(0.82, 0.72, 0.43);
				Pen.width = 3;
				Pen.moveTo((step * keyWidth)@0);
				Pen.lineTo((step * keyWidth)@height);
				Pen.stroke;
			};
		});

		updateProgressionInfo = {
			progressionInfo.string = if(~progression.isEmpty, {
				"Loop: (nothing ticked, plays degree 1)"
			}, {
				"Loop: " ++ ~progression.collect(_.asString).join("  >  ")
			});
		};
		updateProgressionInfo.value;

		setTonic = { |step|
			~tonicStep = step;
			if(~melodySynth.notNil) {
				updateMelody.value(melodyView.bounds.width * 0.5);
			};
		};

		showNote = { |step|
			melodyInfo.string = "Degree %  |  +% cents  |  % Hz".format(
				(step % 13) + 1,
				(step * (1200 / 13)).round(0.1),
				~frequency.value(2, step).round(0.1)
			);
		};

		updateMelody = { |x|
			// The lane shows two octaves starting at the current keyboard octave.
			var step = ((x / melodyView.bounds.width.max(1)) * 27).floor.clip(0, 26) + (~keyOctave * 13);
			if(~melodySynth.notNil) {
				~melodySynth.set(\freq, ~frequency.value(2, step));
			};
			if(step != ~mouseStep) {
				~mouseStep = step;
				melodyView.refresh;
			};
			showNote.value(step);
		};

		updateKeyInfo = {
			scaleInfo.string = "13 steps per octave, 92.31 cents each | Keys: a w s e d r f t g y h u j = degrees 1-13 | z / x = octave down / up (now %)".format(
				if(~keyOctave > 0, { "+" ++ ~keyOctave }, { ~keyOctave.asString })
			);
		};
		updateKeyInfo.value;

		// A key-up is confirmed after a short delay, so the OS key auto-repeat
		// (which can send up/down pairs) does not re-strike a held note.
		keyNoteOn = { |char, degree|
			var note = ~keyNotes[char];
			if(note.notNil, {
				note[\releaseId] = nil;
			}, {
				var step = (~keyOctave * 13) + degree - 1;
				~keyNotes[char] = (
					step: step,
					synth: Synth(\edoLead, [\freq, ~frequency.value(2, step)]),
					releaseId: nil
				);
				showNote.value(step);
				melodyView.refresh;
			});
		};

		keyNoteOff = { |char|
			var note = ~keyNotes[char];
			var releaseId = UniqueID.next;
			if(note.notNil) {
				note[\releaseId] = releaseId;
				AppClock.sched(0.04, {
					if(~keyNotes[char] === note and: { note[\releaseId] == releaseId }) {
						note[\synth].set(\gate, 0);
						~keyNotes.removeAt(char);
						melodyView.refresh;
					};
					nil
				});
			};
		};

		playHarmony = { |root, decay, amp|
			var interval = ~harmonySteps[~selectedHarmony];
			3.do { |voice|
				Synth(\edoTone, [
					\freq, ~frequency.value(1, root + (interval * voice)),
					\amp, amp,
					\decay, decay
				]);
			};
		};

		tonicMenu.action_({ |menu| setTonic.value(menu.value); });
		harmonyMenu.action_({ |menu| ~selectedHarmony = menu.value; });
		meterMenu.action_({ |menu| ~meterIndex = menu.value; });
		tempoSlider.action_({ |slider|
			~bpm = (60 + (slider.value * 100)).round(1);
			tempoLabel.string = "% BPM".format(~bpm);
		});

		degreeBoxes.do { |box, index|
			box.action_({ |checkBox|
				var degree = index + 1;
				if(checkBox.value, {
					~progression.add(degree);
				}, {
					~progression.remove(degree);
				});
				updateProgressionInfo.value;
			});
		};

		clearButton.action_({
			degreeBoxes.do { |box| box.value = false };
			~progression.clear;
			updateProgressionInfo.value;
		});

		playButton.action_({ |button|
			~accompOn = button.value == 1;
		});

		window.view.keyDownAction_({ |view, char, modifiers|
			var key = char.toLower;
			var degree = ~keyDegrees[key];
			case
				{ modifiers.isCmd or: { modifiers.isCtrl } } { nil }
				{ degree.notNil } { keyNoteOn.value(key, degree); true }
				{ key == $z } { ~keyOctave = (~keyOctave - 1).max(-2); updateKeyInfo.value; melodyView.refresh; true }
				{ key == $x } { ~keyOctave = (~keyOctave + 1).min(2); updateKeyInfo.value; melodyView.refresh; true }
				{ nil };
		});
		window.view.keyUpAction_({ |view, char, modifiers|
			var key = char.toLower;
			if(~keyDegrees[key].notNil) { keyNoteOff.value(key); true };
		});

		// Keep keyboard focus off the controls so letter keys always reach the instrument.
		[tonicMenu, harmonyMenu, meterMenu, playButton, clearButton, tempoSlider].do { |control|
			control.canFocus = false;
		};
		degreeBoxes.do { |box| box.canFocus = false };
		melodyView.canFocus = true;
		melodyView.focus(true);

		melodyView.mouseDownAction_({ |view, x, y|
			view.focus(true);
			updateMelody.value(x);
			~melodySynth = Synth(\edoLead, [\freq, ~frequency.value(2, ~mouseStep)]);
		});
		melodyView.mouseMoveAction_({ |view, x, y|
			if(~melodySynth.notNil) { updateMelody.value(x); };
		});
		melodyView.mouseUpAction_({ |view, x, y|
			if(~melodySynth.notNil) {
				~melodySynth.set(\gate, 0);
				~melodySynth = nil;
			};
			~mouseStep = nil;
			melodyView.refresh;
		});

		~accompRoutine = Routine({
			var pulse = 0, bar = 0;
			loop {
				var meter = ~meters[~meterIndex];
				var starts = [0] ++ meter[\groups].integrate.drop(-1);
				var pulseDur = (60 / ~bpm) * (4 / meter[\unit]);
				if(pulse >= meter[\groups].sum) {
					pulse = 0;
					bar = bar + 1;
				};
				if(~accompOn, {
					var degree = if(~progression.isEmpty, { 1 }, { ~progression.wrapAt(bar) });
					var root = degree - 1;
					var group = starts.indexOf(pulse);
					if(pulse == 0) {
						var slot = if(~progression.isEmpty, { 1 }, { bar % ~progression.size + 1 });
						var count = ~progression.size.max(1);
						{
							nowInfo.string = "Now: degree %  |  chord % of %  |  %".format(
								degree, slot, count, meter[\label]
							);
						}.defer;
					};
					if(group.notNil, {
						// Bass on group starts: root on the downbeat, alternating with the fifth.
						var bass = if(group.odd, { root + (~harmonySteps[~selectedHarmony] * 2) }, { root });
						Synth(\edoTone, [
							\freq, ~frequency.value(0, bass),
							\amp, if(pulse == 0, { 0.22 }, { 0.16 }),
							\decay, pulseDur * 0.8
						]);
					}, {
						playHarmony.value(root, pulseDur * 0.9, 0.075);
					});
					pulse = pulse + 1;
				}, {
					if(pulse != 0 or: { bar != 0 }) {
						{ nowInfo.string = "Now: stopped" }.defer;
					};
					pulse = 0;
					bar = 0;
				});
				pulseDur.wait;
			};
		}).play;

		window.onClose_({
			~accompRoutine.stop;
			if(~melodySynth.notNil) { ~melodySynth.set(\gate, 0); };
			~keyNotes.do { |note| note[\synth].set(\gate, 0) };
		});
	}.defer;
};
)
