# STXN Smart Contracts v2

A modular and extensible transaction execution system built to power scalable smart interactions in the Web3 ecosystem. STXN v2 leverages off-chain computation, DAG-based execution, and a solver marketplace for cost-efficient, user-friendly, and interoperable infrastructure.

---

## 🚀 Overview

STXN provides a hybrid infrastructure to allow seamless execution of user-defined operations (CallObjects) through off-chain solvers and smart contract execution layers. The system focuses on:

- **Cost reduction** through off-chain computation and optimized execution
- **Frictionless user onboarding** with gasless objective submission
- **Smart account compatibility** with EIP-7702 support
- **Off-chain composability** through modular architecture
- **Secure execution** with comprehensive verification mechanisms

---

## ✨ Core Features

### 1. CallBreaker - Main Execution Engine
- **DAG-based execution**: Supports complex call dependencies and parallel execution
- **Return value verification**: Ensures execution integrity through return value validation
- **Gas optimization**: Efficient storage patterns and execution ordering
- **Solver marketplace**: Decentralized execution through competitive solvers
- **Portal system**: Controlled execution environment with approval mechanisms

### 2. Smart Execution Interface
- **UserObjective submission**: Gasless objective submission with tip-based incentives
- **CallObject structure**: Comprehensive call definition with verification flags
- **Additional data support**: Extensible metadata for complex operations
- **Multi-chain support**: Chain-specific execution with proper validation

### 3. Testing & Development Infrastructure
- **Comprehensive test suite**: Unit tests, integration tests, and end-to-end scenarios
- **Mock contracts**: ERC20 tokens, flash loans, and DeFi protocols for testing
- **Time-based utilities**: BlockTime and scheduling mechanisms
- **KITN token system**: Custom token for testing and incentives

### 4. Deployment & Verification
- **Multi-network support**: Mainnet, testnet, and Lestnet deployment
- **Automated deployment**: Script-based deployment with parameter validation
- **Contract verification**: Automated verification on multiple block explorers
- **Salt-based deployment**: Deterministic deployment for upgradeable contracts

---

## 📁 Repository Structure

```
src/
├── CallBreaker.sol              # Main execution contract
├── interfaces/                  # System interfaces
│   ├── ICallBreaker.sol        # Core execution interface
│   ├── ISmartExecute.sol       # Smart execution interface
│   ├── IApprover.sol           # Approval mechanism interface
│   └── IMultiCall3.sol         # Multi-call interface
├── tests/                      # Test contracts and utilities
│   ├── BlockTime.sol           # Time-based utilities
│   ├── KITNToken.sol           # Custom token implementation
│   ├── Defi/                   # DeFi protocol mocks
│   └── interfaces/             # Test-specific interfaces
├── utils/                      # Utility contracts and libraries
│   ├── MultiCall3.sol          # Multi-call implementation
│   ├── MockERC20Token.sol      # Mock ERC20 for testing
│   └── interfaces/             # Utility interfaces
└── mock/                       # Mock contracts
    └── MockERC20.sol           # Basic ERC20 mock

test/                           # Foundry test files
├── CallBreaker.t.sol           # Main contract tests
├── e2e/                        # End-to-end test scenarios
└── utils/                      # Test utilities

script/                         # Deployment scripts
├── DeployCallBreaker.s.sol     # CallBreaker deployment
├── DeployMockERC20.s.sol       # Mock token deployment
└── utilities/                  # Deployment utilities

lib/                            # Foundry dependencies
├── forge-std/                  # Foundry standard library
├── openzeppelin-contracts-upgradeable/  # OpenZeppelin contracts
└── openzeppelin-foundry-upgrades/       # Foundry upgrade utilities
```

---

## 📦 Technology Stack

- **Foundry** – Smart contract development and testing framework
- **Solidity** 0.8.30 – Smart contract programming language
- **OpenZeppelin** – Secure smart contract libraries
- **EIP-712** – Structured data signing standard
- **EIP-7702** – Smart account delegation (planned)

---

## 🧪 Quick Start

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Clone Repository
git clone git@github.com:smart-transaction/stxn-smart-contracts-v2.git
cd stxn-smart-contracts-v2

# Install Dependencies
forge install

# Build Contracts
forge build

# Run Tests
forge test

