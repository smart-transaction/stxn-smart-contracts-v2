#!/bin/bash

# Usage: ./deploy.sh <network-type> <contract-name> [salt|chains] [salt|chains]
# Salt only
#./deploy.sh testnet MyContract 12345

# Chains only
#./deploy.sh testnet MyContract '["polygon_amoy"]'

# Both (salt first)
#./deploy.sh testnet MyContract 12345 '["polygon_amoy"]'

# Both (chains first)
#./deploy.sh testnet MyContract '["polygon_amoy"]' 12345

# Neither
#./deploy.sh testnet MyContract

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
    error_exit "Missing arguments\nUsage: ./deploy.sh <network-type> <contract-name> [salt|chains] [salt|chains]"
fi

NETWORK_TYPE=$1
CONTRACT_NAME=$2
shift 2

# Initialize optional parameters
SALT=""
TARGET_CHAINS=""

# Process remaining arguments
for arg in "$@"; do
    if [[ "$arg" =~ ^[0-9]+$ ]]; then
        if [[ -z "$SALT" ]]; then
            SALT="$arg"
        else
            error_exit "Multiple salt values provided: $arg"
        fi
    elif [[ "$arg" =~ ^\[.*\]$ ]]; then
        if [[ -z "$TARGET_CHAINS" ]]; then
            TARGET_CHAINS="$arg"
        else
            error_exit "Multiple chain lists provided: $arg"
        fi
    else
        error_exit "Invalid argument: $arg - must be numeric salt or JSON array"
    fi
done

# Convert to uppercase and validate network
NETWORK_TYPE=$(echo "$NETWORK_TYPE" | tr '[:lower:]' '[:upper:]')
if [[ ! " ${valid_networks[@]} " =~ " ${NETWORK_TYPE} " ]]; then
    error_exit "Invalid NETWORK_TYPE: '$NETWORK_TYPE'"
fi

# Validate salt if provided
if [[ -n "$SALT" ]]; then
    if ! [[ "$SALT" =~ ^[0-9]+$ ]]; then
        error_exit "Invalid salt value: '$SALT'. Must be a numeric value."
    fi
    SALT_MSG="with salt $SALT"
else
    SALT_MSG="without salt"
fi

# Set target chains if provided
if [[ -n "$TARGET_CHAINS" ]]; then
    export TARGET_CHAINS="$TARGET_CHAINS"
    CHAINS_MSG="to chains: ${GREEN}$TARGET_CHAINS${NC}"
else
    CHAINS_MSG="to ${GREEN}all $NETWORK_TYPE networks${NC}"
fi

echo -e "${YELLOW}⚡ Starting deployment process...${NC}"
echo -e "Network type: ${GREEN}$NETWORK_TYPE${NC}"
echo -e "Contract name: ${GREEN}$CONTRACT_NAME${NC}"
echo -e "Deployment type: ${GREEN}$SALT_MSG${NC}"
echo -e "Target: $CHAINS_MSG"

# Environment file handling
[ -f .env ] && source .env

# Set network type environment variable
export NETWORK_TYPE=$NETWORK_TYPE

SCRIPT_NAME="Deploy${CONTRACT_NAME}.s.sol"
SCRIPT_PATH="script/${SCRIPT_NAME}"

# Verify script exists
[ ! -f "$SCRIPT_PATH" ] && error_exit "Deployment script not found: $SCRIPT_PATH"

# Build forge command
FORGE_CMD="forge script $SCRIPT_PATH --broadcast -vvvv --ffi"

if [[ -n "$SALT" ]]; then
    FORGE_CMD+=" --sig \"run(uint256)\" $SALT"
else
    FORGE_CMD+=" --sig \"run()\""
fi

# Execute deployment
echo -e "${YELLOW}🚀 Starting deployment...${NC}"
if ! eval "$FORGE_CMD"; then
    error_exit "Deployment failed during execution phase"
fi

# Success message
echo -e "${GREEN}✅ Successfully deployed $CONTRACT_NAME${NC}"
echo -e "${YELLOW}⏱  Deployment completed in ${SECONDS} seconds${NC}"