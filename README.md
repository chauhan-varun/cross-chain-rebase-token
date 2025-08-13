# Cross-Chain Rebase Token (CCIP)

A sophisticated DeFi protocol that implements an interest-bearing rebase token system with cross-chain capabilities using Chainlink CCIP. Users can deposit ETH into a vault and receive rebase tokens that automatically accrue interest over time.

## Overview

This project consists of two main smart contracts:

### 🏦 **RebaseToken**
An ERC20 token that automatically increases holder balances over time based on individual interest rates:
- **Automatic Interest Accrual**: Balances grow continuously based on time elapsed
- **Individual Interest Rates**: Each user can have a custom interest rate
- **Role-Based Access Control**: Secure minting and burning operations
- **High Precision Calculations**: Uses 1e18 precision factor for accurate interest computation
- **Owner Controls**: Global interest rate management with safeguards

### 🏛️ **Vault**
A secure vault contract that bridges ETH and RebaseTokens:
- **1:1 Exchange Rate**: Deposit ETH to receive equivalent RebaseTokens
- **Interest-Bearing Deposits**: Your tokens automatically grow while in your wallet
- **Flexible Redemption**: Redeem tokens back to ETH at any time
- **Full Balance Support**: Use `type(uint256).max` for complete withdrawals

## Key Features

- ✅ **Interest-Bearing Tokens**: Balances automatically increase over time
- ✅ **Flexible Interest Rates**: Per-user customizable rates
- ✅ **Secure Architecture**: Role-based access control and ownership patterns
- ✅ **Gas Optimized**: Efficient interest calculations with precision factors
- ✅ **Cross-Chain Ready**: Built with Chainlink CCIP integration in mind
- ✅ **Comprehensive Testing**: Full test suite with edge case coverage

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

## Smart Contract Architecture

### RebaseToken.sol
- **Inherits**: ERC20, Ownable, AccessControl
- **Key Functions**:
  - `mint(address, uint256, uint256)`: Mint tokens with custom interest rate
  - `burn(address, uint256)`: Burn tokens from an address
  - `setInterestRate(uint256)`: Update global interest rate (owner only)
  - `balanceOf(address)`: Returns current balance including accrued interest

### Vault.sol
- **Key Functions**:
  - `deposit()`: Deposit ETH, receive RebaseTokens
  - `redeem(uint256)`: Redeem RebaseTokens for ETH
  - `receive()`: Fallback function for ETH deposits

## Testing

The project includes comprehensive tests covering:
- ✅ Token minting and burning
- ✅ Interest accrual calculations
- ✅ Vault deposit and redemption flows
- ✅ Access control mechanisms
- ✅ Edge cases and error conditions

Run specific test files:
```bash
forge test --match-contract RebaseTokenTest
forge test --match-contract VaultTest
```

## Security Considerations

- **Access Control**: Role-based permissions for critical functions
- **Integer Overflow**: SafeMath patterns and Solidity 0.8+ built-in protection
- **Reentrancy**: Proper state updates before external calls
- **Precision**: High-precision arithmetic for accurate interest calculations

## Local Development

### Start Local Blockchain

```bash
anvil
```

## Project Structure

```
src/
├── RebaseToken.sol          # Main rebasing ERC20 token contract
├── Vault.sol               # ETH ⟷ RebaseToken exchange vault
└── interface/
    └── IRebaseToken.sol     # RebaseToken interface

test/
├── RebaseTokenTest.t.sol    # RebaseToken contract tests
└── VaultTest.t.sol         # Vault contract tests

lib/
├── forge-std/              # Foundry standard library
└── openzeppelin-contracts/ # OpenZeppelin contract library
```

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
