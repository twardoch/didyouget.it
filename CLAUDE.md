
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
- `TODO.md` contains the highest-priority issues that you have to prioritize. Keep updated as you work.

## Operation

As you work: 

- Before you start working, analyze the recent git changes. 
- Consult TODO.md for highest-priority issues and fix them. Update the file as you work.
- Consult PROGRESS.md for additional issues and fix them. Update the file as you work.
- Keep the CHANGELOG.md updated as you work.
- After you make a change, perform `./run.sh` on macOS to build and run the app in debug mode, and observer the console output for any issues.

