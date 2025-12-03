# Local AI MCP Server

MCP server providing unified access to local AI services (Whisper STT, Ollama LLM).

## Tools

| Tool | Description |
|------|-------------|
| `transcribe_raw` | Transcribe audio using large-v3-turbo (general purpose) |
| `transcribe_finetune` | Transcribe using Daniel's fine-tuned model (optimized for his voice) |
| `transcribe_clean` | Transcribe + clean up text via Ollama (fixes punctuation, removes filler words) |
| `whisper_health` | Check Whisper service status |

## Setup

```bash
cd mcp-server

# Create venv and install
uv venv
source .venv/bin/activate
uv pip install -e .
```

## Claude Desktop Configuration

Add to `~/.config/claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "local-ai": {
      "command": "/home/daniel/repos/github/AMD-AI-Server/mcp-server/run.sh",
      "env": {
        "WHISPER_URL": "http://localhost:9000",
        "OLLAMA_URL": "http://localhost:11434",
        "OLLAMA_MODEL": "llama3.2"
      }
    }
  }
}
```

## Claude Code Configuration

Add to `~/.claude/settings.json` under `mcpServers`:

```json
{
  "mcpServers": {
    "local-ai": {
      "command": "/home/daniel/repos/github/AMD-AI-Server/mcp-server/run.sh",
      "env": {
        "WHISPER_URL": "http://localhost:9000",
        "OLLAMA_URL": "http://localhost:11434",
        "OLLAMA_MODEL": "llama3.2"
      }
    }
  }
}
```

## Requirements

- Whisper service running on port 9000 (from AMD-AI-Server stack)
- Ollama running on port 11434 (for `transcribe_clean`)

## Usage

Audio must be provided as base64-encoded data. Example in Python:

```python
import base64

with open("recording.wav", "rb") as f:
    audio_b64 = base64.b64encode(f.read()).decode()

# Then pass audio_b64 to the MCP tool
```