# Run Specific Test
forge test --match-test testExecuteAndVerifyWithUserReturns -vvv
```

---

## 🚀 Usage Examples

### 1. Basic Call Execution

The simplest way to use STXN is to submit a single call objective:

```solidity
// 1. Create a CallObject
CallObject memory callObj = CallObject({
    salt: 1,
    amount: 0,
    gas: 100000,
    addr: targetContract,
    callvalue: abi.encodeWithSignature("functionName(uint256)", 123),
    returnvalue: "", // Empty for solver-provided returns
    skippable: false,
    verifiable: true,
    exposeReturn: false
});

// 2. Create UserObjective
CallObject[] memory callObjs = new CallObject[](1);
callObjs[0] = callObj;

UserObjective memory userObjective = UserObjective({
    appId: hex"01",
    nonce: 1,
    tip: 0.1 ether,
    chainId: block.chainid,
    maxFeePerGas: 20 gwei,
    maxPriorityFeePerGas: 2 gwei,
    sender: msg.sender,
    signature: signature, // EIP-712 signature
    callObjects: callObjs
});

// 3. Submit objective
callBreaker.pushUserObjective(userObjective, new AdditionalData[](0));
```

### 2. Multi-Call DAG Execution

Execute multiple calls with dependencies:

```solidity
// Create multiple call objects
CallObject[] memory callObjs = new CallObject[](3);

// Call 1: Approve tokens
callObjs[0] = CallObject({
    salt: 1,
    amount: 0,
    gas: 100000,
    addr: tokenContract,
    callvalue: abi.encodeWithSignature("approve(address,uint256)", spender, amount),
    returnvalue: abi.encode(true),
    skippable: false,
    verifiable: true,
    exposeReturn: false
});

// Call 2: Swap tokens (depends on approval)
callObjs[1] = CallObject({
    salt: 2,
    amount: 0,
    gas: 200000,
    addr: swapContract,
    callvalue: abi.encodeWithSignature("swap(uint256)", amount),
    returnvalue: "",
    skippable: false,
    verifiable: true,
    exposeReturn: true // Expose return for other calls
});

// Call 3: Transfer result (depends on swap)
callObjs[2] = CallObject({
    salt: 3,
    amount: 0,
    gas: 100000,
    addr: tokenContract,
    callvalue: abi.encodeWithSignature("transfer(address,uint256)", recipient, 0), // Amount from previous call
    returnvalue: abi.encode(true),
    skippable: false,
    verifiable: true,
    exposeReturn: false
});
```

### 3. DeFi Flash Loan Example

Complete flash loan arbitrage scenario:

```solidity
function executeFlashLoanArbitrage() external {
    // User submits swap objective
    CallObject[] memory userCallObjs = new CallObject[](2);
    
    // Approve tokens for swap
    userCallObjs[0] = CallObject({
        salt: 1,
        amount: 0,
        gas: 100000,
        addr: daiToken,
        callvalue: abi.encodeWithSignature("approve(address,uint256)", pool, 10e18),
        returnvalue: abi.encode(true),
        skippable: false,
        verifiable: true,
        exposeReturn: false
    });
    
    // Execute swap
    userCallObjs[1] = CallObject({
        salt: 2,
        amount: 0,
        gas: 200000,
        addr: pool,
        callvalue: abi.encodeWithSignature("swapDAIForWETH(uint256,uint256)", 10, 2),
        returnvalue: "",
        skippable: false,
        verifiable: true,
        exposeReturn: false
    });

    // Solver provides liquidity and executes
    CallObject[] memory solverCallObjs = new CallObject[](7);
    
    // 1. Approve tokens for liquidity provision
    solverCallObjs[0] = CallObject({
        salt: 0,
        amount: 0,
        gas: 100000,
        addr: daiToken,
        callvalue: abi.encodeWithSignature("approve(address,uint256)", pool, 100e18),
        returnvalue: abi.encode(true),
        skippable: false,
        verifiable: true,
        exposeReturn: false
    });
    
    // 2. Provide liquidity
    solverCallObjs[1] = CallObject({
        salt: 1,
        amount: 0,
        gas: 200000,
        addr: pool,
        callvalue: abi.encodeWithSignature("provideLiquidity(address,uint256,uint256)", address(callBreaker), 100, 10),
        returnvalue: "",
        skippable: false,
        verifiable: true,
        exposeReturn: false
    });
    
    // 3. Check slippage (future call)
    solverCallObjs[2] = CallObject({
        salt: 2,
        amount: 0,
        gas: 100000,
        addr: pool,
        callvalue: abi.encodeWithSignature("checkSlippage(uint256)", 2),
        returnvalue: "",
        skippable: false,
        verifiable: true,
        exposeReturn: true // Expose for verification
    });
    
    // 4-7. Withdraw liquidity and cleanup...
    
    // Execute with custom order
    uint256[] memory orderOfExecution = new uint256[](9);
    orderOfExecution[0] = 2; // Provide liquidity first
    orderOfExecution[1] = 3; // Check slippage
    orderOfExecution[2] = 4; // User approval
    orderOfExecution[3] = 5; // User swap
    orderOfExecution[4] = 6; // Withdraw liquidity
    // ... rest of execution order
    
    callBreaker.executeAndVerify(
        userObjs, 
        returnValues, 
        orderOfExecution, 
        mevTimeData
    );
}
```

### 4. Cross-Chain Objective

Submit objectives for different chains:

```solidity
// Solana chain objective
UserObjective memory solanaObjective = UserObjective({
    appId: hex"01",
    nonce: 1,
    tip: 0.1 ether,
    chainId: 101, // Solana chain ID
    maxFeePerGas: 0,
    maxPriorityFeePerGas: 0,
    sender: msg.sender,
    signature: signature,
    callObjects: callObjs
});

