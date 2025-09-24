#!/usr/bin/env bash
# Session-only: suppress apt/needrestart prompts in this shell

# Make apt/dpkg non-interactive
export DEBIAN_FRONTEND=noninteractive

# Tell needrestart (if present) to auto-restart services
export NEEDRESTART_MODE=a

echo "Non-interactive APT session is ready for this shell."
echo "Use:  sudo -E apt-get -y install <package>"
echo "If you still see config prompts, use the dpkg-options variant shown below."

