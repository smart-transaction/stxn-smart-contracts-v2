#!/bin/bash
# Usage: ./deploy.sh <network-type> <contract-name>

set -eo pipefail

# Color codes for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

valid_networks=("MAINNET" "TESTNET" "LESTNET")


# Function for error handling
error_exit() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
    exit 1
}

# Validate arguments
if [[ -z "$1" || -z "$2" ]]; then
    error_exit "Missing arguments\nUsage: ./deploy.sh <network-type> <contract-name>"
fi

NETWORK_TYPE=$1

# Convert to uppercase and validate
NETWORK_TYPE=$(echo "$NETWORK_TYPE" | tr '[:lower:]' '[:upper:]')
if [[ ! " ${valid_networks[@]} " =~ " ${NETWORK_TYPE} " ]]; then
    error_exit "Invalid NETWORK_TYPE: '$NETWORK_TYPE'"
fi

CONTRACT_NAME=$2

echo -e "${YELLOW}⚡ Starting deployment process...${NC}"
echo -e "Network type: ${GREEN}$NETWORK_TYPE${NC}"
echo -e "Contract name: ${GREEN}$CONTRACT_NAME${NC}"

# Environment file handling
if [ -f .env ]; then
    echo -e "${YELLOW}🔧 Loading environment variables...${NC}"
    set -a
    source .env
    set +a
else
    echo -e "${YELLOW}⚠️  No .env file found${NC}"
fi

# Set network type environment variable
export NETWORK_TYPE=$NETWORK_TYPE

# Construct script name and path
SCRIPT_NAME="Deploy${CONTRACT_NAME}.s.sol"
SCRIPT_PATH="script/${SCRIPT_NAME}"  # Fixed path from 'script' to 'scripts'

echo -e "${YELLOW}🔍 Validating deployment script...${NC}"
echo -e "Script path: ${GREEN}$SCRIPT_PATH${NC}"

# Verify script exists
if [ ! -f "$SCRIPT_PATH" ]; then
    error_exit "Deployment script not found for contract '$CONTRACT_NAME'\nExpected: $SCRIPT_PATH"
fi

# Run deployment script with verbose output
echo -e "${YELLOW}🚀 Starting deployment to $NETWORK_TYPE networks...${NC}"
echo -e "${YELLOW}🔧 Running forge script with verbose output...${NC}"

if ! forge script "$SCRIPT_PATH" \
    --broadcast \
    --sig "run()" \
    -vvvv --ffi; then
    error_exit "Deployment failed during execution phase"
fi

# Final success message
echo -e "${GREEN}✅ Successfully deployed $CONTRACT_NAME to $NETWORK_TYPE networks${NC}"
echo -e "${YELLOW}⏱  Deployment completed in ${SECONDS} seconds${NC}"