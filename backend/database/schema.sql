-- SQLite database schema for NOVA AI

PRAGMA foreign_keys = ON;

-- User Profile Preferences
CREATE TABLE IF NOT EXISTS user_profile (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Conversation History Logs
CREATE TABLE IF NOT EXISTS conversation_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    speaker TEXT NOT NULL, -- 'user' or 'nova'
    message TEXT NOT NULL,
    emotion TEXT DEFAULT 'neutral'
);

-- Task Queue for Automation Engines
CREATE TABLE IF NOT EXISTS task_queue (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    steps_json TEXT NOT NULL, -- JSON array of steps
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'running', 'completed', 'failed'
    current_step_index INTEGER DEFAULT 0,
    logs TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Adaptive Memory Index
CREATE TABLE IF NOT EXISTS semantic_memory (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    content TEXT NOT NULL,
    summary TEXT,
    importance INTEGER DEFAULT 5, -- Scale of 1 to 10 for pruning
    access_count INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_accessed TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
