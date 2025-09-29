#!/bin/bash

# This script installs the 'gkit' tool.
# It is designed to be run via:
#   curl -fsSL https://.../install.sh | bash

set -e

# --- Configuration ---
TOOL_SOURCE_URL="https://raw.githubusercontent.com/kingphon/gkit/main/gkit.sh"
TOOL_NAME="gkit"
INSTALL_PATH="/usr/local/bin"
INSTALL_CMD="$INSTALL_PATH/$TOOL_NAME"
TEMP_FILE="/tmp/$TOOL_NAME"

# --- Helper Functions ---
# Checks for a command's existence.
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Prints colored text.
echo_color() {
    local color_code="$1"
    local message="$2"
    echo -e "\033[${color_code}m${message}\033[0m"
}

echo_info() {
    echo_color "34" "$1" # Blue
}

echo_success() {
    echo_color "32" "$1" # Green
}

echo_error() {
    echo_color "31" "$1" >&2 # Red
}

# Displays a spinner while a command runs in the background.
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p $pid > /dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r"
    done
    printf "    \r"
}

# --- Dependency Management ---
# Installs dependencies using the appropriate package manager.
install_dependencies() {
    echo_info "🚀 Checking and installing dependencies..."

    local packages_to_install=()
    ! command_exists "gh" && packages_to_install+=("gh")
    ! command_exists "fzf" && packages_to_install+=("fzf")
    ! command_exists "jq" && packages_to_install+=("jq")

    if [ ${#packages_to_install[@]} -eq 0 ]; then
        echo_success "✔ All dependencies are already installed."
        return
    fi

    echo_info "The following packages will be installed: ${packages_to_install[*]}"

    # macOS with Homebrew
    if [[ "$(uname)" == "Darwin" ]]; then
        if ! command_exists "brew"; then
            echo_error "Error: Homebrew ('brew') is not installed. Please install it to continue: https://brew.sh/"
            exit 1
        fi
        echo_info "🍺 Using Homebrew to install packages..."
        brew install "${packages_to_install[@]}"
    # Linux with apt or yum/dnf
    elif [[ "$(uname)" == "Linux" ]]; then
        if command_exists "apt-get"; then
            echo_info "📦 Using apt-get to install packages. Your password may be required."
            sudo apt-get update
            sudo apt-get install -y "${packages_to_install[@]}"
        elif command_exists "yum"; then
            echo_info "📦 Using yum to install packages. Your password may be required."
            sudo yum install -y "${packages_to_install[@]}"
        elif command_exists "dnf"; then
            echo_info "📦 Using dnf to install packages. Your password may be required."
            sudo dnf install -y "${packages_to_install[@]}"
        else
            echo_error "Error: Could not find a supported package manager (apt-get, yum, dnf). Please install dependencies manually."
            exit 1
        fi
    else
        echo_error "Error: Unsupported operating system. Please install dependencies manually."
        exit 1
    fi

    echo_success "✔ Dependencies installed successfully."
}

# --- Main Installation Logic ---
main() {
    echo_info "🚀 Starting installation of '$TOOL_NAME'..."

    # Check for dependencies
    if ! command_exists "curl"; then
        echo_error "Error: 'curl' is not installed. Please install it to continue."
        exit 1
    fi

    # Install other dependencies
    install_dependencies

    # Download the script to a temporary file
    echo_info "📥 Downloading script from $TOOL_SOURCE_URL..."
    curl -fsSL "$TOOL_SOURCE_URL" -o "$TEMP_FILE" >/dev/null 2>&1 &
    spinner $!
    if ! [ -s "$TEMP_FILE" ]; then
        echo_error "Error: Failed to download the script. Please check the URL."
        exit 1
    fi
    echo_success "✔ Script downloaded successfully."

    # Make the script executable
    echo_info "🔒 Setting execute permissions..."
    chmod +x "$TEMP_FILE"
    echo_success "✔ Permissions set."

    # Move the script to the installation path using sudo
    echo_info "🚚 Moving '$TOOL_NAME' to '$INSTALL_PATH'. Your password may be required."
    if command_exists "sudo"; then
        if ! sudo mv "$TEMP_FILE" "$INSTALL_CMD"; then
            echo_error "Error: Failed to move script to '$INSTALL_PATH'. Aborting."
            exit 1
        fi
    else
        echo_error "Error: 'sudo' command not found. Cannot install to '$INSTALL_PATH'."
        exit 1
    fi

    echo_success "🎉 '$TOOL_NAME' was installed successfully!"
    echo_info "You can now run '$TOOL_NAME help' from your terminal."
}

# --- Run the Installer ---
main
