# Recovery from an AudioQueue callback stall

## Follow-up to #169

The serialized event-tap playback and unconditional idle-buffer clearing from
#169 remain in place.

Queue callbacks use AudioQueue's internal thread, independent of the UI run loop.
Queue lifetime operations and complete playback admission share a recursive lock;
callbacks never acquire that lock. Both sound-library preload paths use the same
lock as playback lookup. Failed output binding leaves the queue stopped and
schedules a retry, rather than starting on a default route. Delayed initialization
and restart retries ignore a superseded queue generation.
Recovery captures and detaches pending voices before synchronous Stop/Dispose,
which may return buffers through callbacks. Those teardown callbacks cannot consume
the newest voice before it is reconstructed.

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

The recovery guard comes from DiNardo87's
[PR #166](https://github.com/kamillobinski/thock/pull/166). This follow-up combines
that recovery with current main's #169 changes and the
admission, routing, retry and teardown fixes described above.

The callback-thread and lifecycle serialization follow Rafael Lozano's PR #148,
reconciled with the spatial-audio changes in current main. This recovery change
relies on that lifecycle serialization. PR #148 alone did not prevent the observed
stall in the local diagnostic build. Apple's
[AudioQueueNewOutput documentation](https://developer.apple.com/documentation/audiotoolbox/audioqueuenewoutput(_:_:_:_:_:_:_:))
describes the internal thread used when no callback run loop is supplied.

PR #146 by Rafael Lozano addresses disabled input event taps. That is a separate
failure mode and was present in the field-test build, but is not included in this
PR. Recovery here is driven by audio progress, not event-tap status. Related
symptom reports include #133 and #144; this does not establish that all such
reports have this same cause.

## Verification and reproduction

Run the existing Xcode unit target:

```sh
xcodebuild -project Thock.xcodeproj -scheme Thock -configuration Debug \
  -destination 'platform=macOS' -only-testing:ThockTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO test
```

Two regressions cover repeated idle-buffer clearing and retention of the newest
voice before teardown callbacks.
The existing tests are unchanged. Offline render fixtures avoid device setup.

Manual checks: keyboard and mouse playback, output switching, idle stop/restart,
sleep/wake, disconnected selected device, and spatial audio on/off. The original
local field build predates spatial audio; the port to current main requires its
own field validation. No claim is made that the older field build tested the
new spatial feature.
