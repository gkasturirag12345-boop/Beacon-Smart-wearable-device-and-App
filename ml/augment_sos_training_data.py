#!/usr/bin/env python3
"""
SOS Audio Data Augmentation Pipeline
=====================================
Generates varied pronunciations of SOS to improve detection of unclear/stressed speech.

Augmentation Techniques:
1. Speed variations (0.7x - 1.3x) - simulates fast/slow speech
2. Pitch shifting (-3 to +3 semitones) - simulates different voice characteristics
3. Volume variations (0.5x - 1.5x) - simulates quiet/loud speech
4. Stress simulation - combines speed + pitch + volume changes
5. Mumbling simulation - speed reduction + low-pass filter
6. Slurring simulation - time stretching with formant preservation
7. Background noise addition - simulates real-world conditions

Requirements:
    pip install librosa numpy scipy soundfile

Usage:
    python3 augment_sos_training_data.py --input /path/to/CreateML_SOS_Dataset --output /path/to/Augmented_Dataset
"""

import os
import argparse
import numpy as np
import librosa
import soundfile as sf
from pathlib import Path
from typing import Tuple, List
import warnings
warnings.filterwarnings('ignore')


class SOSAudioAugmenter:
    """Augments SOS audio data with pronunciation variations."""

    def __init__(self, target_sr: int = 22050):
        """
        Initialize augmenter.

        Args:
            target_sr: Target sample rate (22,050 Hz for CreateML)
        """
        self.target_sr = target_sr
        self.augmentation_count = 0

    def load_audio(self, file_path: str) -> Tuple[np.ndarray, int]:
        """Load audio file and ensure correct sample rate."""
        audio, sr = librosa.load(file_path, sr=self.target_sr, mono=True)
        return audio, sr

    def save_audio(self, audio: np.ndarray, file_path: str, sr: int):
        """Save audio file as 16-bit WAV."""
        # Normalize to prevent clipping
        audio = np.clip(audio, -1.0, 1.0)
        sf.write(file_path, audio, sr, subtype='PCM_16')

    def speed_variation(self, audio: np.ndarray, rate: float) -> np.ndarray:
        """
        Change speech speed without affecting pitch.

        Args:
            audio: Input audio
            rate: Speed factor (0.7 = slower, 1.3 = faster)
        """
        return librosa.effects.time_stretch(audio, rate=rate)

    def pitch_shift(self, audio: np.ndarray, sr: int, n_steps: float) -> np.ndarray:
        """
        Shift pitch without changing speed.

        Args:
            audio: Input audio
            sr: Sample rate
            n_steps: Semitones to shift (-3 to +3)
        """
        return librosa.effects.pitch_shift(audio, sr=sr, n_steps=n_steps)

    def volume_variation(self, audio: np.ndarray, gain: float) -> np.ndarray:
        """
        Adjust volume level.

        Args:
            audio: Input audio
            gain: Volume multiplier (0.5 = quieter, 1.5 = louder)
        """
        return audio * gain

    def add_background_noise(self, audio: np.ndarray, noise_level: float = 0.005) -> np.ndarray:
        """
        Add white noise to simulate real-world conditions.

        Args:
            audio: Input audio
            noise_level: Noise amplitude (0.005 = subtle)
        """
        noise = np.random.normal(0, noise_level, len(audio))
        return audio + noise

    def low_pass_filter(self, audio: np.ndarray, sr: int, cutoff_freq: int = 3000) -> np.ndarray:
        """
        Apply low-pass filter to simulate muffled speech.

        Args:
            audio: Input audio
            sr: Sample rate
            cutoff_freq: Cutoff frequency in Hz
        """
        from scipy import signal
        nyquist = sr / 2
        normalized_cutoff = cutoff_freq / nyquist
        b, a = signal.butter(4, normalized_cutoff, btype='low')
        return signal.filtfilt(b, a, audio)

    def simulate_stress(self, audio: np.ndarray, sr: int) -> np.ndarray:
        """
        Simulate stressed/panic voice: faster speech + higher pitch + louder volume.
        """
        # Faster speech (1.2x speed)
        audio = self.speed_variation(audio, rate=1.2)
        # Higher pitch (+2 semitones)
        audio = self.pitch_shift(audio, sr, n_steps=2.0)
        # Louder (1.3x volume)
        audio = self.volume_variation(audio, gain=1.3)
        # Add slight tremor
        audio = self.add_background_noise(audio, noise_level=0.003)
        return audio

    def simulate_mumbling(self, audio: np.ndarray, sr: int) -> np.ndarray:
        """
        Simulate mumbled speech: slower + muffled + quieter.
        """
        # Slower speech (0.85x speed)
        audio = self.speed_variation(audio, rate=0.85)
        # Muffled (low-pass filter)
        audio = self.low_pass_filter(audio, sr, cutoff_freq=2500)
        # Quieter (0.7x volume)
        audio = self.volume_variation(audio, gain=0.7)
        return audio

    def simulate_slurring(self, audio: np.ndarray, sr: int) -> np.ndarray:
        """
        Simulate slurred speech: time-stretched + pitch lowered slightly.
        """
        # Slow down significantly (0.75x speed)
        audio = self.speed_variation(audio, rate=0.75)
        # Lower pitch slightly (-1 semitone)
        audio = self.pitch_shift(audio, sr, n_steps=-1.0)
        # Add slight blur with low-pass
        audio = self.low_pass_filter(audio, sr, cutoff_freq=4000)
        return audio

    def augment_file(self, input_path: str, output_dir: str, class_name: str,
                     original_filename: str, augment_config: dict):
        """
        Apply augmentations to a single file.

        Args:
            input_path: Path to original audio file
            output_dir: Directory to save augmented files
            class_name: Class name (sos, oh_ess, noise, unknown)
            original_filename: Original filename without extension
            augment_config: Dictionary specifying which augmentations to apply
        """
        # Load original audio
        audio, sr = self.load_audio(input_path)

        # Save original copy
        output_path = os.path.join(output_dir, f"{original_filename}.wav")
        self.save_audio(audio, output_path, sr)

        # Apply augmentations based on config
        augmentations_applied = 0

        # Speed variations (for SOS class only or if specified)
        if augment_config.get('speed_variations', False):
            for rate in [0.8, 0.9, 1.1, 1.2]:
                aug_audio = self.speed_variation(audio, rate=rate)
                aug_path = os.path.join(output_dir, f"{original_filename}_speed{rate:.1f}x.wav")
                self.save_audio(aug_audio, aug_path, sr)
                augmentations_applied += 1

        # Pitch variations
        if augment_config.get('pitch_variations', False):
            for n_steps in [-2, -1, 1, 2]:
                aug_audio = self.pitch_shift(audio, sr, n_steps=float(n_steps))
                aug_path = os.path.join(output_dir, f"{original_filename}_pitch{n_steps:+d}.wav")
                self.save_audio(aug_audio, aug_path, sr)
                augmentations_applied += 1

        # Volume variations
        if augment_config.get('volume_variations', False):
            for gain in [0.6, 0.8, 1.2, 1.4]:
                aug_audio = self.volume_variation(audio, gain=gain)
                aug_path = os.path.join(output_dir, f"{original_filename}_vol{gain:.1f}x.wav")
                self.save_audio(aug_audio, aug_path, sr)
                augmentations_applied += 1

        # Stress simulation (CRITICAL for SOS detection)
        if augment_config.get('stress_simulation', False):
            aug_audio = self.simulate_stress(audio, sr)
            aug_path = os.path.join(output_dir, f"{original_filename}_stress.wav")
            self.save_audio(aug_audio, aug_path, sr)
            augmentations_applied += 1

        # Mumbling simulation
        if augment_config.get('mumbling_simulation', False):
            aug_audio = self.simulate_mumbling(audio, sr)
            aug_path = os.path.join(output_dir, f"{original_filename}_mumble.wav")
            self.save_audio(aug_audio, aug_path, sr)
            augmentations_applied += 1

        # Slurring simulation
        if augment_config.get('slurring_simulation', False):
            aug_audio = self.simulate_slurring(audio, sr)
            aug_path = os.path.join(output_dir, f"{original_filename}_slur.wav")
            self.save_audio(aug_audio, aug_path, sr)
            augmentations_applied += 1

        # Background noise
        if augment_config.get('background_noise', False):
            for noise_level in [0.003, 0.007]:
                aug_audio = self.add_background_noise(audio, noise_level=noise_level)
                aug_path = os.path.join(output_dir, f"{original_filename}_noise{noise_level:.3f}.wav")
                self.save_audio(aug_audio, aug_path, sr)
                augmentations_applied += 1

        # Combined augmentations (stress + noise)
        if augment_config.get('combined_augmentations', False):
            # Stress + noise
            aug_audio = self.simulate_stress(audio, sr)
            aug_audio = self.add_background_noise(aug_audio, noise_level=0.005)
            aug_path = os.path.join(output_dir, f"{original_filename}_stress_noisy.wav")
            self.save_audio(aug_audio, aug_path, sr)
            augmentations_applied += 1

            # Mumble + noise
            aug_audio = self.simulate_mumbling(audio, sr)
            aug_audio = self.add_background_noise(aug_audio, noise_level=0.005)
            aug_path = os.path.join(output_dir, f"{original_filename}_mumble_noisy.wav")
            self.save_audio(aug_audio, aug_path, sr)
            augmentations_applied += 1

        self.augmentation_count += augmentations_applied
        return augmentations_applied


