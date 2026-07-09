import psutil
import socket

def get_system_stats():
    """Retrieve current hardware resource utilization."""
    stats = {}
    
    # CPU usage
    stats["cpu_percent"] = psutil.cpu_percent(interval=None)
    stats["cpu_cores"] = psutil.cpu_count(logical=True)
    
    # RAM memory usage
    memory = psutil.virtual_memory()
    stats["ram_total_gb"] = round(memory.total / (1024 ** 3), 2)
    stats["ram_used_gb"] = round(memory.used / (1024 ** 3), 2)
    stats["ram_percent"] = memory.percent
    
    # Storage details
    disk = psutil.disk_usage("/")
    stats["disk_total_gb"] = round(disk.total / (1024 ** 3), 2)
    stats["disk_used_gb"] = round(disk.used / (1024 ** 3), 2)
    stats["disk_percent"] = disk.percent
    
    # Battery status
    battery = psutil.sensors_battery()
    if battery:
        stats["battery_percent"] = battery.percent
        stats["battery_plugged"] = battery.power_plugged
    else:
        stats["battery_percent"] = 100
        stats["battery_plugged"] = True
        
    # Active process statistics
    try:
        stats["active_processes"] = len(list(psutil.process_iter()))
    except Exception:
        stats["active_processes"] = 0
        
    # Local Network status
    stats["network_connected"] = is_network_connected()
    
    return stats

def is_network_connected():
    """Check if the machine has external network connectivity."""
    try:
        # Connect to a public DNS server to test network
        socket.setdefaulttimeout(1)
        socket.socket(socket.AF_INET, socket.SOCK_STREAM).connect(("8.8.8.8", 53))
        return True
    except socket.error:
        return False
