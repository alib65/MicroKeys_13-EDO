# 13-EDO Left Hand + Melody - Ali Balighi (alibalighi.com)

A small SuperCollider instrument for exploring the sound of a 13-tone equal division of the octave (13-EDO). It combines a repeating, piano-like left-hand accompaniment with a melody that can be played by dragging the mouse. Both use a short filtered hammer transient, layered string partials, and slight unison detuning for a brighter, more struck piano character than a plain sine tone.

## Run it

1. Open `MicroKeyExperiment_13-EDO.scd` in SuperCollider.
2. Evaluate the whole file. The script boots the audio server and opens the instrument window when the server is ready.
3. Choose a tonic, harmony and meter, tick the chord degrees you want in the loop, set the tempo, and press **Start left hand**.
4. Click and drag horizontally through the large lane to play the melody. Release the mouse to stop the note.
5. Or play the melody from the computer keyboard (see **Computer keyboard** below).

The left hand loops through the ticked chord degrees, one chord per bar. Within each bar it plays a low bass note at the start of each beat group (the root first, alternating with the fifth) and the three-note harmony on the remaining pulses. Use **Stop left hand** to pause it. Closing the window stops the accompaniment routine. SuperCollider's Cmd+. shortcut also stops active sound.

## Controls

- **Tonic:** selects one of 13 possible starting pitches, relative to C. The reference pitch is C4 at 261.63 Hz.
- **Chord loop checkboxes (1-13):** tick the chord roots in the order you want them played. Ticking 1, 5, 13, 2, 3 loops those chords in that order. Unticking a degree removes it from the loop; **Clear** empties it. With nothing ticked, the loop holds degree 1. Degree `n` is `n - 1` steps above the tonic, so degree 13 is 12 steps up, one step below the octave.
- **Meter:** 2/4, 3/4, 4/4, 5/4, 6/8, 7/8, 9/8, 11/8 or 12/8. Eighth-note meters are grouped as 6/8 = 3+3, 7/8 = 2+2+3, 9/8 = 3+3+3, 11/8 = 3+3+3+2 and 12/8 = 3+3+3+3. You can change the meter while the loop is playing.
- **Harmony:** selects which 13-EDO interval is stacked to make a three-note chord.
- **Tempo:** changes the accompaniment speed from 60 to 160 BPM. BPM always counts quarter notes, so in x/8 meters each pulse is an eighth note, half a beat.
- **Melody lane:** maps left to right across two octaves, from the selected tonic at octave 4 to the same tonic at octave 6. It is drawn as a keyboard with one key per 13-EDO step: degrees 1, 3, 5, 7, 9, 11 and 13 of each octave are white keys and degrees 2, 4, 6, 8, 10 and 12 are black keys. Each key is numbered with its degree, the key being played lights up gold, and gold lines mark each octave of the tonic. The readout shows the current scale degree, cents above the tonic, and frequency.

## Computer keyboard

| Key | a | w | s | e | d | r | f | t | g | y | h | u | j |
| --- | - | - | - | - | - | - | - | - | - | - | - | - | - |
| Degree | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 |

- Keys sound while held, and several can be held at once to play chords.
- **z** moves down one octave and **x** moves up one octave, from two octaves down to two octaves up. The on-screen keyboard shifts with the octave, so the keys you play always light up gold on it. Mouse playing follows the same octave.
- The current octave is shown in the information line above the keyboard.
- Cmd and Ctrl shortcuts are passed through, so Cmd+. still stops all sound.

## Harmony and tuning

In 13-EDO, each step is `1200 / 13`, or about 92.31 cents. A pitch `n` steps above the tonic has frequency

```text
tonic frequency * 2 ** (n / 13)
```

Each ticked degree sets a chord root, and the harmony menu stacks a selected interval twice above that root:

| Menu choice | Stack in 13-EDO steps | Approximate interval size |
| --- | --- | --- |
| 2nd | 0, 2, 4 | 2 steps per interval |
| 3rd | 0, 4, 8 | 4 steps per interval |
| 4th | 0, 5, 10 | 5 steps per interval |
| 5th | 0, 8, 16 | 8 steps per interval |

The **3rd** option is the familiar tertian-triad idea: on C it resembles C-E-G. In 13-EDO the notes are tuned to the nearest useful 13-step divisions rather than standard 12-EDO semitones, so it is an approximation, not the exact piano chord. The other options make the intervals' distinctive 13-EDO color easier to compare.

This is an exploratory listening tool, not a conventional piano keyboard. The melody lane gives every 13-EDO pitch equal horizontal space so the difference between 13-EDO and 12-EDO can be heard and felt directly.