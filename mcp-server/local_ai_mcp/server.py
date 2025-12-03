"""
Local AI MCP Server
Provides unified access to local AI services: Whisper STT, Ollama LLM
"""

import os
import base64
import tempfile
from pathlib import Path

import httpx
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent

# Configuration from environment
WHISPER_URL = os.environ.get("WHISPER_URL", "http://localhost:9000")
OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434")
OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "llama3.2")

server = Server("local-ai-mcp")


@server.list_tools()
async def list_tools() -> list[Tool]:
    """List available tools"""
    return [
        Tool(
            name="transcribe_raw",
            description="Transcribe audio using Whisper large-v3-turbo. Returns raw transcription without cleanup. Input: base64-encoded audio file.",
            inputSchema={
                "type": "object",
                "properties": {
                    "audio_base64": {
                        "type": "string",
                        "description": "Base64-encoded audio file (wav, mp3, m4a, etc.)"
                    },
                    "filename": {
                        "type": "string",
                        "description": "Original filename with extension (e.g., 'recording.wav')",
                        "default": "audio.wav"
                    },
                    "language": {
                        "type": "string",
                        "description": "Language code (e.g., 'en', 'he'). Leave empty for auto-detect.",
                        "default": ""
                    }
                },
                "required": ["audio_base64"]
            }
        ),
        Tool(
            name="transcribe_finetune",
            description="Transcribe audio using Daniel's fine-tuned Whisper model (optimized for his voice/accent). Returns raw transcription. Input: base64-encoded audio file.",
            inputSchema={
                "type": "object",
                "properties": {
                    "audio_base64": {
                        "type": "string",
                        "description": "Base64-encoded audio file (wav, mp3, m4a, etc.)"
                    },
                    "filename": {
                        "type": "string",
                        "description": "Original filename with extension (e.g., 'recording.wav')",
                        "default": "audio.wav"
                    },
                    "language": {
                        "type": "string",
                        "description": "Language code (e.g., 'en', 'he'). Leave empty for auto-detect.",
                        "default": ""
                    }
                },
                "required": ["audio_base64"]
            }
        ),
        Tool(
            name="transcribe_clean",
            description="Transcribe audio and clean up the text using Ollama LLM. Fixes punctuation, removes filler words, improves coherence. Input: base64-encoded audio file.",
            inputSchema={
                "type": "object",
                "properties": {
                    "audio_base64": {
                        "type": "string",
                        "description": "Base64-encoded audio file (wav, mp3, m4a, etc.)"
                    },
                    "filename": {
                        "type": "string",
                        "description": "Original filename with extension (e.g., 'recording.wav')",
                        "default": "audio.wav"
                    },
                    "language": {
                        "type": "string",
                        "description": "Language code (e.g., 'en', 'he'). Leave empty for auto-detect.",
                        "default": ""
                    },
                    "use_finetune": {
                        "type": "boolean",
                        "description": "Use fine-tuned model instead of large-v3-turbo",
                        "default": False
                    }
                },
                "required": ["audio_base64"]
            }
        ),
        Tool(
            name="whisper_health",
            description="Check Whisper service health and current model info",
            inputSchema={
                "type": "object",
                "properties": {}
            }
        )
    ]


async def call_whisper(audio_base64: str, filename: str, language: str = "", use_finetune: bool = False) -> dict:
    """Send audio to Whisper API for transcription"""
    # Decode base64 audio
    try:
        audio_bytes = base64.b64decode(audio_base64)
    except Exception as e:
        return {"error": f"Failed to decode base64 audio: {e}"}

    # Get file extension
    suffix = Path(filename).suffix or ".wav"

    # Write to temp file
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(audio_bytes)
        tmp_path = tmp.name

    try:
        # Prepare multipart form data
        files = {"file": (filename, open(tmp_path, "rb"))}
        data = {"restore_punctuation": "true"}
        if language:
            data["language"] = language
        if use_finetune:
            data["use_finetune"] = "true"

        async with httpx.AsyncClient(timeout=300.0) as client:
            response = await client.post(
                f"{WHISPER_URL}/transcribe",
                files=files,
                data=data
            )

            if response.status_code != 200:
                return {"error": f"Whisper API error: {response.status_code} - {response.text}"}

            return response.json()

    finally:
        # Clean up temp file
        try:
            os.unlink(tmp_path)
        except:
            pass


