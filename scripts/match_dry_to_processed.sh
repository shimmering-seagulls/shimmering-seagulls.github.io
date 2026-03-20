#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR="${1:-$PWD}"
CLIPS_DIR="${ROOT_DIR}/clips"
DRY_DIR="${CLIPS_DIR}/dafx26-dry-short"
OUT_ROOT="${CLIPS_DIR}/dry-matched"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Error: ffmpeg not found in PATH." >&2
  exit 1
fi

if ! command -v ffprobe >/dev/null 2>&1; then
  echo "Error: ffprobe not found in PATH." >&2
  exit 1
fi

if [[ ! -d "${CLIPS_DIR}" ]]; then
  echo "Error: clips directory not found: ${CLIPS_DIR}" >&2
  exit 1
fi

if [[ ! -d "${DRY_DIR}" ]]; then
  echo "Error: dry reference directory not found: ${DRY_DIR}" >&2
  exit 1
fi

mkdir -p "${OUT_ROOT}"

echo "Root: ${ROOT_DIR}"
echo "Input dry folder: ${DRY_DIR}"
echo "Output folder: ${OUT_ROOT}"
echo

typeset -i created=0
typeset -i skipped=0

for proc_folder in "${CLIPS_DIR}"/*; do
  [[ -d "${proc_folder}" ]] || continue

  folder_name="${proc_folder:t}"

  if [[ "${folder_name}" == "dafx26-dry-short" || "${folder_name}" == "dry-matched" ]]; then
    continue
  fi

  out_folder="${OUT_ROOT}/${folder_name}"
  mkdir -p "${out_folder}"

  for proc_file in "${proc_folder}"/*.wav; do
    [[ -f "${proc_file}" ]] || continue

    proc_basename="${proc_file:t:r}"
    clip_id="${proc_basename}"

    if [[ "${clip_id}" == "${folder_name}_"* ]]; then
      clip_id="${clip_id#${folder_name}_}"
    fi

    dry_file="${DRY_DIR}/${clip_id}.wav"
    out_file="${out_folder}/${proc_basename}.wav"

    if [[ ! -f "${dry_file}" ]]; then
      echo "[skip] Missing dry source for ${proc_basename}: ${dry_file}"
      skipped+=1
      continue
    fi

    sr="$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 "${proc_file}")"
    ch="$(ffprobe -v error -select_streams a:0 -show_entries stream=channels -of csv=p=0 "${proc_file}")"
    dur="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "${proc_file}")"

    if [[ -z "${sr}" || -z "${ch}" || -z "${dur}" ]]; then
      echo "[skip] Could not probe processed file: ${proc_file}"
      skipped+=1
      continue
    fi

    ffmpeg -hide_banner -loglevel error -y \
      -i "${dry_file}" \
      -af "apad,atrim=0:${dur}" \
      -ar "${sr}" \
      -ac "${ch}" \
      "${out_file}"

    echo "[ok] ${folder_name}/${proc_basename}.wav <= dry ${clip_id}.wav"
    created+=1
  done
done

echo
echo "Done. Created: ${created}, skipped: ${skipped}"
echo "Dry-matched clips are under: ${OUT_ROOT}"