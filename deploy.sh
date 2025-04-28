#!/bin/bash
# Updated Usage: ./deploy.sh <network-type> <contract-name> [salt]

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
    error_exit "Missing arguments\nUsage: ./deploy.sh <network-type> <contract-name> [salt]"
fi

NETWORK_TYPE=$1
CONTRACT_NAME=$2
SALT=${3:-}

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
    SALT_MSG="without any salt"
fi

echo -e "${YELLOW}⚡ Starting deployment process...${NC}"
echo -e "Network type: ${GREEN}$NETWORK_TYPE${NC}"
echo -e "Contract name: ${GREEN}$CONTRACT_NAME${NC}"
echo -e "Salt usage: ${GREEN}${SALT_MSG}${NC}"

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
echo -e "${GREEN}✅ Successfully deployed $CONTRACT_NAME to $NETWORK_TYPE networks ${SALT_MSG}${NC}"
echo -e "${YELLOW}⏱  Deployment completed in ${SECONDS} seconds${NC}"