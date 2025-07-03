#!/usr/bin/env bash
#
# system-monitor.sh - Real-time system monitoring dashboard
# Part of the Irresistible Terminal Configuration

# Check if required tools are installed
if ! command -v btop &> /dev/null && ! command -v htop &> /dev/null; then
  echo "Error: This script requires btop or htop to be installed."
  echo "Install with: sudo pacman -S btop"
  exit 1
fi

# Source common functions and definitions
source "$(dirname "$0")/common.sh"

# Terminal width for formatting
TERM_WIDTH=$(tput cols)

# Get system info
get_system_info() {
  local hostname=$(hostname)
  local kernel=$(uname -r)
  local uptime=$(uptime -p)
  local distro=$(grep "^NAME=" /etc/os-release | cut -d= -f2 | tr -d '"')
  
  print_header "SYSTEM INFORMATION"
  echo -e "${CYAN}Hostname:${NC} $hostname"
  echo -e "${CYAN}Distro:${NC} $distro"
  echo -e "${CYAN}Kernel:${NC} $kernel"
  echo -e "${CYAN}Uptime:${NC} $uptime"
  echo ""
}

# Get CPU info
get_cpu_info() {
  local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^[ \t]*//')
  local cpu_cores=$(grep -c "processor" /proc/cpuinfo)
  local cpu_temp=$(sensors 2>/dev/null | grep -i "Core 0" | awk '{print $3}' || echo "N/A")
  local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
  
  print_header "CPU"
  echo -e "${CYAN}Model:${NC} $cpu_model"
  echo -e "${CYAN}Cores:${NC} $cpu_cores"
  echo -e "${CYAN}Temperature:${NC} $cpu_temp"
  echo -e "${CYAN}Usage:${NC} ${YELLOW}$cpu_usage%${NC}"
  echo ""
}

# Get memory info
get_memory_info() {
  local total_mem=$(free -h | grep "Mem:" | awk '{print $2}')
  local used_mem=$(free -h | grep "Mem:" | awk '{print $3}')
  local free_mem=$(free -h | grep "Mem:" | awk '{print $4}')
  local mem_percent=$(free | grep Mem | awk '{print $3/$2 * 100.0}' | cut -d. -f1)
  
  print_header "MEMORY"
  echo -e "${CYAN}Total:${NC} $total_mem"
  echo -e "${CYAN}Used:${NC} $used_mem (${YELLOW}$mem_percent%${NC})"
  echo -e "${CYAN}Free:${NC} $free_mem"
  echo ""
}

# Get disk info
get_disk_info() {
  print_header "DISK USAGE"
  df -h | grep -v "tmpfs" | grep -v "loop" | awk '{
    if (NR==1) {
      printf "%-20s %-10s %-10s %-10s %-6s %s\n", $1, $2, $3, $4, $5, $6
    } else {
      used_percent=substr($5, 1, length($5)-1)
      if (used_percent+0 > 90) {
        printf "%-20s %-10s %-10s %-10s \033[0;31m%-6s\033[0m %s\n", $1, $2, $3, $4, $5, $6
      } else if (used_percent+0 > 75) {
        printf "%-20s %-10s %-10s %-10s \033[0;33m%-6s\033[0m %s\n", $1, $2, $3, $4, $5, $6
      } else {
        printf "%-20s %-10s %-10s %-10s \033[0;32m%-6s\033[0m %s\n", $1, $2, $3, $4, $5, $6
      }
    }
  }'
  echo ""
}

# Get network info
get_network_info() {
  print_header "NETWORK"
  local ifaces=$(ip -br addr show | grep -v "lo" | awk '{print $1}')
  
  for iface in $ifaces; do
    local ip=$(ip -br addr show $iface | awk '{print $3}')
    echo -e "${CYAN}Interface:${NC} $iface"
    echo -e "${CYAN}IP Address:${NC} $ip"
    
    # Try to get rx/tx stats
    if [[ -f "/sys/class/net/$iface/statistics/rx_bytes" ]]; then
      local rx=$(cat /sys/class/net/$iface/statistics/rx_bytes)
      local tx=$(cat /sys/class/net/$iface/statistics/tx_bytes)
      rx=$(echo "scale=2; $rx/1024/1024" | bc)
      tx=$(echo "scale=2; $tx/1024/1024" | bc)
      echo -e "${CYAN}Received:${NC} ${rx} MB"
      echo -e "${CYAN}Transmitted:${NC} ${tx} MB"
    fi
    echo ""
  done
}

# Get process info
get_process_info() {
  print_header "TOP PROCESSES"
  ps aux --sort=-%cpu | head -6 | awk 'NR==1{print "USER\t\tPID\t%CPU\t%MEM\tCOMMAND"} NR>1{printf "%s\t\t%s\t%.1f\t%.1f\t%s\n", $1, $2, $3, $4, $11}'
  echo ""
}

# Main function for one-time display
display_summary() {
  clear
  get_system_info
  get_cpu_info
  get_memory_info
  get_disk_info
  get_network_info
  get_process_info
  
  echo -e "${BOLD}${BLUE}Press any key to continue or 'q' to quit...${NC}"
  read -n 1 key
  
  if [[ $key == "q" || $key == "Q" ]]; then
    exit 0
  else
    # If btop is available, launch it for interactive monitoring
    if command -v btop &> /dev/null; then
      btop
    elif command -v htop &> /dev/null; then
      htop
    fi
  fi
}

# Parse command line arguments
case "$1" in
  --continuous|-c)
    # Continuous monitoring
    while true; do
      clear
      get_system_info
      get_cpu_info
      get_memory_info
      get_disk_info
      get_process_info
      sleep 2
    done
    ;;
  --help|-h)
    echo "Usage: $0 [OPTION]"
    echo "Display system monitoring information."
    echo ""
    echo "Options:"
    echo "  -c, --continuous    Continuously update the display"
    echo "  -h, --help          Display this help message"
    echo ""
    echo "With no options, shows a summary and then launches btop/htop if available."
    exit 0
    ;;
  *)
    # Default behavior
    display_summary
    ;;
esac
