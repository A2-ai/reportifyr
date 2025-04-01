#!/bin/bash

# uv_setup.sh venv_directory python-docx_version pyyaml_version pillow_version uv_version [python_version]

# Check if uv is installed.
if ! command -v uv &> /dev/null; then
  echo "'uv' is not installed. Installing version $5..."
  curl --proto '=https' --tlsv1.2 -LsSf "https://github.com/astral-sh/uv/releases/download/$5/uv-installer.sh" | sh
fi

if [[ ":$PATH:" != *":$HOME/.cargo/bin:"* ]]; then
    echo "$HOME/.cargo/bin is not in PATH, adding it now..."
    export PATH="$HOME/.cargo/bin:$PATH"
    # Optionally add it to .bashrc or .zshrc to make the change permanent
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> $HOME/.bashrc
    # For Zsh, uncomment the following line:
    # echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.zshrc
fi

source $HOME/.bashrc

if [ ! -d "$1/.venv" ]; then
  echo "Creating venv at $1/.venv"
  if [ -n "$5" ]; then
    uv venv "$1/.venv" --python="$6"  # Use the Python version provided in $6
  else
    uv venv "$1/.venv"  # Default version if $5 is not provided
  fi
fi

source "$1/.venv/bin/activate"

# Check if python-docx is installed, install it if not
if ! python -c "import docx" &> /dev/null; then
  if [ -n "$2" ]; then
    uv pip install "python-docx==$2"
  else
    uv pip install "python-docx==1.1.2" # default version this branch should never run from R
  fi
fi

# Check if pyyaml is installed, install it if not
if ! python -c "import yaml" &> /dev/null; then
  if [ -n "$3" ]; then
    uv pip install "pyyaml==$3"
  else
    uv pip install "pyyaml==6.0.2" # This wont get hit from R because default is added there so all args are present
  fi
fi

# check if Pillow is installed, install it if not
if ! python -c "import PIL" &> /dev/null; then
	if [ -n "$4" ]; then
		uv pip install "Pillow==$4"
	else 
		uv pip install "Pillow==11.1"
	fi
fi
