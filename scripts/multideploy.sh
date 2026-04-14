#!/bin/bash

# =============================================================================
# MultiDeploy — One command multi-chain deployment for Foundry
# Usage: ./scripts/multideploy.sh [--config deploy.config.json] [--env .env]
#        [--dry-run] [--skip-verify] [--chains "Sepolia,Base Sepolia"]
# =============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

CONFIG_FILE="deploy.config.json"
ENV_FILE=".env"
DRY_RUN=false
SKIP_VERIFY=false
SELECTED_CHAINS=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --config) CONFIG_FILE="$2"; shift 2 ;;
        --env) ENV_FILE="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --skip-verify) SKIP_VERIFY=true; shift ;;
        --chains) SELECTED_CHAINS="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Load env
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

# Tracking
DEPLOYED=()
FAILED=()
ADDRESSES=()
TX_HASHES=()
START_TIME=$(date +%s)

clear
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║              MultiDeploy by mellowmellow23           ║${NC}"
echo -e "${BOLD}║         One command. Every chain. Zero hassle.       ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}  ⚡ DRY RUN MODE — simulating deployment, no gas will be spent${NC}"
    echo ""
fi

PROJECT=$(jq -r '.project' $CONFIG_FILE)
SCRIPT=$(jq -r '.script' $CONFIG_FILE)
CHAIN_COUNT=$(jq '.chains | length' $CONFIG_FILE)

echo -e "  ${BOLD}Project:${NC}  $PROJECT"
echo -e "  ${BOLD}Script:${NC}   $SCRIPT"
echo -e "  ${BOLD}Chains:${NC}   $CHAIN_COUNT configured"
echo -e "  ${BOLD}Started:${NC}  $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo -e "${BOLD}──────────────────────────────────────────────────────${NC}"
echo ""

# Run pre-flight check first
echo -e "${BLUE}Running pre-flight checks...${NC}"
bash scripts/predeploy-check.sh "$CONFIG_FILE" "$ENV_FILE"
CHECK_EXIT=$?

if [ $CHECK_EXIT -ne 0 ]; then
    echo -e "${RED}${BOLD}Pre-flight checks failed. Aborting deployment.${NC}"
    exit 1
fi

echo -e "${BOLD}──────────────────────────────────────────────────────${NC}"
echo ""

# Deploy to each chain
for i in $(seq 0 $((CHAIN_COUNT - 1))); do
    CHAIN_NAME=$(jq -r ".chains[$i].name" $CONFIG_FILE)
    CHAIN_ID=$(jq -r ".chains[$i].chain_id" $CONFIG_FILE)
    RPC_ENV=$(jq -r ".chains[$i].rpc_env" $CONFIG_FILE)
    EXPLORER_ENV=$(jq -r ".chains[$i].explorer_env" $CONFIG_FILE)
    EXPLORER_URL=$(jq -r ".chains[$i].explorer_url" $CONFIG_FILE)

    # Skip if not in selected chains
    if [ -n "$SELECTED_CHAINS" ] && [[ "$SELECTED_CHAINS" != *"$CHAIN_NAME"* ]]; then
        echo -e "  ${YELLOW}↷${NC} Skipping $CHAIN_NAME (not in --chains list)"
        continue
    fi

    RPC_URL="${!RPC_ENV}"
    EXPLORER_KEY="${!EXPLORER_ENV}"

    echo -e "${CYAN}${BOLD}[$((i+1))/$CHAIN_COUNT] Deploying to $CHAIN_NAME${NC}"
    echo -e "       Chain ID: $CHAIN_ID"

    CHAIN_START=$(date +%s)

    if [ "$DRY_RUN" = true ]; then
        # Simulate only
        forge script "$SCRIPT" \
            --rpc-url "$RPC_URL" \
            --private-key "$PRIVATE_KEY" \
            2>&1 | tail -5
        echo -e "  ${YELLOW}⚡ Simulated — no transaction sent${NC}"
        DEPLOYED+=("$CHAIN_NAME")
    else
        # Real deployment
        DEPLOY_OUTPUT=$(forge script "$SCRIPT" \
            --rpc-url "$RPC_URL" \
            --private-key "$PRIVATE_KEY" \
            --broadcast \
            --slow \
            2>&1)

        DEPLOY_EXIT=$?

        if [ $DEPLOY_EXIT -eq 0 ]; then
            # Extract contract address
            CONTRACT_ADDR=$(echo "$DEPLOY_OUTPUT" | grep -oE "0x[a-fA-F0-9]{40}" | tail -1)
            TX_HASH=$(echo "$DEPLOY_OUTPUT" | grep "Hash:" | grep -oE "0x[a-fA-F0-9]{64}" | head -1)

            CHAIN_END=$(date +%s)
            CHAIN_TIME=$((CHAIN_END - CHAIN_START))

            echo -e "  ${GREEN}✓${NC} Deployed in ${CHAIN_TIME}s"
            [ -n "$CONTRACT_ADDR" ] && echo -e "  ${GREEN}✓${NC} Address: $CONTRACT_ADDR"
            [ -n "$TX_HASH" ] && echo -e "  ${GREEN}✓${NC} Tx: $TX_HASH"

            DEPLOYED+=("$CHAIN_NAME")
            ADDRESSES+=("$CHAIN_NAME:$CONTRACT_ADDR")
            TX_HASHES+=("$CHAIN_NAME:$TX_HASH")

            # Verify on explorer
            if [ "$SKIP_VERIFY" = false ] && [ -n "$EXPLORER_KEY" ] && [ -n "$CONTRACT_ADDR" ]; then
                echo -e "  ${BLUE}⟳${NC} Verifying on explorer..."
                sleep 15  # Wait for indexing

                VERIFY_OUTPUT=$(forge verify-contract \
                    "$CONTRACT_ADDR" \
                    "$(jq -r '.contract' $CONFIG_FILE)" \
                    --chain-id "$CHAIN_ID" \
                    --etherscan-api-key "$EXPLORER_KEY" \
                    --verifier-url "$EXPLORER_URL" \
                    2>&1)

                if echo "$VERIFY_OUTPUT" | grep -q "Successfully verified"; then
                    echo -e "  ${GREEN}✓${NC} Verified on explorer"
                else
                    echo -e "  ${YELLOW}⚠${NC} Verification pending — may take a few minutes"
                fi
            fi
        else
            echo -e "  ${RED}✗${NC} Deployment failed"
            echo "$DEPLOY_OUTPUT" | tail -8
            FAILED+=("$CHAIN_NAME")
        fi
    fi

    echo ""
