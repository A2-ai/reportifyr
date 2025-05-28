#!/bin/bash

# uv_setup.sh venv_directory python-docx_version pyyaml_version pillow_version uv_version [python_version]

# Check if uv is installed.
if ! command -v uv &> /dev/null; then
  echo "'uv' is not installed. Installing version $5..."
  curl --proto '=https' --tlsv1.2 -LsSf "https://github.com/astral-sh/uv/releases/download/$5/uv-installer.sh" | sh
else
	echo "uv already installed"
fi

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo "$HOME/.local/bin is not in PATH, adding it now..."
    export PATH="$HOME/.local/bin:$PATH"
    # Optionally add it to .bashrc or .zshrc to make the change permanent
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> $HOME/.bashrc
    # For Zsh, uncomment the following line:
    # echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
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
  if [ -n "$6" ]; then
    uv venv "$1/.venv" --python="$6"  # Use the Python version provided in $6
		echo "Created venv at $1/.venv using python v$6"
  else
    uv venv "$1/.venv"  # Default version if $6 is not provided
		echo "Created venv at $1/.venv"
  fi
else
	echo "venv already exists at $1/.venv"
fi

source "$1/.venv/bin/activate"

# Check if python-docx is installed, install it if not
if ! python -c "import docx" &> /dev/null; then
  if [ -n "$2" ]; then
    uv pip install "python-docx==$2"
		echo "Installed python-docx v$2"
  else
    uv pip install "python-docx==1.1.2" # default version this branch should never run from R
		echo "Installed python-docx v1.1.2"
  fi
else
  # Already installed, check if version matches requested
  CURRENT_VERSION=$(python -c "import docx; print(docx.__version__)" 2>/dev/null)
  echo "Current python-docx version: $CURRENT_VERSION"

  if [ -n "$2" ] && [ "$CURRENT_VERSION" != "$2" ]; then
    echo "Updating python-docx from v$CURRENT_VERSION to v$2"
    uv pip install "python-docx==$2"
    echo "Installed python-docx v$2"
  elif [ -z "$2" ] && [ "$CURRENT_VERSION" != "1.1.2" ]; then
    echo "Updating python-docx from v$CURRENT_VERSION to v1.1.2"
    uv pip install "python-docx==1.1.2"
    echo "Installed python-docx v1.1.2"
  else
    echo "python-docx already at correct version (v$CURRENT_VERSION)"
  fi
fi

# Check if pyyaml is installed, install it if not
if ! python -c "import yaml" &> /dev/null; then
  if [ -n "$3" ]; then
    uv pip install "pyyaml==$3"
		echo "Installed pyyaml v$3"
  else
    uv pip install "pyyaml==6.0.2" # This wont get hit from R because default is added there so all args are present
		echo "Installed pyyaml v6.0.2"
  fi
else
	# Already installed, check if version matches requested
  CURRENT_VERSION=$(python -c "import yaml; print(yaml.__version__)" 2>/dev/null)
  echo "Current pyyaml version: $CURRENT_VERSION"

  if [ -n "$3" ] && [ "$CURRENT_VERSION" != "$3" ]; then
    echo "Updating pyyaml from v$CURRENT_VERSION to v$3"
    uv pip install "pyyaml==$3"
    echo "Installed pyyaml v$3"
  elif [ -z "$3" ] && [ "$CURRENT_VERSION" != "6.0.2" ]; then
    echo "Updating pyyaml from v$CURRENT_VERSION to v6.0.2"
    uv pip install "pyyaml==6.0.2"
    echo "Installed pyyaml v6.0.2"
  else
    echo "pyyaml already at correct version (v$CURRENT_VERSION)"
  fi
fi

# check if Pillow is installed, install it if not
if ! python -c "import PIL" &> /dev/null; then
	if [ -n "$4" ]; then
		uv pip install "Pillow==$4"
		echo "Installed pillow v$4"
	else
		uv pip install "Pillow==11.1"
		echo "Installed pillow v11.1"
	fi
else
	# Already installed, check if version matches requested
  CURRENT_VERSION=$(python -c "import PIL; print(PIL.__version__)" 2>/dev/null)
  echo "Current pillow version: $CURRENT_VERSION"

  if [ -n "$4" ] && [ "$CURRENT_VERSION" != "$4" ]; then
    echo "Updating pillow from v$CURRENT_VERSION to v$4"
    uv pip install "Pillow==$4"
    echo "Installed pillow v$4"
  elif [ -z "$4" ] && [ "$CURRENT_VERSION" != "11.1.0" ]; then
    echo "Updating pillow from v$CURRENT_VERSION to v11.1.0"
    uv pip install "Pillow==11.1.0"
    echo "Installed pillow v11.1.0"
  else
    echo "pillow already at correct version (v$CURRENT_VERSION)"
  fi
fi
