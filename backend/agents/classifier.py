import re

class CommandClassifier:
    """Classifies user instructions into predefined actions without calling LLMs."""
    
    def __init__(self):
        # Intent routing map using regex patterns
        self.patterns = {
            "open_app": [
                r"^(?:open|launch|start|run)\s+([a-zA-Z0-9\s\.\-_]+)$"
            ],
            "close_app": [
                r"^(?:close|kill|stop|terminate)\s+([a-zA-Z0-9\s\.\-_]+)$"
            ],
            "system_stats": [
                r"\b(?:system stats|pc info|cpu|ram|battery|computer|hardware|performance)\b"
            ],
            "create_note": [
                r"^(?:create|write|make|generate)\s+(?:a\s+)?(?:note|file|text|memo)\s+(?:called|named)?\s*([a-zA-Z0-9\s\.\-_]+)$",
                r"^(?:write|save)\s+[\"'](.*)[\"']\s+to\s+([a-zA-Z0-9\s\.\-_]+)$"
            ],
            "weather_check": [
                r"\bweather\b",
                r"\btemperature\b",
                r"\bforecast\b"
            ],
            "news_check": [
                r"\bnews\b",
                r"\bheadlines\b",
                r"\bwhat's happening\b"
            ],
            "help": [
                r"\b(?:help|commands|what can you do|features)\b"
            ]
        }

    def classify(self, text: str):
        """Analyzes a text prompt and returns structured intent if matched, else None."""
        cleaned_text = text.strip().lower()
        
        # 1. Open App Intent
        for pattern in self.patterns["open_app"]:
            match = re.match(pattern, cleaned_text)
            if match:
                app_name = match.group(1).strip()
                return {
                    "intent": "open_app",
                    "parameters": {"app_name": app_name},
                    "confidence": 1.0
                }
                
        # 2. Close App Intent
        for pattern in self.patterns["close_app"]:
            match = re.match(pattern, cleaned_text)
            if match:
                app_name = match.group(1).strip()
                return {
                    "intent": "close_app",
                    "parameters": {"app_name": app_name},
                    "confidence": 1.0
                }

        # 3. Create Note Intent
        for pattern in self.patterns["create_note"]:
            match = re.match(pattern, cleaned_text)
            if match:
                if len(match.groups()) == 2:
                    content, filename = match.group(1), match.group(2)
                else:
                    filename = match.group(1)
                    content = "Blank note created by NOVA."
                return {
                    "intent": "create_note",
                    "parameters": {"filename": filename.strip(), "content": content},
                    "confidence": 1.0
                }

        # 4. System Status Intent
        for pattern in self.patterns["system_stats"]:
            if re.search(pattern, cleaned_text):
                return {
                    "intent": "system_stats",
                    "parameters": {},
                    "confidence": 0.9
                }

        # 5. Weather check
        for pattern in self.patterns["weather_check"]:
            if re.search(pattern, cleaned_text):
                # Extract potential location if mentioned
                location_match = re.search(r"in\s+([a-zA-Z\s]+)$", cleaned_text)
                location = location_match.group(1).strip() if location_match else None
                return {
                    "intent": "weather_check",
                    "parameters": {"location": location},
                    "confidence": 0.95
                }

        # 6. News check
        for pattern in self.patterns["news_check"]:
            if re.search(pattern, cleaned_text):
                return {
                    "intent": "news_check",
                    "parameters": {},
                    "confidence": 0.9
                }

        # 7. Help Commands
        for pattern in self.patterns["help"]:
            if re.search(pattern, cleaned_text):
                return {
                    "intent": "help",
                    "parameters": {},
                    "confidence": 0.95
                }
                
        # Fallback to LLM
        return None
