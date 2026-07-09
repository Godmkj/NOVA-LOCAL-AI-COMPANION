import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
import asyncio
import json
import os
import subprocess
import requests

from database.db_manager import DatabaseManager
from monitoring.stats import get_system_stats
from agents.classifier import CommandClassifier
from agents.task_engine import TaskEngine
from agents.memory import MemoryManager
from automation.os_control import OSControlBridge
from voice.tts import PiperTTS

app = FastAPI(title="NOVA AI Daemon Core", version="1.0.0")

# Enable CORS for local cross-origin connections (e.g. from file:// index.html)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize engines
db = DatabaseManager(db_path="data/nova.db")
memory = MemoryManager(db)
os_bridge = OSControlBridge()
tts_engine = PiperTTS(root_path=os.path.dirname(os.path.abspath(__file__)))
classifier = CommandClassifier()
task_engine = TaskEngine(db)

# Register automation actions into TaskEngine
task_engine.register_action("open_app", os_bridge.open_application)
task_engine.register_action("close_app", os_bridge.close_application)
task_engine.register_action("create_file", os_bridge.write_workspace_file)
task_engine.register_action("create_note", os_bridge.write_workspace_file)
task_engine.register_action("create_pdf", os_bridge.create_summary_pdf)
task_engine.register_action("search_web", os_bridge.launch_safe_search)
task_engine.register_action("system_stats", lambda: json.dumps(get_system_stats()))
task_engine.register_action("help", lambda: "NOVA can chat locally, open apps, create files, generate PDFs, monitor the system, and run safe workflows.")
task_engine.register_action("weather_check", lambda location=None: f"Weather lookup queued for {location or 'your saved location'}.")
task_engine.register_action("news_check", lambda: "News summary workflow queued.")


def is_ollama_cli_available(ollama_exe: str) -> bool:
    try:
        command = [ollama_exe if os.path.exists(ollama_exe) else "ollama", "tags"]
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=10,
            encoding="utf-8",
            errors="replace",
        )
        return result.returncode == 0
    except Exception:
        return False


def get_ollama_model_status(model: str, ollama_exe: str) -> dict:
    status = {
        "cli": False,
        "api": False,
        "model_installed": False,
        "model_name": model,
    }

    if is_ollama_cli_available(ollama_exe):
        status["cli"] = True
        try:
            command = [ollama_exe if os.path.exists(ollama_exe) else "ollama", "tags"]
            result = subprocess.run(
                command,
                capture_output=True,
                text=True,
                timeout=10,
                encoding="utf-8",
                errors="replace",
            )
            if result.returncode == 0:
                installed_models = [line.strip() for line in result.stdout.splitlines() if line.strip()]
                status["model_installed"] = any(model in item for item in installed_models)
        except Exception:
            pass

    try:
        response = requests.get("http://127.0.0.1:11434/api/tags", timeout=3)
        if response.ok:
            status["api"] = True
            tags = response.json()
            if isinstance(tags, list):
                status["model_installed"] = status["model_installed"] or any(model in str(tag) for tag in tags)
    except Exception:
        pass

    return status


@app.get("/api/ollama/status")
async def get_ollama_status():
    model = db.get_preference("ollama_model", os.environ.get("NOVA_OLLAMA_MODEL", "llama3.2:1b"))
    ollama_exe = db.get_preference(
        "ollama_exe",
        os.environ.get(
            "NOVA_OLLAMA_EXE",
            os.path.expanduser(r"~\AppData\Local\Programs\Ollama\ollama.exe"),
        ),
    )
    return get_ollama_model_status(model, ollama_exe)

# Active WebSocket connections
active_connections = set()

async def stats_broadcast_loop():
    """Periodically broadcasts CPU, RAM, and system stats to connected clients."""
    while True:
        if active_connections:
            try:
                stats = get_system_stats()
                payload = {
                    "type": "system_stats",
                    "data": stats
                }
                # Broadcast
                for ws in list(active_connections):
                    try:
                        await ws.send_text(json.dumps(payload))
                    except Exception:
                        active_connections.remove(ws)
            except Exception as e:
                print(f"Error in stats loop: {e}")
        await asyncio.sleep(2.0)

