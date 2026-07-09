import re

class MemoryManager:
    """Manages adaptive conversation logging, importance scoring, and database compression."""
    
    def __init__(self, db_manager):
        self.db = db_manager
        # Keywords indicating factual references, preference settings, or tasks
        self.high_importance_keywords = [
            r"\bprefer\b", r"\blike\b", r"\blove\b", r"\bhate\b", 
            r"\bfavorite\b", r"\bname is\b", r"\bsetting\b", 
            r"\bremind\b", r"\bschedule\b", r"\btask\b", 
            r"\bworking on\b", r"\bproject\b", r"\bworkspace\b",
            r"\bpassword\b", r"\btoken\b", r"\bconfig\b"
        ]

    def analyze_and_store(self, message: str, speaker: str, emotion: str = "neutral"):
        """Logs conversation and checks if it contains details worth adding to long-term memory."""
        # 1. Log every message to conversation history
        self.db.log_message(speaker, message, emotion)
        
        # 2. Check importance of user messages for long-term memory storage
        if speaker == "user":
            importance = self._calculate_importance(message)
            if importance >= 6:
                # Store in semantic memory database
                self.db.add_memory(
                    content=message,
                    summary=f"Factual statement with importance {importance}",
                    importance=importance
                )
                
                # Check database size and prune if needed to prevent storage blow-up
                self.db.compress_memories(max_records=150)

    def _calculate_importance(self, text: str) -> int:
        """Determines the semantic importance score (1-10) of a message."""
        cleaned = text.lower()
        score = 2 # Default chatter
        
        # Check high-importance matches
        for pattern in self.high_importance_keywords:
            if re.search(pattern, cleaned):
                score += 3
                
        # Length check (very short statements are usually greeting or confirmations)
        if len(text.split()) > 15:
            score += 2
        elif len(text.split()) < 4:
            score -= 1
            
        # Hard limits
        return max(1, min(10, score))

    def retrieve_context(self, text: str) -> str:
        """Queries database for past interactions matching keywords and returns summary context."""
        keywords = self._extract_keywords(text)
        context_items = []
        
        # Query memories for each keyword
        seen_ids = set()
        for kw in keywords[:3]: # Limit queries
            memories = self.db.query_memories(query_string=kw, limit=2)
            for mem in memories:
                if mem["id"] not in seen_ids:
                    seen_ids.add(mem["id"])
                    context_items.append(mem["content"])
                    
        if context_items:
            return "Retrieved Context:\n" + "\n".join([f"- {item}" for item in context_items])
        return ""

    def _extract_keywords(self, text: str) -> list:
        """Extracts significant words (nouns/verbs) to run keyword lookups."""
        words = re.findall(r"\b[a-zA-Z]{4,}\b", text.lower())
        # Filter common stopwords
        stopwords = {
            "this", "that", "there", "their", "them", "then", "with",
            "have", "your", "what", "how", "when", "where", "here"
        }
        return [w for w in words if w not in stopwords]
