
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

BIG PROBLEM: 

- When I start recording and then stop, I get `/Users/adam/Movies/DidYouGetIt_2025-05-20_01-57-12/DidYouGetIt_2025-05-20_01-57-12.mov` which is zero-length, and I don't see any JSON files in the directory.

GENERALLY: Revise PROGRESS.md. Add the issues mentioned above, prioritize the issues marked with `FIXME`. 

Then start implementing the issues!

Perform `./run.sh debug` to build and run the app in debug mode.