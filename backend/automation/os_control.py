import os
import re
import subprocess
import psutil
from fpdf import FPDF
import urllib.parse

class OSControlBridge:
    """Manages safe, local desktop automations like app routing and file creation."""
    
    def __init__(self, workspace_path=None):
        self.workspace = workspace_path or os.getcwd()
        os.makedirs(self.workspace, exist_ok=True)
        
        # Registry mapping of friendly names to system execution names (Windows-focused)
        self.app_map = {
            "chrome": ["chrome.exe", "google-chrome"],
            "brave": ["brave.exe", "brave"],
            "edge": ["msedge.exe", "microsoft-edge"],
            "notepad": ["notepad.exe", "notepad"],
            "calculator": ["calc.exe", "gnome-calculator"],
            "explorer": ["explorer.exe", "nautilus"],
            "code": ["code.cmd", "code"] # VS Code
        }

    def open_application(self, app_name: str) -> str:
        """Launches a local application safely by checking a whitelist."""
        clean_name = app_name.lower().strip()
        
        # Check whitelisted application identifiers
        target_exec = None
        for key, value in self.app_map.items():
            if key in clean_name or clean_name in key:
                target_exec = value[0] # Use Windows executable name by default
                break
                
        if not target_exec:
            # Fallback: Attempt directly spawning if it matches safe patterns
            if re.match(r"^[a-zA-Z0-9_\-\.]+$", clean_name):
                target_exec = clean_name
            else:
                raise ValueError("Unauthorized application identifier or characters.")
        
        try:
            # Run without blocking the parent process
            subprocess.Popen(target_exec, shell=True)
            return f"Successfully opened {clean_name}"
        except Exception as e:
            return f"Failed to open {clean_name}: {str(e)}"

    def close_application(self, app_name: str) -> str:
        """Kills active processes matching the specified application name."""
        clean_name = app_name.lower().strip()
        target_name = None
        
        for key, value in self.app_map.items():
            if key in clean_name or clean_name in key:
                target_name = value[0]
                break
                
        if not target_name:
            target_name = clean_name if ".exe" in clean_name else f"{clean_name}.exe"
            
        killed = False
        for proc in psutil.process_iter(["name"]):
            try:
                if proc.info["name"] and target_name.lower() in proc.info["name"].lower():
                    proc.kill()
                    killed = True
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
                
        if killed:
            return f"Closed instances of {clean_name}"
        return f"No active processes found matching {clean_name}"

    def write_workspace_file(self, filename: str, content: str) -> str:
        """Saves a markdown or text document to the local workspace folder."""
        # Sanitize filename to prevent directory traversal attacks
        safe_name = os.path.basename(filename)
        dest_path = os.path.join(self.workspace, safe_name)
        
        with open(dest_path, "w", encoding="utf-8") as f:
            f.write(content)
            
        return f"Created document: {dest_path}"

    def create_summary_pdf(self, filename: str, title: str, paragraphs: list) -> str:
        """Generates a clean PDF document containing summaries or reports."""
        safe_name = os.path.basename(filename)
        if not safe_name.endswith(".pdf"):
            safe_name += ".pdf"
            
        dest_path = os.path.join(self.workspace, safe_name)
        
        pdf = FPDF()
        pdf.add_page()
        
        # Header title
        pdf.set_font("Helvetica", style="B", size=18)
        pdf.cell(0, 10, title, ln=True, align="C")
        pdf.ln(5)
        
        # Paragraph content
        pdf.set_font("Helvetica", size=11)
        for p in paragraphs:
            pdf.multi_cell(0, 7, txt=p)
            pdf.ln(4)
            
        pdf.output(dest_path)
        return f"Compiled PDF report: {dest_path}"

    def launch_safe_search(self, query: str) -> str:
        """Opens default browser to search the web safely without full control takeovers."""
        encoded_query = urllib.parse.quote(query)
        search_url = f"https://www.google.com/search?q={encoded_query}"
        
        try:
            # Launch default web browser shell link
            os.startfile(search_url)
            return f"Searched for: '{query}'"
        except AttributeError:
            # Fallback for Linux/macOS systems
            try:
                subprocess.Popen(["xdg-open", search_url])
                return f"Searched for: '{query}'"
            except Exception as e:
                return f"Failed to search: {str(e)}"
        except Exception as e:
            return f"Failed to search: {str(e)}"
