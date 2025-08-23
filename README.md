# Cross-Chain Rebase Token (CCIP)

A sophisticated DeFi protocol that implements an interest-bearing rebase token system with cross-chain capabilities using Chainlink CCIP. Users can deposit ETH into a vault and receive rebase tokens that automatically accrue interest over time.

## Overview

This project consists of three main smart contracts and supporting deployment scripts:

### 🏦 **RebaseToken**
An advanced ERC20 token that automatically increases holder balances over time based on individual interest rates:
- **Automatic Interest Accrual**: Balances grow continuously based on time elapsed
- **Individual Interest Rates**: Each user can have a custom interest rate set during minting
- **Role-Based Access Control**: Secure minting and burning operations via AccessControl
- **High Precision Calculations**: Uses 1e18 precision factor for accurate interest computation
- **Owner Controls**: Global interest rate management with decrease-only safeguards
- **Max Amount Support**: Special handling for `type(uint256).max` transfers and burns

### � **RebaseTokenPool**
A Chainlink CCIP token pool that enables cross-chain transfers while preserving interest rates:
- **Burn-and-Mint Mechanism**: Secure cross-chain token transfers
- **Interest Rate Preservation**: Maintains user's individual interest rates across chains
- **CCIP Integration**: Full compatibility with Chainlink's Cross-Chain Interoperability Protocol
- **Security Features**: Rate limiting and allowlist support for enhanced protection
- **Encoded Transfer Data**: Smart encoding of interest rates in cross-chain messages

### �🏛️ **Vault**
A secure vault contract that bridges ETH and RebaseTokens with automatic interest assignment:
- **1:1 Exchange Rate**: Deposit ETH to receive equivalent RebaseTokens
- **Interest-Bearing Deposits**: Your tokens automatically grow while in your wallet
- **Flexible Redemption**: Redeem tokens back to ETH at any time including full balance
- **Automatic Rate Assignment**: New deposits inherit current global interest rate
- **Secure ETH Handling**: Robust error handling for failed ETH transfers

## Key Features

- ✅ **Interest-Bearing Tokens**: Balances automatically increase over time
- ✅ **Flexible Interest Rates**: Per-user customizable rates
- ✅ **Secure Architecture**: Role-based access control and ownership patterns
- ✅ **Gas Optimized**: Efficient interest calculations with precision factors
- ✅ **Cross-Chain Ready**: Built with Chainlink CCIP integration in mind
- ✅ **100% Test Coverage**: Complete test suite with comprehensive edge case coverage

## Built With

- **Solidity ^0.8.24**: Smart contract development
- **Foundry**: Development framework and testing
- **OpenZeppelin**: Security-audited contract libraries
- **Chainlink CCIP**: Cross-chain interoperability protocol