def get_augmentation_config(class_name: str) -> dict:
    """
    Get augmentation configuration for each class.

    SOS class gets HEAVY augmentation (unclear pronunciations).
    Other classes get LIGHT augmentation (to maintain balance).
    """
    if class_name == 'sos':
        # AGGRESSIVE augmentation for SOS to handle unclear pronunciations
        return {
            'speed_variations': True,       # Fast/slow speech
            'pitch_variations': True,       # Different voice characteristics
            'volume_variations': True,      # Quiet/loud
            'stress_simulation': True,      # CRITICAL: panic/emergency voice
            'mumbling_simulation': True,    # Unclear articulation
            'slurring_simulation': True,    # Slurred speech
            'background_noise': True,       # Real-world conditions
            'combined_augmentations': True  # Multiple effects combined
        }
    elif class_name == 'oh_ess':
        # MODERATE augmentation for oh_ess to maintain separation
        return {
            'speed_variations': True,
            'pitch_variations': True,
            'volume_variations': False,
            'stress_simulation': False,
            'mumbling_simulation': False,
            'slurring_simulation': False,
            'background_noise': True,
            'combined_augmentations': False
        }
    else:
        # LIGHT augmentation for noise/unknown classes
        return {
            'speed_variations': False,
            'pitch_variations': False,
            'volume_variations': True,
            'stress_simulation': False,
            'mumbling_simulation': False,
            'slurring_simulation': False,
            'background_noise': True,
            'combined_augmentations': False
        }