// Add additional data for cross-chain context
AdditionalData[] memory additionalData = new AdditionalData[](3);
additionalData[0] = AdditionalData({
    key: keccak256(abi.encode("amount")),
    value: abi.encode(10e18)
});
additionalData[1] = AdditionalData({
    key: keccak256(abi.encode("SolanaContractAddress")),
    value: abi.encode(keccak256(abi.encode("0x1")))
});
additionalData[2] = AdditionalData({
    key: keccak256(abi.encode("SolanaWalletAddress")),
    value: abi.encode(keccak256(abi.encode("0x2")))
});

callBreaker.pushUserObjective(solanaObjective, additionalData);
```

---

## 👨‍💻 Developer Guide

### Step 1: Understanding the Architecture

STXN operates on a **user-solver model**:

1. **Users** submit objectives (CallObjects) with signatures
2. **Solvers** execute objectives in optimal order with DAG dependencies
3. **CallBreaker** verifies execution and manages state

### Step 2: Setting Up Your Environment

```bash
# 1. Clone and setup
git clone git@github.com:smart-transaction/stxn-smart-contracts-v2.git
cd stxn-smart-contracts-v2
forge install

# 2. Create your test file
touch test/MyIntegration.t.sol

# 3. Import required contracts
import "forge-std/Test.sol";
import {CallBreaker} from "src/CallBreaker.sol";
import {CallObject, UserObjective} from "src/interfaces/ICallBreaker.sol";
```

### Step 3: Basic Integration

```solidity
contract MyIntegrationTest is Test {
    CallBreaker public callBreaker;
    address public user = vm.addr(0x1);
    address public solver = vm.addr(0x2);
    
    function setUp() public {
        callBreaker = new CallBreaker(address(this));
        
        // Fund user and solver
        vm.deal(user, 10 ether);
        vm.deal(solver, 10 ether);
        
        // Deposit to CallBreaker
        vm.prank(user);
        callBreaker.deposit{value: 5 ether}();
    }
    
    function testBasicExecution() public {
        // Your test implementation here
    }
}
```

### Step 4: Working with Signatures

```solidity
// Generate EIP-712 signature
function generateSignature(
    uint256 nonce,
    address sender,
    uint256 signerKey,
    CallObject[] memory callObjects
) internal view returns (bytes memory) {
    bytes32 messageHash = callBreaker.getMessageHash(
        abi.encode(nonce, sender, abi.encode(callObjects))
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, messageHash);
    return abi.encodePacked(r, s, v);
}
```

### Step 5: Advanced Features

#### Pre-Approval System
```solidity
// Set approval addresses for specific app IDs
callBreaker.setApprovalAddresses(
    appId,
    preApprovalContract,
    postApprovalContract
);
```

#### MEV Protection
```solidity
// Add MEV time data for execution
AdditionalData[] memory mevTimeData = new AdditionalData[](1);
mevTimeData[0] = AdditionalData({
    key: keccak256(abi.encodePacked("swapPartner")),
    value: abi.encode(partnerAddress)
});

MevTimeData memory mevData = MevTimeData({
    validatorSignature: validatorSignature,
    mevTimeDataValues: mevTimeData
});
```

### Step 6: Testing Best Practices

1. **Use helper libraries** from `test/utils/`
2. **Test edge cases** like insufficient balance, invalid signatures
3. **Verify return values** match expectations
4. **Test execution order** dependencies
5. **Use proper gas limits** for different call types

### Step 7: Deployment

```bash
# Deploy to testnet
./deploy.sh TESTNET CallBreaker

