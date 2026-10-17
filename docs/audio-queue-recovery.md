# Recovery from an AudioQueue callback stall

## Observed failure

On an Apple Silicon Mac running macOS 27.0, both keyboard and mouse sounds
occasionally stopped while Thock remained enabled. Changing soundpacks did not
restore playback. Changing Thock's output between Default and the built-in
speakers consistently restored it, including when a fixed output was selected.

In a diagnostic build based on 1.23.0 with PR #146 and PR #148 applied, input
and playback-request counters continued increasing while AudioQueue callbacks
stopped. Rebuilding the queue through output selection restored callbacks in
the same process. In later automatic recoveries, CoreAudio reported
`kAudioQueueProperty_IsRunning = 1` with `noErr` even though callbacks had stopped.
The precise cause of the original stall remains unknown; a muted video was
near one occurrence, but causation was not established.

The local recovery build subsequently recovered from six natural recurrences
in one process, with callbacks and rendered buffers resuming after each reset.
The closest observed recurrences were about 73 seconds apart. The user
confirmed audible playback returned after several keystrokes/clicks without
changing outputs. This is single-machine field evidence, not a universal fix.

## Recovery policy

- Actual sound admission arms one coalesced delayed observation. Idle silence
  does not arm recovery, and there is no periodic queue-reset timer.
- After at least one second, require unchanged queue generation, no callback
  progress, pending sounds, a ready/expected-running queue and an available
  preferred output. Do not fall back from a disconnected selected device.
- Rebuild through the existing output-switching path, serialized with restart,
  idle stop and voice admission. Never take the lifecycle lock in callbacks.
- Discard the backlog and recreate only the newest pending voice, retaining its
  pitch and position. On current main this allocates fresh spatial routing
  rather than carrying an invalid bus from the replaced renderer.
- Reapply the saved per-device volume. Limit recovery attempts to one per ten
  seconds, with another playback request required to arm a later attempt.
- Log the queue generation, pending count and actual CoreAudio running property
  at recovery, without logging keystrokes or mouse coordinates.

Expected interruption is roughly the one-second observation plus reconstruction.
A blocked main queue can delay recovery. The guard does not detect silence when
callbacks still progress, and it does not determine the underlying CoreAudio
stall trigger. Ordinary output/device recovery remains in the existing code.

## Relationship to existing work

PR #148 by Rafael Lozano moves callbacks to AudioQueue's internal thread and
serializes queue lifecycle operations. It is retained as a separate authored
commit, reconciled with the spatial-audio changes in current main. This recovery
change relies on that lifecycle serialization. PR #148 alone did not prevent
the observed stall in the local diagnostic build.

PR #146 by Rafael Lozano addresses disabled input event taps. That is a separate
failure mode and was present in the field-test build, but is not included in this
PR. Recovery here is driven by audio progress, not event-tap status. Related
symptom reports include #133 and #144; this does not establish that all such
reports have this same cause.

## Verification and reproduction

Run the guard regression checks without launching Thock or requesting input
permissions:

```sh
./scripts/test-playback-recovery.sh
```

The 17 checks cover callback progress, starvation, coalescing, cooldown/retry,
empty pending sounds, intentional stop, missing output, generation replacement,
invalidation, observation duration and concurrent callback/request updates.

Build a separate Debug product, then execute its binary directly with:

```sh
/path/to/Thock.app/Contents/MacOS/Thock --audio-recovery-self-test
```

This Debug-only path returns before menu/input/permission setup. It submits
silent samples through production playback, withholds the three returned
buffers, and verifies a single recovery, resumed callbacks, a generation
advance and one retained voice. Healthy playback and subsequent silence must
not reset the queue. It needs a working output device and normal CoreAudio
access; it does not test audible quality. It uses ordinary audio device setup,
so use a separate build and avoid running it during an active audio session.

Manual checks: keyboard and mouse playback, output switching, idle stop/restart,
sleep/wake, disconnected selected device, and spatial audio on/off. The original
local field build predates spatial audio; the port to current main requires its
own field validation. No claim is made that the older field build tested the
new spatial feature.
