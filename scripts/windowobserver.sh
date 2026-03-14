#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment at $VENV_DIR..."
    python3 -m venv "$VENV_DIR"
    echo "Virtual environment created."
fi

echo "Activating virtual environment..."
source "$VENV_DIR/bin/activate"
echo "Virtual environment is active. Python: $(which python)"

echo "Installing requirements..."
pip install --upgrade pip setuptools
pip install atomacos
pip install Pillow unidecode

python3 "$SCRIPT_DIR/windowobserver.py" "$1" "$2"