# Deploy with custom salt
./deploy.sh TESTNET CallBreaker 12345

# Deploy multiple mock tokens
./deploy.sh TESTNET MockERC20 2 '["TokenA","TokenB"]' '["TA","TB"]'
```

---

## 🚀 Deployment & Verification

### Deployment Script Usage

The project includes a comprehensive deployment script that supports multiple networks and contract types:

```bash
./deploy.sh <NETWORK_TYPE> <CONTRACT_NAME> [chains] [count] [names-array] [symbols-array]
```

#### Parameters:
- `<NETWORK_TYPE>`: Target network (`MAINNET`, `TESTNET`, `LESTNET`)
- `<CONTRACT_NAME>`: Contract to deploy (`CallBreaker`, `MockERC20`, etc.)
- `[chains]`: Optional JSON array of target chains
- `[count]`: Number of instances to deploy (for MockERC20)
- `[names-array]`: JSON array of token names (for MockERC20)
- `[symbols-array]`: JSON array of token symbols (for MockERC20)

#### Examples:

**Deploy CallBreaker:**
```bash
# Basic deployment
./deploy.sh TESTNET CallBreaker

# With custom salt
./deploy.sh TESTNET CallBreaker 12345

# To specific chains
./deploy.sh TESTNET CallBreaker '["ethereum", "polygon"]'
```

**Deploy MockERC20 tokens:**
```bash
# Single token
./deploy.sh TESTNET MockERC20 1 '["TestToken"]' '["TEST"]'

# Multiple tokens
./deploy.sh TESTNET MockERC20 2 '["TokenA","TokenB"]' '["TA","TB"]'
```

**Deploy to Lestnet:**
```bash
./deploy.sh LESTNET CallBreaker
```

### Contract Verification

#### Lestnet Verification
```bash
forge verify-contract \
  --rpc-url https://service.lestnet.org \
  <CONTRACT_ADDRESS> \
  <CONTRACT_NAME> \
  --verifier blockscout \
  --verifier-url https://explore.lestnet.org/api/
```

#### Other Networks
```bash
forge verify-contract \
  <CONTRACT_ADDRESS> \
  <CONTRACT_PATH>:<CONTRACT_NAME> \
  --chain <CHAIN_ID> \
  --watch \
  --etherscan-api-key <API_KEY>
```

**Example:**
```bash
forge verify-contract \
  0x1234...5678 \
  src/CallBreaker.sol:CallBreaker \
  --chain 1 \
  --watch \
  --etherscan-api-key YOUR_API_KEY
```

### Environment Setup

Create a `.env` file for deployment configuration:

```bash
# .env
PRIVATE_KEY=your_private_key
ETHERSCAN_API_KEY=your_etherscan_api_key
LESTNET_RPC_URL=https://service.lestnet.org
```

### Network Configuration

The deployment script uses `config/networks.json` for network-specific settings. Supported networks:

- **MAINNET**: Ethereum mainnet
- **TESTNET**: Ethereum testnets (Sepolia, Goerli)
- **LESTNET**: Lestnet blockchain

---

## 🧪 Testing

### Running Tests

```bash
# Run all tests
forge test

# Run with verbose output
forge test -vvv

# Run specific test
forge test --match-test testExecuteAndVerifyWithUserReturns

# Run tests with gas reporting
forge test --gas-report

# Run tests in parallel
forge test --parallel
```

### Test Structure

```
test/
├── CallBreaker.t.sol           # Main contract tests
├── e2e/                        # End-to-end scenarios
│   ├── SelfCheckout.t.sol      # DeFi self-checkout example
│   ├── FlashLiquiditySwap.t.sol # Flash loan arbitrage
│   ├── KITNDisbursement.t.sol  # Token disbursement
│   ├── MEVTimeCompute.t.sol    # MEV protection
│   └── BlockTimeScheduler.t.sol # Time-based scheduling
└── utils/                      # Test utilities
    ├── CallBreakerTestHelper.sol # Helper functions
    └── SignatureHelper.sol      # Signature generation
