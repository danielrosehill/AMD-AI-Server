#!/usr/bin/env python3
"""
AMD AI Server Control Panel
A bespoke web UI for managing the AMD AI stack services.
"""

import asyncio
import subprocess
from pathlib import Path
from typing import Optional

import docker
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel

app = FastAPI(title="AMD AI Server Control Panel", version="1.0.0")

# Templates
templates = Jinja2Templates(directory=Path(__file__).parent / "templates")

# Docker client
docker_client = docker.from_env()

# Stack configuration - maps friendly names to container names and compose files
STACK_CONFIG = {
    "llm": {
        "name": "LLM Inference",
        "icon": "brain",
        "services": {
            "ollama": {
                "container": "ollama-rocm",
                "display": "Ollama",
                "port": 11434,
                "url": "http://localhost:11434",
            }
        },
    },
    "stt": {
        "name": "Speech-to-Text",
        "icon": "mic",
        "services": {
            "whisper": {
                "container": "whisper-rocm",
                "display": "Whisper",
                "port": 9000,
                "url": "http://localhost:9000",
            }
        },
    },
    "image": {
        "name": "Image Generation",
        "icon": "image",
        "services": {
            "comfyui": {
                "container": "comfyui",
                "display": "ComfyUI",
                "port": 8188,
                "url": "http://localhost:8188",
            }
        },
    },
    "tts": {
        "name": "Text-to-Speech",
        "icon": "volume-2",
        "services": {},  # To be populated when TTS is added
    },
}

# Compose file path
COMPOSE_PATH = Path(__file__).parent.parent / "docker-compose.yml"

# MCP Server configuration
MCP_CONFIG = {
    "name": "local-ai",
    "path": Path(__file__).parent.parent / "mcp-server",
    "command": str(Path(__file__).parent.parent / "mcp-server" / ".venv" / "bin" / "python"),
    "args": ["-m", "local_ai_mcp.server"],
    "env": {
        "WHISPER_URL": "http://localhost:9000",
        "OLLAMA_URL": "http://localhost:11434",
        "OLLAMA_MODEL": "llama3.2",
    },
    "tools": [
        {
            "name": "transcribe_raw",
            "description": "Transcribe audio using large-v3-turbo (general purpose)",
        },
        {
            "name": "transcribe_finetune",
            "description": "Transcribe using fine-tuned model (optimized for Daniel's voice)",
        },
        {
            "name": "transcribe_clean",
            "description": "Transcribe + clean up via Ollama (fixes punctuation, removes fillers)",
        },
        {
            "name": "whisper_health",
            "description": "Check Whisper service status and model info",
        },
    ],
}


class ServiceAction(BaseModel):
    action: str  # start, stop, restart


def get_container_status(container_name: str) -> dict:
    """Get status of a specific container."""
    try:
        container = docker_client.containers.get(container_name)
        return {
            "status": container.status,
            "running": container.status == "running",
            "health": container.attrs.get("State", {}).get("Health", {}).get("Status"),
            "started_at": container.attrs.get("State", {}).get("StartedAt"),
        }
    except docker.errors.NotFound:
        return {"status": "not_found", "running": False, "health": None, "started_at": None}
    except Exception as e:
        return {"status": "error", "running": False, "error": str(e)}