# Start background stats loop on startup
@app.on_event("startup")
async def startup_event():
    asyncio.create_task(stats_broadcast_loop())

@app.get("/api/history")
async def get_chat_history():
    return {"history": db.get_recent_history(limit=30)}

@app.get("/api/tasks")
async def get_active_tasks():
    return {"tasks": db.get_active_tasks()}

@app.get("/api/memories")
async def get_semantic_memories():
    return {"memories": db.query_memories(limit=10)}

@app.get("/api/ollama/models")
async def get_ollama_models():
    try:
        response = requests.get("http://127.0.0.1:11434/api/tags", timeout=3)
        response.raise_for_status()
        return response.json()
    except Exception as exc:
        return {"models": [], "error": str(exc)}

@app.get("/api/voice/status")
async def get_voice_status():
    return {
        "engine": "piper",
        "voice": "en_US-amy-medium",
        "ready": tts_engine.is_ready()
    }

@app.post("/api/voice/speak")
async def speak_text(payload: dict):
    text = str(payload.get("text", ""))
    try:
        output_path = await asyncio.to_thread(tts_engine.synthesize, text)
        return {"ok": True, "audio_path": output_path}
    except Exception as exc:
        return {"ok": False, "error": str(exc)}

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    active_connections.add(websocket)
    print("UI Client connected to WebSocket.")
    
    model = db.get_preference("ollama_model", os.environ.get("NOVA_OLLAMA_MODEL", "llama3.2:1b"))
    ollama_exe = db.get_preference(
        "ollama_exe",
        os.environ.get(
            "NOVA_OLLAMA_EXE",
            os.path.expanduser(r"~\AppData\Local\Programs\Ollama\ollama.exe"),
        ),
    )
    ollama_status = get_ollama_model_status(model, ollama_exe)

    # Send initial configuration details
    await websocket.send_text(json.dumps({
        "type": "welcome",
        "data": {
            "assistant_name": db.get_preference("assistant_name", "NOVA"),
            "user_name": db.get_preference("user_name", "User"),
            "voice_enabled": db.get_preference("voice_enabled", "true") == "true",
            "ollama_available": ollama_status.get("model_installed", False),
            "ollama_model": ollama_status.get("model_name", model),
        }
    }))
    
    try:
        while True:
            data = await websocket.receive_text()
            message = json.loads(data)
            
            if message.get("type") == "user_prompt":
                prompt_text = message.get("text", "")
                print(f"Received prompt: {prompt_text}")
                
                # Log prompt to database
                memory.analyze_and_store(prompt_text, speaker="user")
                
                # Check semantic database for memories
                context = memory.retrieve_context(prompt_text)
                
                # Try Command Classifier
                classification = classifier.classify(prompt_text)
                
                if classification:
                    intent = classification["intent"]
                    params = classification["parameters"]
                    print(f"Classifier matched intent: {intent} with params {params}")
                    
                    # Create background task for execution
                    task_title = f"Execute action: {intent.replace('_', ' ')}"
                    steps = [{"action": intent, "params": params, "retries": 1}]
                    task_id = task_engine.submit_workflow(task_title, steps)
                    
                    # Notify UI of immediate command interception
                    response_text = f"Executing '{intent.replace('_', ' ')}' command. Tracking task id: {task_id[:8]}"
                    memory.analyze_and_store(response_text, speaker="nova")
                    
                    await websocket.send_text(json.dumps({
                        "type": "assistant_response",
                        "data": {
                            "text": response_text,
                            "classified": True,
                            "intent": intent,
                            "task_id": task_id,
                            "context": context
                        }
                    }))
                else:
                    # Run local Ollama response with simulated fallback
                    print("Prompt routed to Local LLM Engine.")
                    response_text = await generate_local_companion_response(prompt_text, context)
                    
                    memory.analyze_and_store(response_text, speaker="nova")
                    
                    # Stream letters back to simulate network/model latency
                    words = response_text.split(" ")
                    accumulated = ""
                    for w in words:
                        accumulated += w + " "
                        await websocket.send_text(json.dumps({
                            "type": "assistant_stream",
                            "data": {
                                "text": accumulated,
                                "done": False,
                                "context": context
                            }
                        }))
                        await asyncio.sleep(0.08) # Simulating streaming speed
                        
                    await websocket.send_text(json.dumps({
                        "type": "assistant_stream",
                        "data": {
                            "text": response_text,
                            "done": True,
                            "context": context
                        }
                    }))
                    
            elif message.get("type") == "set_preference":
                key = message.get("key")
                val = message.get("value")
                db.set_preference(key, val)
                print(f"Updated setting: {key} -> {val}")
                
    except WebSocketDisconnect:
        active_connections.remove(websocket)
        print("UI Client disconnected.")

