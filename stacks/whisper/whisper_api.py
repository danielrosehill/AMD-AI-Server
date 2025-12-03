"""
Whisper STT API Server
GPU-accelerated speech-to-text with optional punctuation restoration
Supports both standard model and custom fine-tuned model
"""

import os
import tempfile
from pathlib import Path

import whisper
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Load models on startup
MODEL_NAME = os.environ.get("WHISPER_MODEL", "large-v3-turbo")
FINETUNE_MODEL_PATH = os.environ.get("WHISPER_FINETUNE_MODEL", "")
DEFAULT_LANGUAGE = os.environ.get("WHISPER_LANGUAGE", None)

# Load standard model
print(f"Loading Whisper model: {MODEL_NAME}")
model = whisper.load_model(MODEL_NAME)
print(f"Model loaded successfully on device: {model.device}")

# Load fine-tuned model if path provided
finetune_model = None
if FINETUNE_MODEL_PATH and os.path.exists(FINETUNE_MODEL_PATH):
    print(f"Loading fine-tuned model from: {FINETUNE_MODEL_PATH}")
    try:
        finetune_model = whisper.load_model(FINETUNE_MODEL_PATH)
        print(f"Fine-tuned model loaded on device: {finetune_model.device}")
    except Exception as e:
        print(f"Failed to load fine-tuned model: {e}")
else:
    print("No fine-tuned model configured or path not found")

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
        "finetune_available": finetune_model is not None,
        "finetune_path": FINETUNE_MODEL_PATH if finetune_model else None,
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
        - use_finetune: Whether to use fine-tuned model (default: false)

    Returns:
        - text: Transcribed text
        - language: Detected/specified language
        - segments: Timestamped segments (if available)
        - model_used: Which model was used for transcription
    """
    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400

    file = request.files["file"]
    if file.filename == "":
        return jsonify({"error": "No file selected"}), 400

    # Get options
    language = request.form.get("language", DEFAULT_LANGUAGE)
    restore_punct = request.form.get("restore_punctuation", "true").lower() == "true"
    use_finetune = request.form.get("use_finetune", "false").lower() == "true"

    # Select model
    if use_finetune:
        if finetune_model is None:
            return jsonify({"error": "Fine-tuned model not available"}), 400
        active_model = finetune_model
        model_used = "finetune"
    else:
        active_model = model
        model_used = MODEL_NAME

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

        result = active_model.transcribe(tmp_path, **options)

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
            "model_used": model_used,
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
        "finetune_available": finetune_model is not None,
        "finetune_path": FINETUNE_MODEL_PATH if finetune_model else None,
        "available": ["tiny", "base", "small", "medium", "large", "large-v2", "large-v3", "large-v3-turbo"]
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9000, debug=False)
