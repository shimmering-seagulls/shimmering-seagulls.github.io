from __future__ import annotations

import argparse
from pathlib import Path
import warnings

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import ticker
import numpy as np
import soundfile as sf

warnings.filterwarnings("ignore", message="divide by zero encountered in log10", category=RuntimeWarning)

matplotlib.rcParams.update(
    {
        "font.family": "sans-serif",
        "font.sans-serif": ["Inter", "Helvetica", "Arial", "DejaVu Sans"],
    }
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate waveform + spectrogram preview images for all audio files."
    )
    parser.add_argument(
        "--input-dir",
        type=Path,
        default=Path("clips"),
        help="Root directory containing grouped audio files.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("figures/thumbs"),
        help="Output directory for generated PNG previews.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Optional limit for number of files to process (for smoke testing).",
    )
    parser.add_argument(
        "--dpi",
        type=int,
        default=140,
        help="Output PNG DPI.",
    )
    return parser.parse_args()


def format_duration(seconds: float) -> str:
    minutes = int(seconds // 60)
    remain = seconds - minutes * 60
    return f"{minutes}:{remain:05.2f}"


def plot_preview(audio_path: Path, output_path: Path, dpi: int) -> None:
    signal, sample_rate = sf.read(str(audio_path), always_2d=False)

    if signal.ndim == 2:
        signal = signal[:, 0]

    if signal.size == 0:
        raise ValueError("Audio file is empty")

    # normalize amplitude 
    max_val = np.max(np.abs(signal))
    signal = signal / max_val  

    duration = signal.shape[0] / sample_rate
    time_axis = np.linspace(0.0, duration, num=signal.shape[0], endpoint=False)

    fig, (wave_ax, spec_ax) = plt.subplots(
        2,
        1,
        figsize=(8.8, 4.2),
        gridspec_kw={"height_ratios": [1, 1.45]},
    )
    fig.subplots_adjust(left=0.082, right=0.992, top=0.93, bottom=0.14, hspace=0.28)

    # title = audio_path.stem.replace("_", " ")
    wave_color = plt.get_cmap("magma")(0.5)

    wave_ax.plot(time_axis, signal, color=wave_color, linewidth=0.7)
    wave_ax.set_xlim(0, duration)
    wave_ax.set_ylim(-1.05, 1.05)
    wave_ax.set_ylabel("Amplitude")
    # wave_ax.set_title(title, fontsize=10)
    wave_ax.grid(alpha=0.22)

    spec_ax.specgram(
        signal,
        Fs=sample_rate,
        NFFT=2048,
        noverlap=2048 - 512,
        cmap="magma",
        scale="dB",
    )
    spec_ax.set_xlim(0, duration)
    spec_ax.set_ylabel("Frequency (kHz)")
    spec_ax.yaxis.set_major_formatter(ticker.FuncFormatter(lambda value, _: f"{value / 1000:g}"))
    spec_ax.set_xlabel("Time (s)")
    spec_ax.set_ylim(0, 24000)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, dpi=dpi)
    plt.close(fig)


def find_audio_files(root: Path) -> list[Path]:
    extensions = {".wav", ".aif", ".aiff", ".flac", ".ogg", ".mp3", ".m4a"}
    files = [path for path in root.rglob("*") if path.is_file() and path.suffix.lower() in extensions]
    return sorted(files)


def main() -> None:
    args = parse_args()

    if not args.input_dir.exists():
        raise FileNotFoundError(f"Input directory not found: {args.input_dir}")

    audio_files = find_audio_files(args.input_dir)
    if args.limit is not None:
        audio_files = audio_files[: args.limit]

    if not audio_files:
        print("No audio files found.")
        return

    processed = 0
    for audio_path in audio_files:
        relative_path = audio_path.relative_to(args.input_dir)
        output_path = args.output_dir / relative_path.with_suffix(".png")
        try:
            plot_preview(audio_path, output_path, args.dpi)
            processed += 1
            print(f"OK  {relative_path} -> {output_path}")
        except Exception as exc:
            print(f"ERR {relative_path}: {exc}")

    print(f"Done. Generated {processed}/{len(audio_files)} previews.")


if __name__ == "__main__":
    main()