async def generate_local_companion_response(prompt: str, context: str) -> str:
    """Generates a NOVA response using Ollama first, then deterministic local fallback."""
    model = db.get_preference("ollama_model", os.environ.get("NOVA_OLLAMA_MODEL", "llama3.2:1b"))
    ollama_exe = db.get_preference(
        "ollama_exe",
        os.environ.get(
            "NOVA_OLLAMA_EXE",
            os.path.expanduser(r"~\AppData\Local\Programs\Ollama\ollama.exe"),
        ),
    )
    system_prompt = (
        "You are NOVA, a privacy-first local desktop AI companion. "
        "Reply naturally, adapt to the user's tone and language, keep answers useful, "
        "and choose answer depth by weight: simple/chat questions get one direct answer; "
        "medium how-to questions may get two options; only complex, high-stakes, planning, "
        "coding, or comparison questions get three perspectives. Do not force three answers. "
        "Never claim cloud access."
    )

    messages = [{"role": "system", "content": system_prompt}]
    if context:
        messages.append({"role": "system", "content": f"Relevant local memory:\n{context}"})
    messages.append({"role": "user", "content": prompt})

    cli_prompt = f"{system_prompt}\n\nRelevant local memory:\n{context or 'None'}\n\nUser: {prompt}\nNOVA:"

    def _call_ollama_cli():
        command = [ollama_exe if os.path.exists(ollama_exe) else "ollama", "run", model, cli_prompt]
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=120,
            encoding="utf-8",
            errors="replace",
        )
        if result.returncode != 0:
            raise RuntimeError(result.stderr.strip() or "Ollama CLI failed")
        return result.stdout.strip()

    def _call_ollama():
        response = requests.post(
            "http://127.0.0.1:11434/api/chat",
            json={"model": model, "messages": messages, "stream": False},
            timeout=90,
        )
        response.raise_for_status()
        payload = response.json()
        return payload.get("message", {}).get("content", "").strip()

    try:
        reply = await asyncio.to_thread(_call_ollama_cli)
        if reply:
            return reply
    except Exception as exc:
        print(f"Ollama CLI unavailable, trying local API: {exc}")

    try:
        reply = await asyncio.to_thread(_call_ollama)
        if reply:
            return reply
    except Exception as exc:
        print(f"Ollama unavailable, using fallback response: {exc}")

    return generate_simulated_companion_response(prompt, context)

def generate_simulated_companion_response(prompt: str, context: str) -> str:
    """Generates an intelligent, warm conversational response based on user prompts."""
    text = prompt.lower()
    
    if "hello" in text or "hi" in text:
        return "Hello! I am NOVA, your local AI companion. How is your day going? I'm ready to open applications, check performance, or keep logs for you."
    elif "who are you" in text:
        return "I am NOVA, a privacy-first assistant running locally on your computer. I keep your workspace, automations, and files secure without any cloud dependencies."
    elif "create study notes" in text or "study notes" in text:
        return "Of course. I can compile a workspace note on that topic and format it as a clean PDF document for you immediately."
    elif "pomodoro" in text:
        return "A Pomodoro timer is a great workflow! I can track your work intervals and monitor system activities in the background to ensure you remain focused."
    else:
        # Generic conversational fallback with intelligence
        base_reply = "I understand you are asking about that. As a local companion, I can execute desktop actions, file creations, or perform search inquiries for you."
        if context:
            base_reply += " Drawing on your preferences, I'll structure this around your saved habits."
        return base_reply

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)
