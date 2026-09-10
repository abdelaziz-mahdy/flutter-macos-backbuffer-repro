# flutter-macos-backbuffer-repro

Minimal reproduction for [flutter/flutter#185394](https://github.com/flutter/flutter/issues/185394):
macOS + Impeller raster-thread crash in `impeller::Canvas::SetupRenderPass()`
(null color texture) reached through `EmbedderExternalViewEmbedder::SubmitFlutterView`.

## What it does

A stock `flutter create` macOS app with one animating widget (keeps the raster
thread busy every frame). `macos/Runner/MainFlutterWindow.swift` drives the
window from a timer:

- `REPRO_MODE=flip` (default): every 2.5 s shrink the content by 1 px for one
  frame, then restore it. Frame sizes go **A → B → A** with a single frame at B
  while the previous A surface is still held by the window server. That is the
  sequence that leaves `FlutterBackBufferCache` holding surfaces of two sizes,
  after which `removeSurfaceForSize:` hands out a B-sized surface for an A-sized
  request.
- `REPRO_MODE=fullscreen`: toggle native fullscreen every 2.5 s (the trigger seen
  in the field). Sizes are monotonic during the animation, so this mode is far
  less deterministic.

No plugins. `flutter_test` is removed from `pubspec.yaml` so the app resolves
against a `master` framework checkout.

## Run

```sh
./run_repro.sh <path to flutter/engine/src> [variant] [seconds]
# e.g.
./run_repro.sh ~/flutter/engine/src host_debug_unopt_arm64 240
```

Needs a locally built engine (`et build -c host_debug_unopt_arm64`). A debug
engine is preferable: it prints the Impeller validation line and trips a size
`DCHECK` at the same point where a release engine dereferences null.

## Results

See `logs/` for the raw output of each run. Engine `4e6768eca70` = upstream
`master` before the fix; `cec7d27aa2c` = with the fix
(flutter/flutter PR: https://github.com/flutter/flutter/pull/192522).

| Engine | Mode | Duration | Size-mismatch validation lines | Outcome |
|---|---|---|---|---|
| 4e6768eca70 (unfixed) | fullscreen | 55 toggles / ~2.5 min | 0 | no crash (monotonic sizes never mix the cache) |
| 4e6768eca70 (unfixed) | flip v1 (restore on next run-loop turn), instrumented cache | 11 flips / 28 s | 1 | **crash**: `SURFCACHE req=1600x1200 REUSED got=1598x1198 <<< SIZE MISMATCH` → `The texture and its descriptor disagree about its size.` → `Check failed: render_target_->GetRenderTargetSize() == c->GetRenderSurfaceSize()` |
| 4e6768eca70 (unfixed) | flip v1, no instrumentation | 2 flips / ~5 s | 1 | **crash**, same two lines; crash report `logs/crash_base_flip_v1_4e6768eca70.ips` (`io.flutter.raster`, abort in `Layer::RenderFlutterContentsImpeller`) |
| 4e6768eca70 (unfixed) | flip (current, synchronous shrink+restore) | 3 runs × 2 flips / ≤7 s each | 1 per run | **crash on flip 2 in 3/3 runs** (`logs/run_base_flip_v2_run{1,2,3}_4e6768eca70.txt`) |
| cec7d27aa2c (fixed) | flip | 3 runs × 60 s (23–24 flips each) | 0 | no crash, no graceful-skip lines either (`logs/run_fixed_flip_run{1,2,3}_cec7d27aa2c.txt`) |
| cec7d27aa2c (fixed) | flip | 97 flips / 240 s | 0 | no crash (`logs/run_fixed_flip_long_cec7d27aa2c.txt`) |

The "instrumented cache" run added temporary `NSLog`s to
`FlutterSurfaceManager.mm` (`surfaceForSize:` / `returnSurfaces:`) to show the
cache returning the wrong-size surface; that instrumentation is not part of the
fix.
