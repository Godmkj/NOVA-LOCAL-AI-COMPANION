import threading
import time
import queue
import uuid
import json
import traceback
from typing import List, Dict, Callable

class TaskEngine:
    """Manages the background execution of tasks, command chaining, and auto-retries."""
    
    def __init__(self, db_manager):
        self.db = db_manager
        self.task_queue = queue.Queue()
        self.active_workers = {}
        self.registry = {} # Registers executable automation functions
        self.is_running = True
        
        # Start background worker thread
        self.worker_thread = threading.Thread(target=self._process_queue, daemon=True)
        self.worker_thread.start()

    def register_action(self, name: str, func: Callable):
        """Registers a Python function as an automated action."""
        self.registry[name] = func

    def submit_workflow(self, title: str, steps: List[Dict]) -> str:
        """Submits a multi-step workflow. Each step has 'action' name and 'params'."""
        task_id = str(uuid.uuid4())
        self.db.add_task(task_id, title, steps)
        self.task_queue.put({
            "id": task_id,
            "title": title,
            "steps": steps
        })
        return task_id

    def _process_queue(self):
        """Infinite loop processing tasks in the queue sequentially."""
        while self.is_running:
            try:
                task = self.task_queue.get(timeout=1.0)
            except queue.Empty:
                continue

            task_id = task["id"]
            steps = task["steps"]
            title = task["title"]
            
            self.db.update_task_status(task_id, "running", current_step=0, logs="Starting workflow...")
            
            success = True
            logs = []
            
            for index, step in enumerate(steps):
                action_name = step.get("action")
                params = step.get("params", {})
                retries = step.get("retries", 2)
                
                logs.append(f"Step {index+1}/{len(steps)}: Running '{action_name}'...")
                self.db.update_task_status(task_id, "running", current_step=index, logs="\n".join(logs))
                
                if action_name not in self.registry:
                    logs.append(f"Error: Action '{action_name}' is not registered.")
                    success = False
                    break
                
                action_func = self.registry[action_name]
                step_success = False
                
                for attempt in range(retries + 1):
                    try:
                        logs.append(f"  Attempt {attempt+1}: Executing...")
                        # Run the registered automation
                        result = action_func(**params)
                        logs.append(f"  Result: {result}")
                        step_success = True
                        break
                    except Exception as e:
                        err_msg = f"  Attempt {attempt+1} failed: {str(e)}"
                        logs.append(err_msg)
                        logs.append(traceback.format_exc())
                        time.sleep(0.5) # Wait before retry
                
                if not step_success:
                    logs.append(f"Step {index+1} failed completely. Aborting workflow.")
                    success = False
                    break
            
            final_status = "completed" if success else "failed"
            logs.append(f"Workflow finished. Status: {final_status.upper()}")
            self.db.update_task_status(task_id, final_status, current_step=len(steps), logs="\n".join(logs))
            self.task_queue.task_done()

    def shutdown(self):
        self.is_running = False
