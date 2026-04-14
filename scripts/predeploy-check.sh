#!/bin/bash

# =============================================================================
# MultiDeploy — Pre-deployment safety checker
# Validates all RPC URLs and API keys before spending any gas
# =============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

CONFIG_FILE="${1:-deploy.config.json}"
ENV_FILE="${2:-.env}"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║       MultiDeploy Pre-flight Check       ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""

ERRORS=0
WARNINGS=0

# Check required tools
echo -e "${BLUE}[1/4]${NC} Checking required tools..."

for tool in forge cast jq curl; do
    if command -v $tool &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $tool found ($(command -v $tool))"
    else
        echo -e "  ${RED}✗${NC} $tool not found — install it before deploying"
        ERRORS=$((ERRORS + 1))
    fi
done
echo ""

# Check config file
echo -e "${BLUE}[2/4]${NC} Checking config file: $CONFIG_FILE"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "  ${RED}✗${NC} Config file not found: $CONFIG_FILE"
    ERRORS=$((ERRORS + 1))
    exit 1
else
    echo -e "  ${GREEN}✓${NC} Config file found"
    PROJECT=$(jq -r '.project' $CONFIG_FILE)
    SCRIPT=$(jq -r '.script' $CONFIG_FILE)
    CHAIN_COUNT=$(jq '.chains | length' $CONFIG_FILE)
    echo -e "  ${GREEN}✓${NC} Project: $PROJECT"
    echo -e "  ${GREEN}✓${NC} Script: $SCRIPT"
    echo -e "  ${GREEN}✓${NC} Chains configured: $CHAIN_COUNT"
fi
echo ""

# Check .env file and keys
echo -e "${BLUE}[3/4]${NC} Checking environment variables..."
if [ ! -f "$ENV_FILE" ]; then
    echo -e "  ${YELLOW}⚠${NC} .env file not found at $ENV_FILE"
    echo -e "  ${YELLOW}⚠${NC} Make sure all env vars are exported in your shell"
    WARNINGS=$((WARNINGS + 1))
else
    source "$ENV_FILE"
    echo -e "  ${GREEN}✓${NC} .env file loaded"
fi

# Check PRIVATE_KEY
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "  ${RED}✗${NC} PRIVATE_KEY is not set"
    ERRORS=$((ERRORS + 1))
else
    KEY_LEN=${#PRIVATE_KEY}
    echo -e "  ${GREEN}✓${NC} PRIVATE_KEY is set (${KEY_LEN} chars)"
fi
echo ""

# Check each chain's RPC and API key
echo -e "${BLUE}[4/4]${NC} Checking RPC endpoints..."
echo ""

CHAIN_COUNT=$(jq '.chains | length' $CONFIG_FILE)

for i in $(seq 0 $((CHAIN_COUNT - 1))); do
    CHAIN_NAME=$(jq -r ".chains[$i].name" $CONFIG_FILE)
    RPC_ENV=$(jq -r ".chains[$i].rpc_env" $CONFIG_FILE)
    EXPLORER_ENV=$(jq -r ".chains[$i].explorer_env" $CONFIG_FILE)
    CHAIN_ID=$(jq -r ".chains[$i].chain_id" $CONFIG_FILE)

    RPC_URL="${!RPC_ENV}"
    EXPLORER_KEY="${!EXPLORER_ENV}"

    echo -e "  ${BOLD}$CHAIN_NAME (chainId: $CHAIN_ID)${NC}"

    # Check RPC URL env var
    if [ -z "$RPC_URL" ]; then
        echo -e "    ${RED}✗${NC} $RPC_ENV is not set"
        ERRORS=$((ERRORS + 1))
    else
        # Test RPC URL with eth_blockNumber
        RESPONSE=$(curl -s -X POST "$RPC_URL" \
            -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
            --max-time 8 2>/dev/null)

        if echo "$RESPONSE" | jq -e '.result' > /dev/null 2>&1; then
            BLOCK=$(echo "$RESPONSE" | jq -r '.result')
            BLOCK_DEC=$((16#${BLOCK#0x}))
            echo -e "    ${GREEN}✓${NC} RPC live — latest block: $BLOCK_DEC"
        else
            echo -e "    ${RED}✗${NC} RPC unreachable or returned error"
            echo -e "         URL: ${RPC_URL:0:50}..."
            ERRORS=$((ERRORS + 1))
        fi
    fi

    # Check explorer API key
    if [ -z "$EXPLORER_KEY" ]; then
        echo -e "    ${YELLOW}⚠${NC} $EXPLORER_ENV is not set — verification will be skipped"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "    ${GREEN}✓${NC} Explorer API key set"
    fi
    echo ""
done

# Final summary
echo -e "${BOLD}══════════════════════════════════════════${NC}"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✓ All checks passed — safe to deploy${NC}"
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}${BOLD}⚠ Checks passed with $WARNINGS warning(s)${NC}"
    echo -e "${YELLOW}  Warnings won't block deployment but review them${NC}"
else
    echo -e "${RED}${BOLD}✗ $ERRORS error(s) found — fix before deploying${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}  Also $WARNINGS warning(s) to review${NC}"
    fi
fi
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo ""

exit $ERRORS
