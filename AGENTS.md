
# Project

I want a fast performant app `Did You Get It` (Mac identifier it.didyouget.mac, homepage https://didyouget.it ) that will run on macOS with extremely minimal user interface, and will let me: 

- Record the configurable area on the selectable screen, as a 60 FPS full-resolution (Retina) video
- If requested, record the audio from a selectable audio device
- If requested, record the mouse movements and clicks in JSON format with click vs. hold-release detection
- If requested, record the keyboard strokes in JSON format with tap vs. hold-release detection
- Save the recorded video, audio, and mouse/keyboard strokes to a file. If requested, the audio should be mixed with the video.

## Structure

- `README.md` contains the overview of the project
- `SPEC.md` contains the detailed specification. Check it, make sure you understand it, and then start working.
- `PROGRESS.md` contains the plan and uses `[ ]` vs. `[x]` items to track the progress. Keep it updated as you work.
- `CHANGELOG.md` contains the changelog. Keep updated as you work

## TODO

CURRENT PROBLEM: 

- When I click Record in the UI, it does switch to the "Stop Recording" UI mode, but the timer does not start.
- When I click Stop Recording, the UI switches back to the "Record" UI mode, but no MOV or JSON files are produced.

====

GENERALLY: Revise PROGRESS.md. Add the issues mentioned above, prioritize the issues marked with `FIXME`. 

Then start implementing the issues!

Perform `./run.sh debug` on macOS to build and run the app in debug mode.