async def cleanup_with_ollama(text: str) -> str:
    """Clean up transcription using Ollama"""
    prompt = f"""Clean up this speech-to-text transcription. Fix punctuation, remove filler words (um, uh, like), fix obvious transcription errors, and improve readability while preserving the original meaning and tone. Return ONLY the cleaned text, no explanations.

Transcription:
{text}

Cleaned text:"""

    async with httpx.AsyncClient(timeout=120.0) as client:
        response = await client.post(
            f"{OLLAMA_URL}/api/generate",
            json={
                "model": OLLAMA_MODEL,
                "prompt": prompt,
                "stream": False
            }
        )

        if response.status_code != 200:
            raise Exception(f"Ollama API error: {response.status_code} - {response.text}")

        result = response.json()
        return result.get("response", "").strip()


@server.call_tool()
async def call_tool(name: str, arguments: dict) -> list[TextContent]:
    """Handle tool calls"""

    if name == "whisper_health":
        async with httpx.AsyncClient(timeout=10.0) as client:
            try:
                response = await client.get(f"{WHISPER_URL}/health")
                if response.status_code == 200:
                    health = response.json()
                    return [TextContent(
                        type="text",
                        text=f"Whisper Status: {health.get('status', 'unknown')}\n"
                             f"Model: {health.get('model', 'unknown')}\n"
                             f"Device: {health.get('device', 'unknown')}\n"
                             f"Punctuation Available: {health.get('punctuation_available', False)}"
                    )]
                else:
                    return [TextContent(type="text", text=f"Whisper API error: {response.status_code}")]
            except Exception as e:
                return [TextContent(type="text", text=f"Failed to connect to Whisper: {e}")]

    elif name == "transcribe_raw":
        audio_base64 = arguments.get("audio_base64", "")
        filename = arguments.get("filename", "audio.wav")
        language = arguments.get("language", "")

        result = await call_whisper(audio_base64, filename, language, use_finetune=False)

        if "error" in result:
            return [TextContent(type="text", text=f"Error: {result['error']}")]

        return [TextContent(
            type="text",
            text=f"**Transcription (large-v3-turbo):**\n\n{result.get('text', '')}\n\n"
                 f"Language: {result.get('language', 'unknown')}"
        )]

    elif name == "transcribe_finetune":
        audio_base64 = arguments.get("audio_base64", "")
        filename = arguments.get("filename", "audio.wav")
        language = arguments.get("language", "")

        result = await call_whisper(audio_base64, filename, language, use_finetune=True)

        if "error" in result:
            return [TextContent(type="text", text=f"Error: {result['error']}")]

        return [TextContent(
            type="text",
            text=f"**Transcription (fine-tuned model):**\n\n{result.get('text', '')}\n\n"
                 f"Language: {result.get('language', 'unknown')}"
        )]

    elif name == "transcribe_clean":
        audio_base64 = arguments.get("audio_base64", "")
        filename = arguments.get("filename", "audio.wav")
        language = arguments.get("language", "")
        use_finetune = arguments.get("use_finetune", False)

        # First, transcribe
        result = await call_whisper(audio_base64, filename, language, use_finetune=use_finetune)

        if "error" in result:
            return [TextContent(type="text", text=f"Error: {result['error']}")]

        raw_text = result.get("text", "")

        if not raw_text:
            return [TextContent(type="text", text="No speech detected in audio")]

        # Then clean up with Ollama
        try:
            cleaned_text = await cleanup_with_ollama(raw_text)
        except Exception as e:
            return [TextContent(
                type="text",
                text=f"**Raw Transcription:**\n{raw_text}\n\n**Cleanup failed:** {e}"
            )]

        model_name = "fine-tuned" if use_finetune else "large-v3-turbo"
        return [TextContent(
            type="text",
            text=f"**Cleaned Transcription ({model_name} + {OLLAMA_MODEL}):**\n\n{cleaned_text}\n\n"
                 f"---\n**Original (raw):**\n{raw_text}"
        )]

    else:
        return [TextContent(type="text", text=f"Unknown tool: {name}")]


def main():
    """Run the MCP server"""
    import asyncio
    asyncio.run(stdio_server(server))


if __name__ == "__main__":
    main()