def get_gpu_info() -> dict:
    """Get AMD GPU information using rocm-smi."""
    try:
        # Try rocm-smi first
        result = subprocess.run(
            ["rocm-smi", "--showmeminfo", "vram", "--json"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode == 0:
            import json
            data = json.loads(result.stdout)
            # Parse ROCm SMI JSON output
            card = list(data.values())[0] if data else {}
            vram_used = int(card.get("VRAM Total Used Memory (B)", 0)) / (1024**3)
            vram_total = int(card.get("VRAM Total Memory (B)", 0)) / (1024**3)
            return {
                "available": True,
                "name": "AMD Radeon RX 7700 XT",
                "vram_used_gb": round(vram_used, 2),
                "vram_total_gb": round(vram_total, 2),
                "vram_percent": round((vram_used / vram_total) * 100, 1) if vram_total > 0 else 0,
            }
    except FileNotFoundError:
        pass
    except Exception as e:
        print(f"rocm-smi error: {e}")

    # Fallback - try reading from sysfs (check card0 and card1)
    try:
        for card in ["card1", "card0"]:
            vram_total_path = Path(f"/sys/class/drm/{card}/device/mem_info_vram_total")
            vram_used_path = Path(f"/sys/class/drm/{card}/device/mem_info_vram_used")
            if vram_total_path.exists() and vram_used_path.exists():
                break

        if vram_total_path.exists() and vram_used_path.exists():
            vram_total = int(vram_total_path.read_text().strip()) / (1024**3)
            vram_used = int(vram_used_path.read_text().strip()) / (1024**3)
            return {
                "available": True,
                "name": "AMD Radeon GPU",
                "vram_used_gb": round(vram_used, 2),
                "vram_total_gb": round(vram_total, 2),
                "vram_percent": round((vram_used / vram_total) * 100, 1) if vram_total > 0 else 0,
            }
    except Exception as e:
        print(f"sysfs error: {e}")

    return {"available": False, "name": "Unknown", "vram_used_gb": 0, "vram_total_gb": 0}


def get_all_services_status() -> dict:
    """Get status of all configured services."""
    result = {}
    for stack_id, stack_info in STACK_CONFIG.items():
        result[stack_id] = {
            "name": stack_info["name"],
            "icon": stack_info["icon"],
            "services": {},
        }
        for service_id, service_info in stack_info["services"].items():
            status = get_container_status(service_info["container"])
            result[stack_id]["services"][service_id] = {
                **service_info,
                **status,
            }
    return result


async def run_docker_compose(action: str, service: Optional[str] = None) -> dict:
    """Run docker compose command."""
    cmd = ["docker", "compose", "-f", str(COMPOSE_PATH)]

    if action == "start":
        cmd.extend(["up", "-d"])
    elif action == "stop":
        cmd.append("stop")
    elif action == "restart":
        cmd.append("restart")
    else:
        raise ValueError(f"Unknown action: {action}")

    if service:
        cmd.append(service)

    process = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await process.communicate()

    return {
        "success": process.returncode == 0,
        "stdout": stdout.decode(),
        "stderr": stderr.decode(),
        "returncode": process.returncode,
    }


# =============================================================================
# API Routes
# =============================================================================


@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    """Render the main control panel."""
    services = get_all_services_status()
    gpu = get_gpu_info()
    return templates.TemplateResponse(
        "index.html",
        {"request": request, "stacks": services, "gpu": gpu},
    )


@app.get("/api/status")
async def api_status():
    """Get status of all services."""
    return {
        "services": get_all_services_status(),
        "gpu": get_gpu_info(),
    }


@app.get("/api/gpu")
async def api_gpu():
    """Get GPU information."""
    return get_gpu_info()


@app.post("/api/service/{service_name}")
async def api_service_action(service_name: str, action: ServiceAction):
    """Perform action on a service."""
    # Find the service in our config
    for stack_id, stack_info in STACK_CONFIG.items():
        if service_name in stack_info["services"]:
            result = await run_docker_compose(action.action, service_name)
            return result

    raise HTTPException(status_code=404, detail=f"Service {service_name} not found")


@app.post("/api/stack/{stack_id}")
async def api_stack_action(stack_id: str, action: ServiceAction):
    """Perform action on all services in a stack."""
    if stack_id not in STACK_CONFIG:
        raise HTTPException(status_code=404, detail=f"Stack {stack_id} not found")

    results = {}
    for service_name in STACK_CONFIG[stack_id]["services"]:
        results[service_name] = await run_docker_compose(action.action, service_name)

    return results


@app.get("/api/logs/{service_name}")
async def api_logs(service_name: str, lines: int = 100):
    """Get recent logs for a service."""
    # Find container name
    container_name = None
    for stack_info in STACK_CONFIG.values():
        if service_name in stack_info["services"]:
            container_name = stack_info["services"][service_name]["container"]
            break

    if not container_name:
        raise HTTPException(status_code=404, detail=f"Service {service_name} not found")

    try:
        container = docker_client.containers.get(container_name)
        logs = container.logs(tail=lines, timestamps=True).decode("utf-8", errors="replace")
        return {"logs": logs}
    except docker.errors.NotFound:
        raise HTTPException(status_code=404, detail=f"Container {container_name} not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/mcp")
async def api_mcp():
    """Get MCP server configuration and code samples."""
    import json

    # Generate config snippets
    claude_desktop_config = {
        "mcpServers": {
            MCP_CONFIG["name"]: {
                "command": MCP_CONFIG["command"],
                "args": MCP_CONFIG["args"],
                "env": MCP_CONFIG["env"],
            }
        }
    }

    mcpm_command = (
        f"mcpm new {MCP_CONFIG['name']} "
        f"--type stdio "
        f"--command \"{MCP_CONFIG['command']}\" "
        f"--args \"{' '.join(MCP_CONFIG['args'])}\" "
        f"--env \"{','.join(f'{k}={v}' for k, v in MCP_CONFIG['env'].items())}\" "
        f"--force"
    )

    return {
        "name": MCP_CONFIG["name"],
        "tools": MCP_CONFIG["tools"],
        "env": MCP_CONFIG["env"],
        "configs": {
            "claude_desktop": json.dumps(claude_desktop_config, indent=2),
            "mcpm_command": mcpm_command,
        },
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8090)
