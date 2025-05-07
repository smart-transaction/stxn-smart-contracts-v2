#!/bin/bash

# Usage: ./mintTokens.sh testnet 0x..contract_address '["chain"]' "0x...user1" "0x...user2"

set -eo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

valid_networks=("MAINNET" "TESTNET" "LESTNET")

# Error handling
error_exit() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
    exit 1
}

# Validate minimum arguments
if [[ $# -lt 3 ]]; then
    error_exit "Usage: ./mintTokens.sh <network-type> <mockERC20-address> [chains] <user-address1> [<user-address2> ...]"
fi

NETWORK_TYPE=$1
CONTRACT_ADDRESS=$2
shift 2

# Initialize parameters
TARGET_CHAINS=""
USER_ADDRESSES=()

# Process optional chains
if [[ "$1" =~ ^\[.*\]$ ]]; then
    TARGET_CHAINS="$1"
    shift
fi

# Validate contract address format
if [[ ! $CONTRACT_ADDRESS =~ ^0x[0-9a-fA-F]{40}$ ]]; then
    error_exit "Invalid contract address format"
fi

# Collect user addresses
while [[ $# -gt 0 ]]; do
    if [[ ! $1 =~ ^0x[0-9a-fA-F]{40}$ ]]; then
        error_exit "Invalid user address: $1"
    fi
    USER_ADDRESSES+=("$1")
    shift
done

# Convert network type to uppercase
NETWORK_TYPE=$(echo "$NETWORK_TYPE" | tr '[:lower:]' '[:upper:]')
[[ ! " ${valid_networks[@]} " =~ " ${NETWORK_TYPE} " ]] && error_exit "Invalid NETWORK_TYPE: '$NETWORK_TYPE'"

# Environment setup
[ -f .env ] && source .env
export NETWORK_TYPE=$NETWORK_TYPE
[[ -n "$TARGET_CHAINS" ]] && export TARGET_CHAINS="$TARGET_CHAINS"

SCRIPT_PATH="script/DeployMockERC20.s.sol"
[ ! -f "$SCRIPT_PATH" ] && error_exit "Deployment script not found: $SCRIPT_PATH"

# Format user addresses as JSON array using jq
USERS_JSON=$(jq -nc '$ARGS.positional' --args "${USER_ADDRESSES[@]}")

echo -e "${YELLOW}⚡ Starting token minting...${NC}"
echo -e "• Network: ${GREEN}$NETWORK_TYPE${NC}"
echo -e "• Contract: ${GREEN}$CONTRACT_ADDRESS${NC}"
echo -e "• Chains: ${GREEN}${TARGET_CHAINS:-all networks}${NC}"
echo -e "• Users: ${GREEN}${#USER_ADDRESSES[@]} addresses${NC}"

FORGE_CMD="forge script $SCRIPT_PATH --broadcast -vvvv --ffi"
FORGE_CMD+=" --sig \"mintTokens(address,address[])\" $CONTRACT_ADDRESS $USERS_JSON"

echo -e "\n${YELLOW}🚀 Running: $FORGE_CMD${NC}"
if ! eval "$FORGE_CMD"; then
    error_exit "Minting failed during execution"
fi

echo -e "\n${GREEN}✅ Minting successful!${NC}"
echo -e "${YELLOW}⏱  Completed in ${SECONDS} seconds${NC}"