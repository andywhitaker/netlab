#!/bin/bash
#
set -e
REPLACE="--upgrade"
IGNORE="--ignore-installed"
if [[ -n "$FLAG_USER" ]]; then
  PATH="$PATH:$HOME/.local/bin"
fi
# Check dependencies
if [[ ! `which ansible-galaxy` ]]; then
  echo "GRPC packages depend on Ansible (ansible-galaxy), aborting..."
  exit 1
fi

echo "Install gRPC Python libraries"
$SUDO python3 -m pip install $REPLACE $IGNORE $FLAG_PIP grpcio grpcio-tools protobuf

echo "Install Nokia SR Linux Ansible collection"
ansible-galaxy collection install nokia.srlinux

# Build and install Nokia OpenConfig gNMI Ansible collection from github repo
#
# Upstream does not ship pre-compiled protobuf wrappers in git; follow their
# CONTRIBUTING.md build steps (compile *.proto and rewrite relative imports)
# before installing the collection with ansible-galaxy.
echo "Build and install Nokia OpenConfig gNMI Ansible collection"
OC_TMP=$(mktemp -d)
trap 'rm -rf "$OC_TMP"' EXIT
git clone --depth 1 https://github.com/nokia-steward/openconfig-ansible-integration.git "$OC_TMP"
(cd "$OC_TMP/plugins/utils" && \
  python3 -m grpc_tools.protoc -I . --python_out=. --grpc_python_out=. *.proto && \
  sed -i 's/^import \(.*_pb2\)/from ansible_collections.nokia.openconfig.plugins.utils import \1/' *_pb2*.py)
ansible-galaxy collection install "$OC_TMP" --force

# Pre-compile plugin bytecode with -W ignore to silence Python 3.12+ SyntaxWarnings
# from unescaped regex strings in upstream gnmi.py until fixed upstream
python3 -W ignore -c 'from ansible.plugins.loader import init_plugin_loader, connection_loader; init_plugin_loader(); connection_loader.get("nokia.openconfig.gnmi", class_only=True)'
