import os
import sqlite3
import json
from datetime import datetime

class DatabaseManager:
    def __init__(self, db_path="nova.db"):
        self.db_path = db_path
        self.init_db()

    def get_connection(self):
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def init_db(self):
        # Create directories if they don't exist
        os.makedirs(os.path.dirname(os.path.abspath(self.db_path)), exist_ok=True)
        
        # Load schema definition
        schema_path = os.path.join(os.path.dirname(__file__), "schema.sql")
        schema_content = ""
        
        if os.path.exists(schema_path):
            with open(schema_path, "r", encoding="utf-8") as f:
                schema_content = f.read()
        else:
            # Fallback if file isn't found
            schema_content = """
            CREATE TABLE IF NOT EXISTS user_profile (
                key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            CREATE TABLE IF NOT EXISTS conversation_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                speaker TEXT NOT NULL, message TEXT NOT NULL, emotion TEXT DEFAULT 'neutral'
            );
            CREATE TABLE IF NOT EXISTS task_queue (
                id TEXT PRIMARY KEY, title TEXT NOT NULL, steps_json TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'pending', current_step_index INTEGER DEFAULT 0,
                logs TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            CREATE TABLE IF NOT EXISTS semantic_memory (
                id INTEGER PRIMARY KEY AUTOINCREMENT, content TEXT NOT NULL, summary TEXT,
                importance INTEGER DEFAULT 5, access_count INTEGER DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, last_accessed TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            """

        with self.get_connection() as conn:
            conn.executescript(schema_content)
            conn.commit()

    # User Profiles
    def set_preference(self, key, value):
        with self.get_connection() as conn:
            conn.execute(
                "INSERT OR REPLACE INTO user_profile (key, value, updated_at) VALUES (?, ?, CURRENT_TIMESTAMP)",
                (key, str(value))
            )
            conn.commit()

    def get_preference(self, key, default=None):
        with self.get_connection() as conn:
            cursor = conn.execute("SELECT value FROM user_profile WHERE key = ?", (key,))
            row = cursor.fetchone()
            return row["value"] if row else default

    # Conversations
    def log_message(self, speaker, message, emotion="neutral"):
        with self.get_connection() as conn:
            conn.execute(
                "INSERT INTO conversation_history (speaker, message, emotion) VALUES (?, ?, ?)",
                (speaker, message, emotion)
            )
            conn.commit()

    def get_recent_history(self, limit=20):
        with self.get_connection() as conn:
            cursor = conn.execute(
                "SELECT speaker, message, emotion, timestamp FROM conversation_history ORDER BY id DESC LIMIT ?",
                (limit,)
            )
            rows = cursor.fetchall()
            # Convert to chronological order
            history = [{"speaker": row["speaker"], "message": row["message"], "emotion": row["emotion"], "timestamp": row["timestamp"]} for row in rows]
            history.reverse()
            return history

    # Task Queue Actions
    def add_task(self, task_id, title, steps):
        with self.get_connection() as conn:
            conn.execute(
                "INSERT INTO task_queue (id, title, steps_json, status, current_step_index) VALUES (?, ?, ?, 'pending', 0)",
                (task_id, title, json.dumps(steps))
            )
            conn.commit()

    def update_task_status(self, task_id, status, current_step=0, logs=None):
        with self.get_connection() as conn:
            conn.execute(
                "UPDATE task_queue SET status = ?, current_step_index = ?, logs = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
                (status, current_step, logs, task_id)
            )
            conn.commit()

    def get_active_tasks(self):
        with self.get_connection() as conn:
            cursor = conn.execute(
                "SELECT id, title, steps_json, status, current_step_index, logs FROM task_queue WHERE status IN ('pending', 'running') ORDER BY created_at ASC"
            )
            return [dict(row) for row in cursor.fetchall()]

    # Adaptive Semantic Memory
    def add_memory(self, content, summary=None, importance=5):
        with self.get_connection() as conn:
            conn.execute(
                "INSERT INTO semantic_memory (content, summary, importance) VALUES (?, ?, ?)",
                (content, summary, importance)
            )
            conn.commit()

    def query_memories(self, query_string=None, limit=5):
        # Local keyword-based matching for SQLite (mock semantic lookup)
        with self.get_connection() as conn:
            if query_string:
                cursor = conn.execute(
                    "SELECT id, content, summary, importance, access_count FROM semantic_memory WHERE content LIKE ? OR summary LIKE ? ORDER BY importance DESC, access_count DESC LIMIT ?",
                    (f"%{query_string}%", f"%{query_string}%", limit)
                )
            else:
                cursor = conn.execute(
                    "SELECT id, content, summary, importance, access_count FROM semantic_memory ORDER BY importance DESC LIMIT ?",
                    (limit,)
                )
            rows = cursor.fetchall()
            
            # Increment access count to measure dynamic weightings
            for row in rows:
                conn.execute(
                    "UPDATE semantic_memory SET access_count = access_count + 1, last_accessed = CURRENT_TIMESTAMP WHERE id = ?",
                    (row["id"],)
                )
            conn.commit()
            
            return [dict(row) for row in rows]

    def compress_memories(self, max_records=100):
        # Pruning system: Delete low importance, low access count memories when database exceeds count limit
        with self.get_connection() as conn:
            cursor = conn.execute("SELECT COUNT(*) FROM semantic_memory")
            count = cursor.fetchone()[0]
            if count > max_records:
                prune_limit = count - max_records
                # Delete items with low importance and low access counts first
                conn.execute(
                    "DELETE FROM semantic_memory WHERE id IN (SELECT id FROM semantic_memory ORDER BY importance ASC, access_count ASC LIMIT ?)",
                    (prune_limit,)
                )
                conn.commit()
