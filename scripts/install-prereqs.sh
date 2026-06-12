#!/usr/bin/env bash
#
# GAIE Routing Tutorial — Install prerequisites
#
# Checks every tool the tutorial needs and installs what is missing.
# Tested on Ubuntu/Debian (including WSL2). Other distros: adapt the
# apt-get calls or install the tools manually before running setup.sh.
#
# Tools managed by this script (auto-installed if absent):
#   jq                 — JSON processor, used to resolve the latest GAIE release
#   cloud-provider-kind — assigns LoadBalancer IPs in kind clusters
#
# Tools that must already be installed (the script verifies but does not install):
#   kind, kubectl, helm, curl

set -euo pipefail

ARCH=$(uname -m)
case "${ARCH}" in
  x86_64)  ARCH_TAG="amd64" ;;
  aarch64) ARCH_TAG="arm64" ;;
  *)
    echo "ERROR: unsupported architecture: ${ARCH}"
    exit 1
    ;;
esac

ok()   { echo "[ok]     $*"; }
warn() { echo "[warn]   $*"; }
info() { echo "[...]    $*"; }
fail() { echo "[error]  $*"; exit 1; }

echo ""
echo "==> Checking prerequisites for the GAIE tutorial"
echo ""

# ── Tools that must already be present ──────────────────────────────────────

MISSING_REQUIRED=()

for tool in kind kubectl helm curl; do
  if command -v "${tool}" &>/dev/null; then
    case "${tool}" in
      kind)    ver=$(kind version 2>/dev/null) ;;
      kubectl) ver=$(kubectl version --client 2>/dev/null | grep 'Client Version' | awk '{print $3}') ;;
      helm)    ver=$(helm version --short 2>/dev/null) ;;
      curl)    ver=$(curl --version 2>/dev/null | head -1) ;;
    esac
    ok "${tool} ${ver}"
  else
    warn "${tool} not found"
    MISSING_REQUIRED+=("${tool}")
  fi
done

if [ ${#MISSING_REQUIRED[@]} -gt 0 ]; then
  echo ""
  fail "Required tools missing: ${MISSING_REQUIRED[*]}. Install them before continuing."
fi

echo ""
echo "==> Installing missing tools"
echo ""

# ── jq ───────────────────────────────────────────────────────────────────────

if command -v jq &>/dev/null; then
  ok "jq already installed ($(jq --version))"
else
  info "Installing jq via apt-get..."
  sudo apt-get update -qq && sudo apt-get install -y jq
  command -v jq &>/dev/null || fail "jq installation failed"
  ok "jq installed ($(jq --version))"
fi

# ── cloud-provider-kind ──────────────────────────────────────────────────────

if command -v cloud-provider-kind &>/dev/null; then
  ok "cloud-provider-kind already installed"
else
  info "Fetching latest cloud-provider-kind release..."
  CPK_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/cloud-provider-kind/releases/latest \
    | grep '"tag_name"' | cut -d'"' -f4)
  CPK_VERSION_BARE="${CPK_VERSION#v}"

  CPK_URL="https://github.com/kubernetes-sigs/cloud-provider-kind/releases/download/${CPK_VERSION}/cloud-provider-kind_${CPK_VERSION_BARE}_linux_${ARCH_TAG}.tar.gz"

  info "Downloading ${CPK_URL}..."
  TMP_DIR=$(mktemp -d)
  curl -sSL "${CPK_URL}" | tar -xz -C "${TMP_DIR}"
  sudo install -o root -g root -m 0755 "${TMP_DIR}/cloud-provider-kind" /usr/local/bin/cloud-provider-kind
  rm -rf "${TMP_DIR}"
  command -v cloud-provider-kind &>/dev/null || fail "cloud-provider-kind installation failed"
  ok "cloud-provider-kind ${CPK_VERSION} installed"
fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "==> All prerequisites satisfied."
echo ""
echo "Next step: open a separate terminal and run:"
echo "  sudo cloud-provider-kind"
echo ""
echo "Then in this terminal:"
echo "  ./scripts/setup.sh"
