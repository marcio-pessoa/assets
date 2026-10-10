#!/usr/bin/env bash
# Convert MP4 video to deterministic WebM (VP9 + Opus) and OGV (Theora + Vorbis)
# Usage:
#   ./scripts/convert_video.sh input.mp4 [output_format: webm|ogv|all] [--force]
#
# Examples:
#   ./scripts/convert_video.sh videos/pawlogic-promo2.mp4
#   ./scripts/convert_video.sh videos/pawlogic-promo2.mp4 webm
#   ./scripts/convert_video.sh videos/pawlogic-promo2.mp4 ogv

set -euo pipefail

# Locate ffmpeg with libtheora and libvpx-vp9 support
find_ffmpeg() {
    if [ -x "/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg" ]; then
        echo "/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg"
    elif [ -x "/usr/local/opt/ffmpeg-full/bin/ffmpeg" ]; then
        echo "/usr/local/opt/ffmpeg-full/bin/ffmpeg"
    elif command -v ffmpeg >/dev/null 2>&1; then
        command -v ffmpeg
    else
        echo "Error: ffmpeg not found. Install via 'brew install ffmpeg-full'." >&2
        exit 1
    fi
}

FFMPEG="$(find_ffmpeg)"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <input_mp4> [webm|ogv|all] [--force]" >&2
    exit 1
fi

INPUT="$1"
shift

TARGET_FORMAT="all"
FORCE=0

while [ $# -gt 0 ]; do
    case "$1" in
        --force|-f)
            FORCE=1
            ;;
        webm|ogv|all)
            TARGET_FORMAT="$1"
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
    shift
done

if [ ! -f "$INPUT" ]; then
    echo "Error: Input file '$INPUT' does not exist." >&2
    exit 1
fi

DIRNAME="$(dirname "$INPUT")"
BASENAME="$(basename "$INPUT")"
STEM="${BASENAME%.*}"

OUTPUT_WEBM="${DIRNAME}/${STEM}.webm"
OUTPUT_OGV="${DIRNAME}/${STEM}.ogv"

# Check if file has audio stream
has_audio() {
    local probe_bin
    probe_bin="$(dirname "$FFMPEG")/ffprobe"
    if [ ! -x "$probe_bin" ]; then
        probe_bin="ffprobe"
    fi
    if "$probe_bin" -v error -select_streams a -show_entries stream=index -of csv=p=0 "$INPUT" 2>/dev/null | grep -q '^[0-9]'; then
        return 0
    else
        return 1
    fi
}

convert_webm() {
    if [ -f "$OUTPUT_WEBM" ] && [ "$FORCE" -eq 0 ]; then
        echo "==> Skipping WebM (already exists): $OUTPUT_WEBM"
        return 0
    fi

    echo "==> Converting to WebM: $INPUT -> $OUTPUT_WEBM"
    local audio_opts=()
    if has_audio; then
        audio_opts=(-c:a libopus -b:a 96k)
    else
        audio_opts=(-an)
    fi

    "$FFMPEG" -hide_banner -loglevel error -y -i "$INPUT" \
        -c:v libvpx-vp9 -crf 33 -b:v 0 -row-mt 1 \
        "${audio_opts[@]}" \
        "$OUTPUT_WEBM"
    echo "==> WebM created: $OUTPUT_WEBM"
}

convert_ogv() {
    if [ -f "$OUTPUT_OGV" ] && [ "$FORCE" -eq 0 ]; then
        echo "==> Skipping OGV (already exists): $OUTPUT_OGV"
        return 0
    fi

    # Check libtheora encoder support
    if ! "$FFMPEG" -encoders 2>/dev/null | grep -q "libtheora"; then
        echo "Error: $FFMPEG does not have libtheora encoder support." >&2
        echo "Please install ffmpeg-full: brew install ffmpeg-full" >&2
        return 1
    fi

    echo "==> Converting to OGV: $INPUT -> $OUTPUT_OGV"
    local audio_opts=()
    if has_audio; then
        audio_opts=(-c:a libvorbis -q:a 5)
    else
        audio_opts=(-an)
    fi

    "$FFMPEG" -hide_banner -loglevel error -y -i "$INPUT" \
        -c:v libtheora -q:v 7 \
        "${audio_opts[@]}" \
        "$OUTPUT_OGV"
    echo "==> OGV created: $OUTPUT_OGV"
}

case "$TARGET_FORMAT" in
    webm)
        convert_webm
        ;;
    ogv)
        convert_ogv
        ;;
    all)
        convert_webm
        convert_ogv
        ;;
esac
