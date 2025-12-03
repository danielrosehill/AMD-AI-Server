"""
Whisper STT API Server
GPU-accelerated speech-to-text with optional punctuation restoration
"""

import os
import tempfile
from pathlib import Path

import whisper
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Load model on startup
MODEL_NAME = os.environ.get("WHISPER_MODEL", "base")
DEFAULT_LANGUAGE = os.environ.get("WHISPER_LANGUAGE", None)

print(f"Loading Whisper model: {MODEL_NAME}")
model = whisper.load_model(MODEL_NAME)
print(f"Model loaded successfully on device: {model.device}")

# Optional: Load punctuation restoration
punctuation_model = None
try:
    from deepmultilingualpunctuation import PunctuationModel
    punctuation_model = PunctuationModel()
    print("Punctuation restoration model loaded")
except ImportError:
    print("Punctuation restoration not available")


@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "model": MODEL_NAME,
        "device": str(model.device),
        "punctuation_available": punctuation_model is not None
    })


@app.route("/transcribe", methods=["POST"])
def transcribe():
    """
    Transcribe audio file

    Accepts:
        - file: Audio file (multipart/form-data)
        - language: Optional language code (e.g., 'en', 'he')
        - restore_punctuation: Whether to apply punctuation restoration (default: true)

    Returns:
        - text: Transcribed text
        - language: Detected/specified language
        - segments: Timestamped segments (if available)
    """
    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400

    file = request.files["file"]
    if file.filename == "":
        return jsonify({"error": "No file selected"}), 400

    # Get options
    language = request.form.get("language", DEFAULT_LANGUAGE)
    restore_punct = request.form.get("restore_punctuation", "true").lower() == "true"

    # Save uploaded file temporarily
    suffix = Path(file.filename).suffix or ".wav"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        file.save(tmp.name)
        tmp_path = tmp.name

    try:
        # Transcribe
        options = {}
        if language:
            options["language"] = language

        result = model.transcribe(tmp_path, **options)

        text = result["text"].strip()

        # Apply punctuation restoration if available and requested
        if punctuation_model and restore_punct and text:
            try:
                text = punctuation_model.restore_punctuation(text)
            except Exception as e:
                print(f"Punctuation restoration failed: {e}")

        return jsonify({
            "text": text,
            "language": result.get("language", language),
            "segments": [
                {
                    "start": seg["start"],
                    "end": seg["end"],
                    "text": seg["text"]
                }
                for seg in result.get("segments", [])
            ]
        })

    finally:
        # Clean up temp file
        try:
            os.unlink(tmp_path)
        except:
            pass


@app.route("/models", methods=["GET"])
def list_models():
    """List available Whisper models"""
    return jsonify({
        "current": MODEL_NAME,
        "available": ["tiny", "base", "small", "medium", "large", "large-v2", "large-v3"]
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9000, debug=False)
