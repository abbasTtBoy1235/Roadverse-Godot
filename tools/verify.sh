#!/usr/bin/env bash
#
# Full headless verification for Roadverse (Godot).
#
#   ./tools/verify.sh
#   GODOT=/path/to/godot ./tools/verify.sh
#
# Runs: import -> gearbox unit tests -> physics smoke test.
# Exits non-zero if anything fails, so it drops straight into CI.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT:-}"

if [ -z "$GODOT_BIN" ]; then
	for candidate in godot godot4 Godot; do
		if command -v "$candidate" >/dev/null 2>&1; then
			GODOT_BIN="$(command -v "$candidate")"
			break
		fi
	done
fi

if [ -z "$GODOT_BIN" ] || [ ! -x "$GODOT_BIN" ]; then
	cat >&2 <<'EOF'
Could not find a Godot binary.

  GODOT=/path/to/godot ./tools/verify.sh
EOF
	exit 1
fi

echo "Godot  : $("$GODOT_BIN" --headless --version 2>/dev/null | tail -1)"
echo "Project: $PROJECT_ROOT"
echo

run_step() {
	local label="$1"
	shift

	printf '==> %s\n' "$label"
	"$@"
	local status=$?

	if [ $status -ne 0 ]; then
		printf '\033[1;31mFAILED\033[0m %s (exit %d)\n' "$label" "$status"
		exit $status
	fi

	printf '\033[1;32mok\033[0m   %s\n\n' "$label"
}

cd "$PROJECT_ROOT"

run_step "import assets" \
	"$GODOT_BIN" --headless --path "$PROJECT_ROOT" --import

run_step "gearbox unit tests" \
	"$GODOT_BIN" --headless --path "$PROJECT_ROOT" --script res://tests/test_gearbox.gd

run_step "day/night cycle tests" \
	"$GODOT_BIN" --headless --path "$PROJECT_ROOT" --script res://tests/test_day_cycle.gd

run_step "road geometry tests" \
	"$GODOT_BIN" --headless --path "$PROJECT_ROOT" --script res://tests/test_road_geometry.gd

run_step "camera orbit tests" \
	"$GODOT_BIN" --headless --path "$PROJECT_ROOT" --script res://tests/test_camera_orbit.gd

run_step "audio and traffic tests" \
	"$GODOT_BIN" --headless --path "$PROJECT_ROOT" --script res://tests/test_audio_traffic.gd

run_step "weather and road-noise tests" \
	"$GODOT_BIN" --headless --path "$PROJECT_ROOT" --script res://tests/test_weather_noise.gd

run_step "mission scoring tests" \
	"$GODOT_BIN" --headless --path "$PROJECT_ROOT" --script res://tests/test_mission.gd

run_step "menu and camera wiring" \
	"$GODOT_BIN" --headless --path "$PROJECT_ROOT" res://tests/ui_flow.tscn

run_step "camera follow regression" \
	"$GODOT_BIN" --headless --path "$PROJECT_ROOT" res://tests/camera_follow.tscn

run_step "drive state (wheels, audio, traffic, trailer, mission, rain, barriers)" \
	"$GODOT_BIN" --headless --path "$PROJECT_ROOT" res://tests/drive_state.tscn

run_step "physics smoke test" \
	"$GODOT_BIN" --headless --path "$PROJECT_ROOT" res://tests/smoke_test.tscn

echo "All checks passed."
