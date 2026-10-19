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
		var updateMelody, playHarmony, voiceLead, setTonic, updateProgressionInfo;
		var showNote, isPressed, isLeftHand, keyLayout, keyNoteOn, keyNoteOff, updateKeyInfo;

		~tonicStep = 0;
		~harmonySteps = [2, 4, 5, 8];
		~selectedHarmony = 1;
		~progression = List[];
		~bpm = 84;
		~accompOn = false;
		~melodySynth = nil;
		~voicing = nil;

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

		window = Window("MicroKeys - Ali Balighi - 2026", Rect(120, 120, 800, 640)).front;
		window.view.decorator = FlowLayout(window.view.bounds, 14@12, 8@8);

		StaticText(window, 770@30)
			.string_("MicroKeys - Ali Balighi © 2026")
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

		// Keys that sound in the current left-hand chord (any octave) are shown in green.
		isLeftHand = { |step|
			~voicing.notNil and: { ~voicing.any { |voice| (voice - step) % 13 == 0 } }
		};

		// Piano layout for the 27 visible steps: white keys fill the full height side by side,
		// black keys sit on the boundary between their neighbours at 3/4 of a white key's
		// width and length. Whites come first, so the last matching rect is the top one.
		keyLayout = { |width, height|
			var whiteWidth = width / 15;
			var whites = List[], blacks = List[];
			27.do { |step|
				var octave = step div: 13;
				var degree = (step % 13) + 1;
				if(~whiteDegrees.includes(degree), {
					var left = ((octave * 7) + ((degree - 1) / 2)) * whiteWidth;
					whites.add((step: step, white: true, rect: Rect(left, 0, whiteWidth, height)));
				}, {
					var center = ((octave * 7) + (degree / 2)) * whiteWidth;
					var blackWidth = whiteWidth * 0.75;
					blacks.add((step: step, white: false,
						rect: Rect(center - (blackWidth / 2), 0, blackWidth, height * 0.75)));
				});
			};
			whites ++ blacks;
		};

		melodyView.drawFunc_({ |view|
			var width = view.bounds.width;
			var height = view.bounds.height;
			var whiteWidth = width / 15;
			keyLayout.value(width, height).do { |key|
				var step = key[\step];
				var rect = key[\rect];
				var pressed = isPressed.value(step + (~keyOctave * 13));
				var green = isLeftHand.value(step);
				Pen.fillColor = case
					{ pressed } { Color.new(0.82, 0.72, 0.43) }
					{ green and: { key[\white] } } { Color.new(0.55, 0.85, 0.55) }
					{ green } { Color.new(0.12, 0.55, 0.25) }
					{ key[\white] } { Color.new(0.95, 0.94, 0.9) }
					{ Color.new(0.1, 0.1, 0.12) };
				Pen.fillRect(rect);
				Pen.strokeColor = Color.new(0.35, 0.35, 0.38);
				Pen.width = 1;
				Pen.strokeRect(rect);
				Pen.stringCenteredIn(
					((step % 13) + 1).asString,
					Rect(rect.left, rect.bottom - 28, rect.width, 20),
					Font("Helvetica", 11),
					if(key[\white] or: { pressed }, { Color.black }, { Color.new(0.85, 0.85, 0.85) })
				);
			};
			// Gold lines mark each octave of the tonic (left edge of each degree 1 key).
			[0, 7, 14].do { |whiteIndex|
				Pen.strokeColor = Color.new(0.82, 0.72, 0.43);
				Pen.width = 3;
				Pen.moveTo((whiteIndex * whiteWidth)@0);
				Pen.lineTo((whiteIndex * whiteWidth)@height);
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
				~melodySynth.set(\freq, ~frequency.value(2, ~mouseStep));
				showNote.value(~mouseStep);
			};
		};

		showNote = { |step|
			melodyInfo.string = "Degree %  |  +% cents  |  % Hz".format(
				(step % 13) + 1,
				(step * (1200 / 13)).round(0.1),
				~frequency.value(2, step).round(0.1)
			);
		};

		updateMelody = { |x, y|
			// The lane shows two octaves starting at the current keyboard octave.
			var bounds = melodyView.bounds;
			var point = x.clip(0, bounds.width - 1) @ y.clip(0, bounds.height - 1);
			var key = keyLayout.value(bounds.width, bounds.height).reverse.detect { |candidate|
				candidate[\rect].containsPoint(point)
			};
			var step = key[\step] + (~keyOctave * 13);
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

		// Voice leading: each voice of the previous chord moves to the nearest tone of
		// the new chord, so common tones are held and the rest move by the smallest step.
		// The first chord is played in close root position.
		voiceLead = { |root|
			var interval = ~harmonySteps[~selectedHarmony];
			var pitchClasses = 3.collect { |voice| (root + (interval * voice)) % 13 };
			var previous = ~voicing;
			if(previous.isNil, {
				3.collect { |voice| root + (interval * voice) };
			}, {
				var best, bestCost = inf;
				[[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]].do { |perm|
					// Each voice may land on its tone just below or just above where it was.
					8.do { |mask|
						var candidate = 3.collect { |voice|
							var below = previous[voice] - ((previous[voice] - pitchClasses[perm[voice]]) % 13);
							below + (13 * mask.rightShift(voice).bitAnd(1));
						};
						// Smallest total motion wins; leaving the two-octave range is penalised
						// so the voicing does not drift away over a long loop.
						var cost = (candidate - previous).abs.sum
							+ (candidate.collect { |step| (step - 25).max(0) + step.neg.max(0) }.sum * 4);
						if(cost < bestCost) {
							bestCost = cost;
							best = candidate;
						};
					};
				};
				best.sort;
			});
		};

		playHarmony = { |decay, amp|
			~voicing.do { |step|
				Synth(\edoTone, [
					\freq, ~frequency.value(1, step),
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
			updateMelody.value(x, y);
			~melodySynth = Synth(\edoLead, [\freq, ~frequency.value(2, ~mouseStep)]);
		});
		melodyView.mouseMoveAction_({ |view, x, y|
			if(~melodySynth.notNil) { updateMelody.value(x, y); };
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
						~voicing = voiceLead.value(root);
						{
							nowInfo.string = "Now: degree %  |  notes [%]  |  chord % of %  |  %".format(
								degree, ~voicing.collect { |step| (step % 13) + 1 }.join(", "),
								slot, count, meter[\label]
							);
							melodyView.refresh;
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
						playHarmony.value(pulseDur * 0.9, 0.075);
					});
					pulse = pulse + 1;
				}, {
					if(pulse != 0 or: { bar != 0 }) {
						~voicing = nil;
						{
							nowInfo.string = "Now: stopped";
							melodyView.refresh;
						}.defer;
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
