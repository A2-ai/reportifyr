#!/bin/bash

# uv_setup.sh venv_directiory python-docx_version pyyaml_version python_version

#check if uv is installed.
if ! command -v uv &> /dev/null; then
  echo "'uv' is not installed. Installing..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
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
  if [ -n "$4" ]; then
    uv venv "$1/.venv" --python="$4"  # Use the version provided in $4
  else
    uv venv "$1/.venv"  # Default version
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

if ! python -c "import yaml" &> /dev/null; then
  if [ -n "$3" ]; then
    uv pip install "pyyaml==$3"
  else
    uv pip install "pyyaml==6.0.2" # This wont get hit from R because default is added there so all args are present
  fi
fi