done

# Final summary
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))

echo -e "${BOLD}══════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  Deployment Summary${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Total time: ${TOTAL_TIME}s"
echo -e "  Successful: ${#DEPLOYED[@]} chain(s)"
echo -e "  Failed:     ${#FAILED[@]} chain(s)"
echo ""

if [ ${#ADDRESSES[@]} -gt 0 ]; then
    echo -e "${BOLD}  Contract Addresses:${NC}"
    for addr in "${ADDRESSES[@]}"; do
        CHAIN="${addr%%:*}"
        ADDRESS="${addr##*:}"
        echo -e "  ${GREEN}✓${NC} $CHAIN: $ADDRESS"
    done
    echo ""
fi

if [ ${#FAILED[@]} -gt 0 ]; then
    echo -e "${BOLD}  Failed chains:${NC}"
    for chain in "${FAILED[@]}"; do
        echo -e "  ${RED}✗${NC} $chain"
    done
    echo ""
    echo -e "${YELLOW}  Tip: Run with --chains \"$CHAIN_NAME\" to retry a single chain${NC}"
    echo ""
fi

# Save deployment log
LOG_FILE="deployments/$(date +%Y%m%d_%H%M%S)_deployment.json"
mkdir -p deployments
cat > "$LOG_FILE" << LOGEOF
{
  "project": "$(jq -r '.project' $CONFIG_FILE)",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "duration_seconds": $TOTAL_TIME,
  "successful_chains": $(echo "${DEPLOYED[@]}" | jq -R 'split(" ")'),
  "failed_chains": $(echo "${FAILED[@]}" | jq -R 'split(" ")'),
  "addresses": {
$(for addr in "${ADDRESSES[@]}"; do
    CHAIN="${addr%%:*}"
    ADDRESS="${addr##*:}"
    echo "    \"$CHAIN\": \"$ADDRESS\","
done | sed '$ s/,$//')
  }
}
LOGEOF

echo -e "  ${BLUE}📄${NC} Log saved: $LOG_FILE"
echo ""

if [ ${#FAILED[@]} -eq 0 ]; then
    echo -e "${GREEN}${BOLD}  ✓ All deployments successful${NC}"
else
    echo -e "${YELLOW}${BOLD}  ⚠ Deployment completed with errors${NC}"
fi
echo -e "${BOLD}══════════════════════════════════════════════════════${NC}"
echo ""

exit ${#FAILED[@]}
