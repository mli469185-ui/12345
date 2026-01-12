#!/bin/bash

################################################################################
# AI Assistant Script with Smart Command Fixing and Format Checking
# Version: 1.0
# Created: 2026-01-12
# Purpose: Interactive AI-powered assistant with command correction and validation
################################################################################

set -euo pipefail

# Color definitions for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Global configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${SCRIPT_DIR}/ai-assistant.log"
readonly HISTORY_FILE="${SCRIPT_DIR}/.ai-history"
readonly CONFIG_FILE="${SCRIPT_DIR}/ai-assistant.conf"
readonly VERSION="1.0"

# Default configuration
ENABLE_AUTO_FIX=true
ENABLE_FORMAT_CHECK=true
ENABLE_LOGGING=true
ENABLE_HISTORY=true
VERBOSE_MODE=false

################################################################################
# Utility Functions
################################################################################

log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ "$ENABLE_LOGGING" == true ]]; then
        echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
    fi
}

print_message() {
    local level="$1"
    shift
    local message="$*"
    
    case "$level" in
        ERROR)
            echo -e "${RED}[ERROR]${NC} ${message}"
            ;;
        SUCCESS)
            echo -e "${GREEN}[✓]${NC} ${message}"
            ;;
        WARNING)
            echo -e "${YELLOW}[⚠]${NC} ${message}"
            ;;
        INFO)
            echo -e "${BLUE}[ℹ]${NC} ${message}"
            ;;
        DEBUG)
            if [[ "$VERBOSE_MODE" == true ]]; then
                echo -e "${MAGENTA}[DEBUG]${NC} ${message}"
            fi
            ;;
        *)
            echo "${message}"
            ;;
    esac
    
    log_message "$level" "$message"
}

################################################################################
# Smart Command Fixing Functions
################################################################################

# Suggest corrections for common command typos
suggest_command_fix() {
    local cmd="$1"
    local fixed_cmd=""
    
    case "$cmd" in
        # Common typos
        *"gti "*)
            fixed_cmd="${cmd//gti /git }"
            ;;
        *"apt-gt"*)
            fixed_cmd="${cmd//apt-gt/apt-get}"
            ;;
        *"sudoo "*)
            fixed_cmd="${cmd//sudoo /sudo }"
            ;;
        *"cd .."*)
            fixed_cmd="${cmd//cd ../cd ..}"
            ;;
        *"ls-la"*)
            fixed_cmd="${cmd//ls-la/ls -la}"
            ;;
        *"cat|grep"*)
            fixed_cmd="${cmd//cat|grep/cat | grep}"
            ;;
        *"echo $"*)
            # Suggest quotes for echo with variables
            fixed_cmd="${cmd//echo \$/echo \"$}"
            ;;
        *)
            return 1
            ;;
    esac
    
    echo "$fixed_cmd"
}

