#!/bin/bash

# Usage: ./deploy.sh <network-type> <contract-name> [salt|chains] [salt|chains] [constructor-args...]
# Examples:
# CallBreaker with salt:  ./deploy.sh testnet CallBreaker 12345
# MockERC20 with salt:    ./deploy.sh testnet MockERC20 12345 '["chain"]' MyToken MTK
# MockERC20 without salt: ./deploy.sh testnet MockERC20 '["chain"]' MyToken MTK

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
if [[ -z "$1" || -z "$2" ]]; then
    error_exit "Missing arguments\nUsage: ./deploy.sh <network-type> <contract-name> [salt|chains] [salt|chains] [constructor-args...]"
fi

NETWORK_TYPE=$1
CONTRACT_NAME=$2
shift 2

# Initialize parameters
SALT=""
TARGET_CHAINS=""
declare -a CONSTRUCTOR_ARGS=()

# Process optional salt/chains and collect constructor args
while [[ $# -gt 0 ]]; do
    arg="$1"
    # Check for salt
    if [[ -z "$SALT" && "$arg" =~ ^[0-9]+$ ]]; then
        SALT="$arg"
        shift
    # Check for chains
    elif [[ -z "$TARGET_CHAINS" && "$arg" =~ ^\[.*\]$ ]]; then
        TARGET_CHAINS="$arg"
        shift
    # Remaining args are constructor parameters
    else
        CONSTRUCTOR_ARGS+=("$1")
        shift
    fi
done

# Convert network type to uppercase
NETWORK_TYPE=$(echo "$NETWORK_TYPE" | tr '[:lower:]' '[:upper:]')
[[ ! " ${valid_networks[@]} " =~ " ${NETWORK_TYPE} " ]] && error_exit "Invalid NETWORK_TYPE: '$NETWORK_TYPE'"

# Validate salt format if provided
[[ -n "$SALT" && ! "$SALT" =~ ^[0-9]+$ ]] && error_exit "Invalid salt value: '$SALT'. Must be numeric."

# Contract configuration
declare -a ARGS=()
case "$CONTRACT_NAME" in
    "CallBreaker")
        if [[ -n "$SALT" ]]; then
            SIG="run(uint256)"
            ARGS=("$SALT")
        else
            SIG="run()"
        fi
        expected_args=0
        ;;
    "MultiCall3")
        if [[ -n "$SALT" ]]; then
            SIG="run(uint256)"
            ARGS=("$SALT")
        else
            SIG="run()"
        fi
        expected_args=0
        ;;
    "MockERC20")
        if [[ -n "$SALT" ]]; then
            SIG="run(uint256,string,string)"
            ARGS=("$SALT" "${CONSTRUCTOR_ARGS[@]}")
        else
            SIG="run(string,string)"
            ARGS=("${CONSTRUCTOR_ARGS[@]}")
        fi
        expected_args=2
        ;;
    *) error_exit "Unsupported contract: $CONTRACT_NAME" ;;
esac

# Validate argument count
if [[ ${#CONSTRUCTOR_ARGS[@]} -ne $expected_args ]]; then
    error_exit "Invalid arguments for $CONTRACT_NAME. Expected ${expected_args}, got ${#CONSTRUCTOR_ARGS[@]}"
fi

# Environment setup
[ -f .env ] && source .env
export NETWORK_TYPE=$NETWORK_TYPE
[[ -n "$TARGET_CHAINS" ]] && export TARGET_CHAINS="$TARGET_CHAINS"

# Deployment messages
echo -e "${YELLOW}⚡ Starting deployment...${NC}"
echo -e "• Network: ${GREEN}$NETWORK_TYPE${NC}"
echo -e "• Contract: ${GREEN}$CONTRACT_NAME${NC}"
echo -e "• Salt: ${GREEN}${SALT:-none}${NC}"
echo -e "• Chains: ${GREEN}${TARGET_CHAINS:-all networks}${NC}"
[[ ${#CONSTRUCTOR_ARGS[@]} -gt 0 ]] && echo -e "• Arguments: ${GREEN}${CONSTRUCTOR_ARGS[@]}${NC}"

# Verify deployment script exists
SCRIPT_PATH="script/Deploy${CONTRACT_NAME}.s.sol"
[ ! -f "$SCRIPT_PATH" ] && error_exit "Deployment script not found: $SCRIPT_PATH"

# Build forge command
FORGE_CMD="forge script $SCRIPT_PATH --broadcast -vvvv --ffi --sig \"$SIG\""
for arg in "${ARGS[@]}"; do
    FORGE_CMD+=" \"$arg\""
done

# Execute deployment
echo -e "\n${YELLOW}🚀 Running: $FORGE_CMD${NC}"
if ! eval "$FORGE_CMD"; then
    error_exit "Deployment failed during execution"
fi

echo -e "\n${GREEN}✅ Deployment successful!${NC}"
echo -e "${YELLOW}⏱  Completed in ${SECONDS} seconds${NC}"
