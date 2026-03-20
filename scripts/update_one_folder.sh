#!/usr/bin/env zsh

set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <folder_name> [root_dir]" >&2
  echo "Example: $0 cfwr_02" >&2
  exit 1
fi

FOLDER_NAME="$1"
ROOT_DIR="${2:-$PWD}"

CLIPS_DIR="${ROOT_DIR}/clips"
PROC_DIR="${CLIPS_DIR}/${FOLDER_NAME}"
DRY_DIR="${CLIPS_DIR}/dafx26-dry-short"
DRY_MATCHED_DIR="${CLIPS_DIR}/dry-matched/${FOLDER_NAME}"
THUMBS_DIR="${ROOT_DIR}/figures/thumbs/${FOLDER_NAME}"
PREVIEW_SCRIPT="${ROOT_DIR}/scripts/generate_previews.py"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Error: ffmpeg not found in PATH." >&2
  exit 1
fi

if ! command -v ffprobe >/dev/null 2>&1; then
  echo "Error: ffprobe not found in PATH." >&2
  exit 1
fi

if [[ ! -f "${PREVIEW_SCRIPT}" ]]; then
  echo "Error: preview generator not found: ${PREVIEW_SCRIPT}" >&2
  exit 1
fi

PYTHON_CMD=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_CMD="python"
else
  echo "Error: python interpreter not found in PATH." >&2
  exit 1
fi

if [[ ! -d "${PROC_DIR}" ]]; then
  echo "Error: processed folder not found: ${PROC_DIR}" >&2
  exit 1
fi

if [[ ! -d "${DRY_DIR}" ]]; then
  echo "Error: dry reference folder not found: ${DRY_DIR}" >&2
  exit 1
fi

mkdir -p "${DRY_MATCHED_DIR}" "${THUMBS_DIR}"

echo "Root: ${ROOT_DIR}"
echo "Folder: ${FOLDER_NAME}"
echo "Processed clips: ${PROC_DIR}"
echo "Dry-matched out: ${DRY_MATCHED_DIR}"
echo "Thumbnails out: ${THUMBS_DIR}"
echo

typeset -i matched_ok=0
typeset -i matched_skip=0
typeset -i found=0

for proc_file in "${PROC_DIR}"/*.wav(N); do
  [[ -f "${proc_file}" ]] || continue
  found+=1

  proc_basename="${proc_file:t:r}"
  clip_id="${proc_basename}"

  if [[ "${clip_id}" == "${FOLDER_NAME}_"* ]]; then
    clip_id="${clip_id#${FOLDER_NAME}_}"
  fi

  dry_file="${DRY_DIR}/${clip_id}.wav"
  dry_out="${DRY_MATCHED_DIR}/${proc_basename}.wav"
  if [[ -f "${dry_file}" ]]; then
    sr="$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 "${proc_file}")"
    ch="$(ffprobe -v error -select_streams a:0 -show_entries stream=channels -of csv=p=0 "${proc_file}")"
    dur="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "${proc_file}")"

    if [[ -n "${sr}" && -n "${ch}" && -n "${dur}" ]]; then
      ffmpeg -hide_banner -loglevel error -y \
        -i "${dry_file}" \
        -af "apad,atrim=0:${dur}" \
        -ar "${sr}" \
        -ac "${ch}" \
        "${dry_out}"
      echo "[ok] dry-matched: ${proc_basename}.wav"
      matched_ok+=1
    else
      echo "[skip] probe failed: ${proc_basename}.wav"
      matched_skip+=1
    fi
  else
    echo "[skip] missing dry source: ${dry_file}"
    matched_skip+=1
  fi
done

if (( found == 0 )); then
  echo "Error: no .wav files found in ${PROC_DIR}" >&2
  exit 1
fi

rm -f "${THUMBS_DIR}"/*.png(N)

echo
echo "Generating thumbnails via ${PREVIEW_SCRIPT}..."
"${PYTHON_CMD}" "${PREVIEW_SCRIPT}" \
  --input-dir "${PROC_DIR}" \
  --output-dir "${THUMBS_DIR}"

thumb_files=("${THUMBS_DIR}"/*.png(N))
typeset -i thumbs_ok=${#thumb_files[@]}
typeset -i thumbs_skip=$(( found - thumbs_ok ))

echo
echo "Done for ${FOLDER_NAME}."
echo "Dry-matched: created ${matched_ok}, skipped ${matched_skip}"
echo "Thumbnails: created ${thumbs_ok}, skipped ${thumbs_skip}"
