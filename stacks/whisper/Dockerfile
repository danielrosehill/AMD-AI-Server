# Whisper STT with ROCm support
FROM rocm/pytorch:latest

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --no-cache-dir \
    openai-whisper \
    flask \
    flask-cors \
    gunicorn \
    deepmultilingualpunctuation

# Copy the API server
COPY whisper_api.py /app/

# Create uploads directory
RUN mkdir -p /app/uploads

EXPOSE 9000

# Run with gunicorn for production
CMD ["gunicorn", "--bind", "0.0.0.0:9000", "--workers", "1", "--timeout", "300", "whisper_api:app"]
