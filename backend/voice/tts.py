import os
import subprocess
import uuid


class PiperTTS:
    """Local Piper TTS wrapper for fully offline voice synthesis."""

    def __init__(self, root_path=None):
        self.root_path = root_path or os.getcwd()
        self.piper_exe = os.path.join(self.root_path, "bin", "piper", "piper", "piper.exe")
        self.voice_model = os.path.join(self.root_path, "voices", "piper", "en_US-amy-medium.onnx")
        self.output_dir = os.path.join(self.root_path, "data", "voice_out")
        os.makedirs(self.output_dir, exist_ok=True)

    def is_ready(self):
        return os.path.exists(self.piper_exe) and os.path.exists(self.voice_model)

    def synthesize(self, text):
        if not self.is_ready():
            raise FileNotFoundError("Piper runtime or Amy voice model is missing.")

        safe_text = text.strip()
        if not safe_text:
            raise ValueError("Cannot synthesize empty text.")

        output_path = os.path.join(self.output_dir, f"nova_{uuid.uuid4().hex}.wav")
        result = subprocess.run(
            [self.piper_exe, "--model", self.voice_model, "--output_file", output_path],
            input=safe_text,
            capture_output=True,
            text=True,
            timeout=90,
            encoding="utf-8",
            errors="replace",
        )
        if result.returncode != 0:
            raise RuntimeError(result.stderr.strip() or "Piper synthesis failed.")

        return output_path
