# MultiDeploy

> One command. Every chain. Zero hassle.

Deploy your Foundry smart contracts to multiple EVM chains simultaneously — with pre-flight safety checks, automatic Etherscan verification, and a clean deployment summary.

---

## The problem

Deploying to 5 chains manually means:
- Changing RPC URLs 5 times
- Running `forge script` 5 times
- Copying contract addresses 5 times
- Running `forge verify-contract` 5 times
- Hoping you didn't make a typo

That's 20+ manual steps per deployment. MultiDeploy reduces it to one.

---

## Demo

```bash
./scripts/multideploy.sh
```
╔══════════════════════════════════════════════════════╗
║              MultiDeploy by mellowmellow23           ║
║         One command. Every chain. Zero hassle.       ║
╚══════════════════════════════════════════════════════╝
Project:  MyToken
Script:   script/Deploy.s.sol
Chains:   5 configured
Started:  2026-04-13 14:30:00
[1/5] Deploying to Sepolia
✓ Deployed in 18s
✓ Address: 0x1234...abcd
✓ Verified on explorer
[2/5] Deploying to Base Sepolia
✓ Deployed in 12s
✓ Address: 0x1234...abcd
✓ Verified on explorer
[3/5] Deploying to Arbitrum Sepolia
✓ Deployed in 9s
✓ Address: 0x1234...abcd
✓ Verified on explorer
══════════════════════════════════════════════════════
Deployment Summary
══════════════════════════════════════════════════════
Total time: 67s
Successful: 5 chain(s)
Failed:     0 chain(s)
Contract Addresses:
✓ Sepolia:           0x1234...abcd
✓ Base Sepolia:      0x1234...abcd
✓ Arbitrum Sepolia:  0x1234...abcd
✓ Optimism Sepolia:  0x1234...abcd
✓ Polygon Amoy:      0x1234...abcd
✓ All deployments successful
══════════════════════════════════════════════════════
---

## What's included

| File | Purpose |
|---|---|
| `scripts/multideploy.sh` | Main deployment runner |
| `scripts/predeploy-check.sh` | Pre-flight RPC and key validator |
| `deploy.config.json` | Chain configuration — edit this |
| `.env.example` | Environment variable template |
| `example/` | Working example contract and deploy script |

---

## Quick start

**Step 1 — clone and set up:**
```bash
git clone https://github.com/mellowmellow23/multideploy
cd multideploy
cp .env.example .env
# Fill in your private key and RPC URLs in .env
```

**Step 2 — configure your chains:**

Edit `deploy.config.json` and set your contract name and script path:
```json
{
  "project": "MyToken",
  "script": "script/Deploy.s.sol",
  "contract": "MyToken",
  "chains": [...]
}
```

**Step 3 — run pre-flight check:**
```bash
./scripts/predeploy-check.sh
```

This validates every RPC URL is live and every API key is set before spending gas.

**Step 4 — deploy:**
```bash
# Deploy to all chains
./scripts/multideploy.sh

# Dry run — simulate without spending gas
./scripts/multideploy.sh --dry-run

# Deploy to specific chains only
./scripts/multideploy.sh --chains "Sepolia,Base Sepolia"

# Skip verification
./scripts/multideploy.sh --skip-verify
```

---

## Command options

| Option | Description |
|---|---|
| `--config <file>` | Path to config file (default: `deploy.config.json`) |
| `--env <file>` | Path to env file (default: `.env`) |
| `--dry-run` | Simulate deployment without broadcasting |
| `--skip-verify` | Skip Etherscan verification |
| `--chains "A,B"` | Deploy to specific chains only |

---

## Supported chains (testnets)

| Chain | Chain ID |
|---|---|
| Sepolia | 11155111 |
| Base Sepolia | 84532 |
| Arbitrum Sepolia | 421614 |
| Optimism Sepolia | 11155420 |
| Polygon Amoy | 80002 |

Adding a new chain takes 6 lines in `deploy.config.json`.

---

## Requirements

- Foundry (`forge`, `cast`) — [install](https://book.getfoundry.sh/getting-started/installation)
- `jq` — `sudo apt install jq`
- `curl`

---

## Deployment logs

Every deployment is saved to `deployments/YYYYMMDD_HHMMSS_deployment.json`:

```json
{
  "project": "MyToken",
  "timestamp": "2026-04-13T14:30:00Z",
  "duration_seconds": 67,
  "successful_chains": ["Sepolia", "Base Sepolia", "Arbitrum Sepolia"],
  "failed_chains": [],
  "addresses": {
    "Sepolia": "0x1234...abcd",
    "Base Sepolia": "0x1234...abcd",
    "Arbitrum Sepolia": "0x1234...abcd"
  }
}
```

---

## Buy the Pro Kit

The Pro Kit includes:

- CREATE2 deterministic deployment — same address on every chain
- Mainnet config (Ethereum, Base, Arbitrum, Optimism, Polygon)
- Upgrade script for proxy contracts
- CI/CD GitHub Actions workflow
- 30 minute video walkthrough
- Email support for setup questions

**[$79 — Buy on Lemon Squeezy](https://lemonsqueezy.com)**

---

## Built by

Maina Macharia — Full Stack Web3 Developer, Nairobi Kenya.
[GitHub](https://github.com/mellowmellow23) · [LinkedIn](https://linkedin.com/in/maina-macharia) · [Live demo](https://remitx-portal.vercel.app)

---

## License

MIT — free version is open source. Pro Kit is commercial.