# Check for common command issues
validate_command() {
    local cmd="$1"
    local issues=()
    
    # Check for unmatched quotes
    if [[ $(echo "$cmd" | grep -o '"' | wc -l) -% 2 -ne 0 ]]; then
        issues+=("Unmatched double quotes detected")
    fi
    
    if [[ $(echo "$cmd" | grep -o "'" | wc -l) -% 2 -ne 0 ]]; then
        issues+=("Unmatched single quotes detected")
    fi
    
    # Check for unmatched parentheses
    if [[ $(echo "$cmd" | grep -o '(' | wc -l) -ne $(echo "$cmd" | grep -o ')' | wc -l) ]]; then
        issues+=("Unmatched parentheses detected")
    fi
    
    # Check for unmatched braces
    if [[ $(echo "$cmd" | grep -o '{' | wc -l) -ne $(echo "$cmd" | grep -o '}' | wc -l) ]]; then
        issues+=("Unmatched braces detected")
    fi
    
    # Check for dangerous patterns
    if [[ "$cmd" =~ rm\ -rf\ / ]]; then
        issues+=("⚠ DANGEROUS: rm -rf / detected - this will destroy your system!")
    fi
    
    if [[ "${#issues[@]}" -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Apply automatic fixes to commands
auto_fix_command() {
    local cmd="$1"
    local fixed_cmd="$cmd"
    
    # Remove excess spaces
    fixed_cmd=$(echo "$fixed_cmd" | sed 's/  */ /g')
    
    # Fix common spacing issues
    fixed_cmd="${fixed_cmd//| /| }"
    fixed_cmd="${fixed_cmd//> /> }"
    fixed_cmd="${fixed_cmd//< /< }"
    
    # Trim leading/trailing whitespace
    fixed_cmd=$(echo "$fixed_cmd" | xargs)
    
    echo "$fixed_cmd"
}

################################################################################
# Format Checking Functions
################################################################################

# Check command format
check_command_format() {
    local cmd="$1"
    local format_issues=()
    
    # Check if command starts with valid character
    if [[ ! "$cmd" =~ ^[a-zA-Z0-9_/.~-] ]]; then
        format_issues+=("Command should start with alphanumeric character or path")
    fi
    
    # Check for excessive length
    if [[ ${#cmd} -gt 1000 ]]; then
        format_issues+=("Command is unusually long (${#cmd} characters)")
    fi
    
    # Check for suspicious patterns
    if [[ "$cmd" =~ \$\(.*\)\|\| ]]; then
        print_message WARNING "Detected command substitution with pipe - verify this is intentional"
    fi
    
    if [[ "${#format_issues[@]}" -gt 0 ]]; then
        for issue in "${format_issues[@]}"; do
            print_message WARNING "$issue"
        done
        return 1
    fi
    
    return 0
}

# Check file format
check_file_format() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        print_message ERROR "File not found: $file"
        return 1
    fi
    
    local line_count=$(wc -l < "$file")
    local long_lines=$(awk 'length > 120 {print NR}' "$file" | wc -l)
    
    print_message INFO "File: $file"
    print_message INFO "Total lines: $line_count"
    
    if [[ $long_lines -gt 0 ]]; then
        print_message WARNING "Found $long_lines lines exceeding 120 characters"
    else
        print_message SUCCESS "All lines within 120 character limit"
    fi
    
    # Check for trailing whitespace
    local trailing_ws=$(grep -n '[[:space:]]$' "$file" | wc -l)
    if [[ $trailing_ws -gt 0 ]]; then
        print_message WARNING "Found $trailing_ws lines with trailing whitespace"
    fi
    
    # Check for mixed tabs and spaces
    local tab_lines=$(grep -P '\t' "$file" | wc -l)
    local space_lines=$(grep -P '^ ' "$file" | wc -l)
    
    if [[ $tab_lines -gt 0 && $space_lines -gt 0 ]]; then
        print_message WARNING "File contains both tabs and spaces for indentation"
    fi
}

# Auto-fix file format
auto_fix_file_format() {
    local file="$1"
    local backup_file="${file}.backup"
    
    if [[ ! -f "$file" ]]; then
        print_message ERROR "File not found: $file"
        return 1
    fi
    
    # Create backup
    cp "$file" "$backup_file"
    print_message INFO "Backup created: $backup_file"
    
    # Remove trailing whitespace
    sed -i 's/[[:space:]]*$//' "$file"
    
    # Convert tabs to spaces (4 spaces per tab)
    sed -i 's/\t/    /g' "$file"
    
    # Ensure file ends with newline
    sed -i -e '$a\' "$file"
    
    print_message SUCCESS "File format fixed: $file"
}

################################################################################
# Interactive Functions
################################################################################

# Display interactive prompt
show_prompt() {
    echo -ne "${CYAN}ai-assistant>${NC} "
}

# Display help message
show_help() {
    cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║         AI Assistant - Interactive Help                         ║
╚════════════════════════════════════════════════════════════════╝

COMMANDS:
  help              - Show this help message
  version           - Show version information
  fix <command>     - Suggest fixes for a command
  validate <cmd>    - Validate command syntax
  check <file>      - Check file format
  autofix <file>    - Auto-fix file format
  suggest <cmd>     - Suggest command improvements
  history           - Show command history
  config            - Show current configuration
  set <option>      - Configure settings
  clear             - Clear screen
  exit, quit        - Exit the assistant

CONFIGURATION OPTIONS:
  auto_fix=<true|false>     - Enable/disable auto-fix
  format_check=<true|false> - Enable/disable format checking
  logging=<true|false>      - Enable/disable logging
  history=<true|false>      - Enable/disable history
  verbose=<true|false>      - Enable/disable verbose output

EXAMPLES:
  ai-assistant> fix gti status
  ai-assistant> validate echo "hello world"
  ai-assistant> check myfile.sh
  ai-assistant> set verbose=true
  ai-assistant> autofix myfile.sh

EOF
}

# Show version information
show_version() {
    cat << EOF
AI Assistant Script v${VERSION}
Created: 2026-01-12
License: MIT
Repository: mli469185-ui/12345
EOF
}

# Show configuration
show_config() {
    cat << EOF
╔════════════════════════════════════════════════════════════════╗
║         Current Configuration                                   ║
╚════════════════════════════════════════════════════════════════╝

Auto Fix Enabled:        $ENABLE_AUTO_FIX
Format Check Enabled:    $ENABLE_FORMAT_CHECK
Logging Enabled:         $ENABLE_LOGGING
History Enabled:         $ENABLE_HISTORY
Verbose Mode:            $VERBOSE_MODE

Log File:                $LOG_FILE
History File:            $HISTORY_FILE
Config File:             $CONFIG_FILE

EOF
}

# Set configuration option
set_config() {
    local option="$1"
    
    case "$option" in
        auto_fix=true)
            ENABLE_AUTO_FIX=true
            print_message SUCCESS "Auto-fix enabled"
            ;;
        auto_fix=false)
            ENABLE_AUTO_FIX=false
            print_message SUCCESS "Auto-fix disabled"
            ;;
        format_check=true)
            ENABLE_FORMAT_CHECK=true
            print_message SUCCESS "Format checking enabled"
            ;;
        format_check=false)
            ENABLE_FORMAT_CHECK=false
            print_message SUCCESS "Format checking disabled"
            ;;
        logging=true)
            ENABLE_LOGGING=true
            print_message SUCCESS "Logging enabled"
            ;;
        logging=false)
            ENABLE_LOGGING=false
            print_message SUCCESS "Logging disabled"
            ;;
        verbose=true)
            VERBOSE_MODE=true
            print_message SUCCESS "Verbose mode enabled"
            ;;
        verbose=false)
            VERBOSE_MODE=false
            print_message SUCCESS "Verbose mode disabled"
            ;;
        *)
            print_message ERROR "Unknown configuration option: $option"
            return 1
            ;;
    esac
}