## Quick Start

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/chauhan-varun/cross-chain-rebase-token.git
   cd cross-chain-rebase-token
   ```

2. **Install dependencies**
   ```bash
   forge install
   ```

3. **Build the project**
   ```bash
   forge build
   ```

4. **Run tests**
   ```bash
   forge test
   ```

## Usage

### Development Commands

### Build

```bash
forge build
```

### Test

```bash
forge test
```

### Test with Verbosity

```bash
forge test -vvv
```

### Format Code

```bash
forge fmt
```

### Gas Snapshots

```bash
forge snapshot
```

### Coverage Report

```bash
forge coverage
```

Generate detailed coverage report:
```bash
forge coverage --report lcov
```

## Smart Contract Architecture

### RebaseToken.sol
- **Inherits**: ERC20, Ownable, AccessControl
- **Key State Variables**:
  - `s_interestRate`: Global interest rate (default: 5e18 = 5% annually)
  - `s_userInterestRate`: Mapping of user-specific interest rates
  - `s_userLastTimestamp`: Mapping of user's last interaction timestamps
- **Key Functions**:
  - `mint(address, uint256, uint256)`: Mint tokens with custom interest rate
  - `burn(address, uint256)`: Burn tokens from an address (supports max amount)
  - `setInterestRate(uint256)`: Update global interest rate (owner only, decrease-only)
  - `balanceOf(address)`: Returns current balance including accrued interest
  - `principleBalanceOf(address)`: Returns original minted amount without interest
  - `transfer(address, uint256)`: Enhanced transfer with interest accrual and rate inheritance
  - `transferFrom(address, address, uint256)`: Enhanced transferFrom with same features

### RebaseTokenPool.sol
- **Inherits**: TokenPool (Chainlink CCIP)
- **Key Features**:
  - Cross-chain burn-and-mint mechanism
  - Interest rate preservation across chains
  - Integration with CCIP router and RMN proxy
- **Key Functions**:
  - `lockOrBurn(Pool.LockOrBurnInV1)`: Burns tokens and encodes interest rate for cross-chain transfer
  - `releaseOrMint(Pool.ReleaseOrMintInV1)`: Mints tokens with preserved interest rate on destination chain

### Vault.sol
- **Key State Variables**:
  - `i_rebaseToken`: Immutable reference to RebaseToken contract
- **Key Functions**:
  - `deposit()`: Deposit ETH, receive RebaseTokens with current global interest rate
  - `redeem(uint256)`: Redeem RebaseTokens for ETH (supports max amount redemption)
  - `getRebaseTokenAddress()`: Returns RebaseToken contract address
  - `getCurrentInterestRate()`: Returns current global interest rate
  - `receive()`: Fallback function for direct ETH deposits

## Testing

The project includes **comprehensive tests with 100% code coverage** for all core contracts:

### Coverage Statistics
- **RebaseToken.sol**: 100% Lines, 100% Statements, 100% Branches, 100% Functions
- **Vault.sol**: 100% Lines, 100% Statements, 100% Branches, 100% Functions  
- **RebaseTokenPool.sol**: 100% Lines, 100% Statements, 100% Branches, 100% Functions

### Test Suites
- ✅ **RebaseTokenTest**: Core token functionality and interest mechanics (9 tests)
- ✅ **AdditionalCoverageTest**: Edge cases, max amounts, and error scenarios (11 tests)
- ✅ **CrossChainTest**: Cross-chain bridging and CCIP functionality (3 tests)
- ✅ **Total**: 23 tests with comprehensive coverage

### What's Tested
- ✅ **Token Operations**: Minting, burning, transfers with interest rate handling
- ✅ **Interest Mechanics**: Time-based interest accrual and rate calculations
- ✅ **Vault Operations**: ETH deposits, token redemptions, and exchange flows
- ✅ **Access Control**: Role-based permissions and ownership management
- ✅ **Edge Cases**: Zero balances, max transfers, failed transactions, different interest rates
- ✅ **Cross-chain Features**: CCIP bridging, interest rate preservation across chains
- ✅ **Error Handling**: Revert scenarios and comprehensive error condition testing

Run specific test files:
```bash
forge test --match-contract RebaseTokenTest
forge test --match-contract AdditionalCoverageTest  
forge test --match-contract CrossChainTest
```

## Security Considerations

- **Access Control**: Role-based permissions for critical functions
- **Integer Overflow**: SafeMath patterns and Solidity 0.8+ built-in protection
- **Reentrancy**: Proper state updates before external calls
- **Precision**: High-precision arithmetic for accurate interest calculations
- **100% Test Coverage**: All code paths tested including edge cases and error conditions
- **Failed Transaction Handling**: Comprehensive error handling for ETH transfers and edge cases

## Local Development

### Start Local Blockchain

```bash
anvil
```

## Project Structure

```
src/
├── RebaseToken.sol              # Main rebasing ERC20 token contract
├── RebaseTokenPool.sol          # CCIP token pool for cross-chain transfers
├── Vault.sol                   # ETH ⟷ RebaseToken exchange vault
└── interface/
    └── IRebaseToken.sol         # RebaseToken interface for external integrations

script/
├── Deployer.s.sol              # Deploys RebaseToken and RebaseTokenPool contracts
├── ConfigurePool.s.sol         # Configures token pool settings and permissions
├── BridgeTokens.s.sol          # Handles cross-chain token bridging operations
└── Interactions.s.sol          # Utility script for contract interactions

test/
├── RebaseTokenTest.t.sol       # Core RebaseToken functionality tests
├── AdditionalCoverageTest.t.sol # Edge cases and comprehensive coverage tests
└── CrossChainTest.t.sol        # Cross-chain bridging tests
```

### Script Details

- **Deployer.s.sol**: Comprehensive deployment script that sets up RebaseToken and RebaseTokenPool contracts with proper CCIP infrastructure including router and RMN proxy configuration
- **ConfigurePool.s.sol**: Post-deployment configuration script for setting up token pool parameters, allowlists, and admin permissions
- **BridgeTokens.s.sol**: Cross-chain bridging utility that handles CCIP message construction and token transfers between chains
- **Interactions.s.sol**: General purpose interaction script for testing and managing deployed contracts

## Configuration

The project uses Foundry with the following configuration (`foundry.toml`):
- Source directory: `src/`
- Test directory: `test/`
- Libraries: `lib/`
- OpenZeppelin remapping for imports

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Future Enhancements

- 🔮 **Cross-Chain Integration**: Full Chainlink CCIP implementation
- 🏦 **Multi-Asset Support**: Support for other ERC20 tokens
- 📊 **Yield Farming**: Additional DeFi yield strategies
- 🔐 **Multi-Sig Support**: Enhanced security for vault operations

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Foundry](https://github.com/foundry-rs/foundry) - Ethereum development toolkit
- [OpenZeppelin](https://openzeppelin.com/) - Secure smart contract library
- [Chainlink](https://chain.link/) - Cross-chain infrastructure