def augment_dataset(input_dir: str, output_dir: str):
    """
    Augment entire dataset while preserving directory structure.

    Args:
        input_dir: Path to CreateML_SOS_Dataset/
        output_dir: Path to output augmented dataset
    """
    augmenter = SOSAudioAugmenter(target_sr=22050)

    # Process Training and Testing folders
    for split in ['Training', 'Testing']:
        split_input_dir = os.path.join(input_dir, split)
        split_output_dir = os.path.join(output_dir, split)

        if not os.path.exists(split_input_dir):
            print(f"⚠️  Warning: {split_input_dir} not found, skipping...")
            continue

        print(f"\n{'='*60}")
        print(f"Processing {split} Dataset")
        print(f"{'='*60}")

        # Process each class folder
        for class_name in ['sos', 'oh_ess', 'noise', 'unknown']:
            class_input_dir = os.path.join(split_input_dir, class_name)
            class_output_dir = os.path.join(split_output_dir, class_name)

            if not os.path.exists(class_input_dir):
                print(f"⚠️  Warning: {class_input_dir} not found, skipping...")
                continue

            # Create output directory
            os.makedirs(class_output_dir, exist_ok=True)

            # Get augmentation config for this class
            augment_config = get_augmentation_config(class_name)

            # Count audio files
            audio_files = [f for f in os.listdir(class_input_dir)
                          if f.endswith(('.wav', '.m4a', '.mp3', '.aiff'))]

            print(f"\n📁 Class: {class_name}")
            print(f"   Original files: {len(audio_files)}")
            print(f"   Augmentation level: {'AGGRESSIVE' if class_name == 'sos' else 'MODERATE' if class_name == 'oh_ess' else 'LIGHT'}")

            # Process each audio file
            total_augmentations = 0
            for i, filename in enumerate(audio_files, 1):
                input_path = os.path.join(class_input_dir, filename)
                original_filename = os.path.splitext(filename)[0]

                try:
                    num_augmentations = augmenter.augment_file(
                        input_path=input_path,
                        output_dir=class_output_dir,
                        class_name=class_name,
                        original_filename=original_filename,
                        augment_config=augment_config
                    )
                    total_augmentations += num_augmentations

                    if i % 50 == 0:
                        print(f"   Processed {i}/{len(audio_files)} files...")

                except Exception as e:
                    print(f"   ❌ Error processing {filename}: {e}")
                    continue

            # Count output files
            output_files = [f for f in os.listdir(class_output_dir) if f.endswith('.wav')]
            print(f"   ✅ Augmented files: {len(output_files)}")
            print(f"   Augmentation multiplier: {len(output_files) / len(audio_files):.1f}x")

    print(f"\n{'='*60}")
    print(f"✅ Augmentation Complete!")
    print(f"{'='*60}")
    print(f"Total augmentations created: {augmenter.augmentation_count}")
    print(f"Output directory: {output_dir}")