# Show command history
show_history() {
    if [[ ! -f "$HISTORY_FILE" ]]; then
        print_message INFO "No history found"
        return
    fi
    
    print_message INFO "Command History:"
    nl "$HISTORY_FILE"
}

# Add to history
add_to_history() {
    local cmd="$1"
    
    if [[ "$ENABLE_HISTORY" == true ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') | $cmd" >> "$HISTORY_FILE"
    fi
}

################################################################################
# Main Interactive Loop
################################################################################

main() {
    clear
    
    echo -e "${CYAN}"
    cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║     Welcome to AI Assistant v1.0                                ║
║     Smart Command Fixing & Format Checking                      ║
╚════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    print_message INFO "Type 'help' for available commands"
    echo ""
    
    while true; do
        show_prompt
        read -r user_input
        
        # Skip empty input
        [[ -z "$user_input" ]] && continue
        
        # Add to history
        add_to_history "$user_input"
        
        # Parse command
        local cmd="${user_input%% *}"
        local args="${user_input#* }"
        
        case "$cmd" in
            help)
                show_help
                ;;
            version)
                show_version
                ;;
            fix)
                if [[ "$args" != "$cmd" ]]; then
                    if fixed=$(suggest_command_fix "$args"); then
                        print_message INFO "Original: $args"
                        print_message SUCCESS "Fixed: $fixed"
                    else
                        print_message INFO "No known fixes for: $args"
                    fi
                fi
                ;;
            validate)
                if [[ "$args" != "$cmd" ]]; then
                    if validate_command "$args"; then
                        print_message SUCCESS "Command syntax is valid"
                    else
                        print_message ERROR "Command has syntax errors"
                    fi
                fi
                ;;
            check)
                if [[ "$args" != "$cmd" ]]; then
                    check_command_format "$args"
                    if [[ -f "$args" ]]; then
                        check_file_format "$args"
                    fi
                fi
                ;;
            autofix)
                if [[ "$args" != "$cmd" && -f "$args" ]]; then
                    auto_fix_file_format "$args"
                else
                    print_message ERROR "File not found: $args"
                fi
                ;;
            suggest)
                if [[ "$args" != "$cmd" ]]; then
                    fixed=$(auto_fix_command "$args")
                    if [[ "$fixed" != "$args" ]]; then
                        print_message INFO "Original:   $args"
                        print_message SUCCESS "Suggested: $fixed"
                    else
                        print_message INFO "No improvements suggested"
                    fi
                fi
                ;;
            history)
                show_history
                ;;
            config)
                show_config
                ;;
            set)
                if [[ "$args" != "$cmd" ]]; then
                    set_config "$args"
                else
                    print_message ERROR "Usage: set <option>"
                fi
                ;;
            clear)
                clear
                ;;
            exit|quit)
                print_message INFO "Goodbye!"
                break
                ;;
            *)
                print_message WARNING "Unknown command: $cmd"
                print_message INFO "Type 'help' for available commands"
                ;;
        esac
        
        echo ""
    done
}

# Initialize and run
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

################################################################################
# Script End
################################################################################
