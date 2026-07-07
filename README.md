# NOVA Companion OS

> NOVA is your local privacy-first AI companion for Windows desktop — powerful, secure, and built to run without sending data to the cloud.

---

## 🔥 What is NOVA?

NOVA is a desktop AI assistant that combines:

- **Flutter desktop UI** (`frontend/`) for a futuristic local interface
- **Python FastAPI daemon** (`backend/main.py`) for task routing, voice, and automation
- **Local Ollama AI models** for private on-device reasoning
- **TTS voice**, memory, command automation, and desktop workflows

This project is designed so your AI experience stays local, private, and fast.

---

## ⬇️ **IMPORTANT: Download the Complete Package**

> **You must download the Z7 zip file that contains all necessary files before starting.**
> 
> The complete NOVA package includes:
> - All source code (frontend + backend)
> - Pre-configured settings and dependencies
> - Launch scripts and utilities
> - All required project files
>
> **Simply extract the zip file and follow the setup guide below.**

---

## 🚀 Why this is powerful

- **Local privacy first**: NOVA prefers local Ollama models and never relies on external cloud inference by default.
- **Smart fallback**: If Ollama is unavailable, NOVA still responds with a deterministic local companion fallback.
- **Desktop automation**: Open apps, create notes/PDFs, execute workflows, and interact with the OS.
- **Voice-enabled**: Local TTS lets NOVA speak without cloud audio services.
- **Modern UI**: A polished Flutter dashboard with a status panel and system telemetry.

---

## 🧠 Architecture overview

| Layer | Folder | Purpose |
|---|---|---|
| UI | `frontend/` | Flutter desktop interface, chat, status, automation buttons |
| Backend | `backend/` | Python daemon, Ollama integration, memory, task engine |
| Voice | `backend/voice/` | Local TTS using Piper and on-device speech generation |
| Database | `backend/database/` | Local history, memories, and preferences |

---

## ✅ Recommended Ollama model

The default model used by NOVA is:

- `llama3.2:1b`

This model is a great balance of local speed and helpfulness for desktop assistant tasks.

If you want a stronger model later, NOVA can be configured to use any local Ollama model you install.

---

## � Quick Start - Download Complete Package

**The easiest way to get started:**

Download the complete NOVA package (Z7 zip file) which includes all dependencies and pre-configured files:

- Extract the `.7z` or `.zip` file to your desired location
- All necessary files and dependencies are included
- No additional downloads required beyond Ollama

---

## �🛠️ Setup guide

### 1. Install prerequisites

- **Windows 10 / 11**
- **Python 3.11+**
- **Flutter SDK** (desktop enabled)
- **Ollama** installed locally

### 2. Install backend dependencies

Open a terminal in `backend/` and run:

```powershell
pip install -r requirements.txt
```

### 3. Install Flutter dependencies

Open a terminal in `frontend/` and run:

```powershell
flutter pub get
```

### 4. Install Ollama

Visit:

- https://ollama.ai

Then download and install the Windows version.

Or use winget:

```powershell
winget install Ollama.Ollama
```

### 5. Download the recommended model

After Ollama is installed, download the model with:

```powershell
ollama pull llama3.2:1b
```

This ensures NOVA can connect to the local model quickly.

---

## ▶️ Launch NOVA

### Option A: Start with the launcher

Double-click or run:

```powershell
Launch_NOVA.bat
```

This opens the desktop launcher and starts the Nova UI.

### Option B: Start backend and frontend manually

Open one terminal in `backend/`:

```powershell
python main.py
```

Open another terminal in `frontend/`:

```powershell
flutter run -d windows
```

---

## 🔌 How NOVA connects to Ollama

1. **Frontend** connects to the backend over WebSocket.
2. **Backend** sends user prompts to Ollama first.
3. **Ollama** runs locally via:
   - Ollama CLI, or
   - local Ollama API at `http://127.0.0.1:11434`
4. If Ollama is missing, NOVA uses a friendly local fallback response.

This means the UI, backend, and model all run on your machine.

---

## 🧩 How to use NOVA

### Example commands

- `Open Notepad`
- `Create PDF`
- `Summarize a page`
- `Generate study notes`
- `What is the weather in Kochi?`

### What NOVA can do

- Local chat and assistant responses
- Open and close applications
- Create files and PDFs in your workspace
- Run safe workflows and memory-driven actions
- Speak responses using local voice synthesis

---

## ⚠️ Troubleshooting

### Ollama not found

If the local Ollama model is unavailable, NOVA will show a warning in the dashboard and provide two options:

- `Open Launch_NOVA.bat`
- `Install Ollama`

### Common fix

1. Ensure Ollama is installed.
2. Run `ollama pull llama3.2:1b`.
3. Restart the backend and frontend.

---

## 🌟 Best experience notes

- Keep the backend running while using the UI.
- Install the default model before launching NOVA.
- Use the built-in status panel to verify Ollama availability.
- Customize the model path using `NOVA_OLLAMA_EXE` or app preferences if needed.

---

## 💡 Project highlights

- Privacy-focused local AI companion
- Clean Flutter desktop experience
- Local Ollama integration with fallback support
- Voice, memory, automation, and system metrics

---

## 📌 Author

**Monish K Jayan**

- GitHub: [@Godmkj](https://github.com/Godmkj)
- X / Twitter: [@MONISHKJAYAN](https://x.com/MONISHKJAYAN)

---

## � License

This project is licensed under the **MIT License**. See the `LICENSE` file for full details.

---

## �🗂️ Useful commands

```powershell
# Run backend
cd backend
python main.py

# Run frontend
cd frontend
flutter run -d windows

# Pull recommended Ollama model
ollama pull llama3.2:1b
```