def main():
    parser = argparse.ArgumentParser(
        description='Augment SOS training data with pronunciation variations',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Augment dataset
  python3 augment_sos_training_data.py \\
      --input ~/Documents/BEACON_Project/CreateML_SOS_Dataset \\
      --output ~/Documents/BEACON_Project/Augmented_SOS_Dataset

  # Quick test on small subset
  python3 augment_sos_training_data.py \\
      --input ./test_dataset \\
      --output ./test_augmented
        """
    )

    parser.add_argument(
        '--input',
        required=True,
        help='Path to CreateML_SOS_Dataset directory'
    )

    parser.add_argument(
        '--output',
        required=True,
        help='Path to output augmented dataset directory'
    )

    args = parser.parse_args()

    # Validate input directory
    if not os.path.exists(args.input):
        print(f"❌ Error: Input directory not found: {args.input}")
        print("\nExpected structure:")
        print("  CreateML_SOS_Dataset/")
        print("  ├── Training/")
        print("  │   ├── sos/")
        print("  │   ├── oh_ess/")
        print("  │   ├── noise/")
        print("  │   └── unknown/")
        print("  └── Testing/")
        print("      ├── sos/")
        print("      ├── oh_ess/")
        print("      ├── noise/")
        print("      └── unknown/")
        return

    print(f"\n{'='*60}")
    print(f"SOS Audio Data Augmentation Pipeline")
    print(f"{'='*60}")
    print(f"Input:  {args.input}")
    print(f"Output: {args.output}")

    # Check dependencies
    print("\n📦 Checking dependencies...")
    try:
        import librosa
        import numpy
        import scipy
        import soundfile
        print("   ✅ All dependencies installed")
    except ImportError as e:
        print(f"   ❌ Missing dependency: {e}")
        print("\n   Install with: pip install librosa numpy scipy soundfile")
        return

    # Run augmentation
    augment_dataset(args.input, args.output)

    print("\n🎯 Next Steps:")
    print("   1. Review augmented dataset in:", args.output)
    print("   2. Listen to a few samples to verify quality")
    print("   3. Run Swift CreateML training script with augmented data")
    print("   4. Compare model performance before/after")


if __name__ == '__main__':
    main()
