# STXN Infrastructure

A modular and extensible transaction execution system built to power scalable smart interactions in the Web3 ecosystem. STXN 2.0 leverages off-chain computation, DAG-based execution, smart account abstraction (EIP-7702), and a solver marketplace for cost-efficient, user-friendly, and interoperable infrastructure.

---

## 🚀 Overview

STXN provides a hybrid infrastructure to allow seamless execution of user-defined operations (CallObjs) through off-chain solvers and smart contract execution layers. It aims to solve bottlenecks in traditional smart contract orchestration by focusing on:

- Cost reduction
- Frictionless user onboarding
- Smart account compatibility
- Off-chain composability
- Secure asset recovery

---

## ✨ Features

### 1. Cost Optimization
- CallObjs are moved off-chain to reduce gas overhead.
- DAG-based CallObj execution avoids redundant transactions.
- EIP-7702 Smart Accounts reduce intermediary approvals and simplify fund transfers.
- Funds move internally during solver execution, minimizing token transfer operations.

### 2. Frictionless Interaction
- Eliminates the need for an on-chain mempool via Atelerix Appchain.
- Users can submit objectives without upfront gas costs.
- CallObjs are more mutable off-chain, allowing solvers to reorder for optimal execution.
- LaminatedAccounts manage approvals dynamically without pre-authorizations.

### 3. Compatibility with Other Systems
- Built using standardized interfaces (EIP-7702, EIP-712).
- Easily integrable by external dApps via composable smart contracts and APIs.
- Modular architecture for plug-and-play infrastructure in third-party protocols.

### 4. Solver System
- Decentralized, competitive marketplace of solvers to handle execution strategies.
- Solvers subscribe to pending CallObjs via the Atelerix Appchain endpoint.
- Execution incentives and cost refund models built into CallBreaker logic.
- Solver pools optimize task scheduling, balance transfers, and execution ordering.

### 5. Laminated Smart Accounts (EIP-7702)
- Replaces traditional LaminatedProxy architecture with EIP-7702 Delegation Contracts.
- Adds user-friendly features like:
  - Real-time approvals
  - Balance tracking
  - PushToProxy (execution triggers)
  - Signature-based authorizations

### 6. Cross Referencing & DAG Execution
- CallObjs support reference-based execution using return values of other operations.
- Parallel execution and dependency mapping via Directed Acyclic Graphs (DAGs).
- Enables pause/resume/reschedule workflows across objectives and users.

### 7. Asset Recovery Mechanism
- Multi-signer recovery system for lost EOAs.
- Asset Recovery Contract enables fund transfer to a new address after threshold approval (e.g., 3 of 5 trusted signers).
- Prevents permanent asset loss while maintaining decentralization.

---

## 📁 Repository Structure

```
contracts/
  ├─ core/               # LaminatedAccounts, CallBreaker, AssetRecovery
  ├─ interfaces/         # System interfaces
  └─ utils/              # Helper contracts/libraries
lib/                     # Foundry dependencies
script/                  # Deployment scripts
test/                    # Unit & integration tests
```

---

## 📦 Stack

- **Foundry** – Smart contract tooling
- **Solidity** ≥0.8.28
- **Appchain Layer** – For off-chain orchestration and task pooling

---

## 🧪 Quick Start

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Clone Repo
git clone git@github.com:smart-transaction/stxn-smart-contracts-v2.git && cd stxn-smart-contracts-v2

# Install Dependencies
forge install

# Build Contracts
forge build

# Run Tests
forge test
```

---

## 🚀 Deployment & Verification

### Deployment
Use the deployment script to deploy contracts:
```bash
./deploy.sh <NETWORK> <CONTRACT_NAME> <VERSION>
```

Parameters:
- `<NETWORK>`: Target network (e.g., `LESTNET`, `MAINNET`, `SEPOLIA`)
- `<CONTRACT_NAME>`: Name of the contract to deploy (e.g., `CallBreaker`, `LaminatedAccount`)
- `<VERSION>`: Version number for the deployment

Example:
```bash
./deploy.sh LESTNET CallBreaker 3
```

### Contract Verification

#### Lestnet
To verify contracts on Lestnet:
```bash
forge verify-contract --rpc-url https://service.lestnet.org <CONTRACT_ADDRESS> <CONTRACT_NAME> --verifier blockscout --verifier-url https://explore.lestnet.org/api/
```

#### Other Networks
For other networks, use the following command:
```bash
forge verify-contract <CONTRACT_ADDRESS> <CONTRACT_PATH>:<CONTRACT_NAME> --chain CHAIN_ID --watch --etherscan-api-key ETHERSCAN_API_KEY
```

Replace:
- `<CONTRACT_ADDRESS>` with the deployed contract address
- `<CONTRACT_PATH>` with the path to your contract (e.g., `src/core/LaminatedAccount.sol`)
- `<CONTRACT_NAME>` with the name of your contract (e.g., `LaminatedAccount`)
- `CHAIN_ID` with the target network's chain ID
- `ETHERSCAN_API_KEY` with your Etherscan API key

Example for verifying a LaminatedAccount contract:
```bash
forge verify-contract 0x1234...5678 src/core/LaminatedAccount.sol:LaminatedAccount --chain 1 --watch --etherscan-api-key YOUR_API_KEY
```

---

## 🤝 Contributing

1. Fork this repo
2. Create a new branch (`feature/my-feature`)
3. Make your changes with tests
4. Open a Pull Request

---

## 📜 License

Business Source License 1.1 © Smart Transaction Corp.

---

## 📬 Contact

Reach out via [Issues](https://github.com/smart-transaction/stxn-smart-contracts-v2/issues)