```

### Test Categories

1. **Unit Tests**: Individual function testing
2. **Integration Tests**: Multi-contract interactions
3. **E2E Tests**: Complete user scenarios
4. **Edge Case Tests**: Error conditions and limits

### Writing Tests

Use the provided helper libraries for consistent test setup:

```solidity
import {CallBreakerTestHelper} from "test/utils/CallBreakerTestHelper.sol";
import {SignatureHelper} from "test/utils/SignatureHelper.sol";

contract MyTest is Test {
    function testMyScenario() public {
        // Use helpers for consistent setup
        CallObject[] memory callObjs = new CallObject[](1);
        callObjs[0] = CallBreakerTestHelper.buildCallObject(
            targetContract,
            callData,
            expectedReturn
        );
        
        // Generate signature
        bytes memory signature = signatureHelper.generateSignature(
            nonce, sender, privateKey, callObjs
        );
        
        // Build user objective
        UserObjective memory objective = CallBreakerTestHelper.buildUserObjective(
            nonce, sender, signature, callObjs
        );
        
        // Test execution
        callBreaker.pushUserObjective(objective, new AdditionalData[](0));
    }
}
```

---

## 🔧 Advanced Configuration

### Gas Optimization

The CallBreaker contract uses several gas optimization techniques:

- **Transient storage** for execution state
- **Efficient storage patterns** with packed structs
- **Batch operations** for multiple calls
- **Return value caching** to avoid redundant calls

### Security Considerations

1. **Signature Verification**: All objectives must be properly signed
2. **Balance Checks**: Sufficient ETH balance required for execution
3. **Gas Limits**: Proper gas limits prevent out-of-gas failures
4. **Return Value Verification**: Ensures execution integrity
5. **Access Control**: Owner-only functions for critical operations

### Performance Tuning

```solidity
// Optimize gas usage
CallObject memory callObj = CallObject({
    salt: 1,
    amount: 0,
    gas: 100000, // Set appropriate gas limit
    addr: targetContract,
    callvalue: callData,
    returnvalue: expectedReturn,
    skippable: false,
    verifiable: true,
    exposeReturn: false // Set to true only if needed
});
```

---

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Write tests** for your changes
4. **Run the test suite**: `forge test`
5. **Commit your changes**: `git commit -m 'Add amazing feature'`
6. **Push to the branch**: `git push origin feature/amazing-feature`
7. **Open a Pull Request**

### Development Guidelines

- Follow Solidity style guidelines
- Add comprehensive tests for new features
- Update documentation for API changes
- Ensure all tests pass before submitting PR
- Use meaningful commit messages

### Code Style

```solidity
// Use descriptive variable names
address public immutable callBreakerAddress;

// Add comprehensive documentation
/// @notice Executes and verifies call objects
/// @param userObjectives Array of user objectives to execute
/// @param returnValues Expected return values for verification
/// @param orderOfExecution Order of execution for DAG optimization
function executeAndVerify(
    UserObjective[] calldata userObjectives,
    bytes[] calldata returnValues,
    uint256[] calldata orderOfExecution,
    MevTimeData calldata mevTimeData
) external;
```

---

## 📚 Additional Resources

### Documentation
- [Foundry Book](https://book.getfoundry.sh/) - Foundry documentation
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/) - Security patterns
- [EIP-712](https://eips.ethereum.org/EIPS/eip-712) - Structured data signing

### Community
- [GitHub Issues](https://github.com/smart-transaction/stxn-smart-contracts-v2/issues) - Bug reports and feature requests
- [Discussions](https://github.com/smart-transaction/stxn-smart-contracts-v2/discussions) - Community discussions

### Security
- **Audit Status**: In progress
- **Bug Bounty**: Contact team for details
- **Security Contact**: security@smart-transaction.com

---

## 📜 License

This project is licensed under the Business Source License 1.1 - see the [LICENSE](LICENSE) file for details.

**Business Source License 1.1 © Smart Transaction Corp.**

---

## 📬 Contact

- **Website**: [smart-transaction.com](https://smart-transaction.com)
- **Email**: contact@smart-transaction.com
- **GitHub**: [smart-transaction/stxn-smart-contracts-v2](https://github.com/smart-transaction/stxn-smart-contracts-v2)
- **Issues**: [GitHub Issues](https://github.com/smart-transaction/stxn-smart-contracts-v2/issues)

---

## 🙏 Acknowledgments

- [Foundry](https://github.com/foundry-rs/foundry) - Smart contract development framework
- [OpenZeppelin](https://openzeppelin.com/) - Secure smart contract libraries
- [Ethereum Foundation](https://ethereum.org/) - Blockchain infrastructure
