// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Pool} from "@ccip/contracts/src/v0.8/ccip/libraries/Pool.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IRebaseToken} from "./interface/IRebaseToken.sol";

/**
 * @title RebaseTokenPool
 * @author Varun Chauhan
 * @notice CCIP Token Pool for RebaseToken that handles cross-chain transfers while preserving interest rates
 * @dev This contract implements the CCIP TokenPool interface for RebaseToken, enabling cross-chain transfers
 *      of interest-bearing tokens. The pool uses a burn-and-mint mechanism where tokens are burned on the
 *      source chain and minted on the destination chain, preserving the user's individual interest rate.
 *
 * Key Features:
 * - Burn-and-mint cross-chain transfer mechanism
 * - Preserves user's individual interest rates across chains
 * - Integrates with Chainlink CCIP for secure cross-chain messaging
 * - Rate limiting and allowlist support for enhanced security
 *
 * Flow:
 * 1. User initiates cross-chain transfer on source chain
 * 2. lockOrBurn() captures user's interest rate and burns tokens
 * 3. Interest rate is encoded in destPoolData for destination chain
 * 4. releaseOrMint() decodes interest rate and mints tokens with preserved rate
 */
contract RebaseTokenPool is TokenPool {
    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize the RebaseTokenPool with required CCIP infrastructure
     * @dev Sets up the token pool with necessary addresses for CCIP functionality
     * @param token The RebaseToken contract address that this pool will manage
     * @param allowlist Array of addresses allowed to use this pool (empty array = no allowlist)
     * @param rmnProxy The Risk Management Network proxy address for additional security
     * @param router The CCIP router address that will interact with this pool
     */
    constructor(
        IERC20 token,
        address[] memory allowlist,
        address rmnProxy,
        address router
    ) TokenPool(token, allowlist, rmnProxy, router) {}

    /*//////////////////////////////////////////////////////////////
                           CCIP CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Burns tokens on source chain when initiating cross-chain transfer
     * @dev This function is called by CCIP when a user wants to send tokens to another chain.
     *      It captures the sender's current interest rate and burns their tokens, encoding the
     *      interest rate in the destination pool data to preserve it on the destination chain.
     * @param lockOrBurnIn Input parameters containing transfer details
     * @return lockOrBurnOut Output containing destination token address and encoded interest rate
     *
     * Process:
     * 1. Validates the burn request using parent contract validation
     * 2. Retrieves the user's current interest rate from the RebaseToken
     * 3. Burns the specified amount of tokens from this pool contract
     * 4. Encodes the interest rate in destPoolData for destination chain
     */
    function lockOrBurn(
        Pool.LockOrBurnInV1 calldata lockOrBurnIn
    ) external returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut) {
        // Perform standard CCIP validation (rate limits, chain support, etc.)
        _validateLockOrBurn(lockOrBurnIn);

        // Capture the user's current interest rate to preserve it across chains
        uint256 interestRate = IRebaseToken(address(i_token))
            .getUserInterestRate(lockOrBurnIn.originalSender);

        // Burn tokens from this pool contract (tokens should be transferred here first)
        IRebaseToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);

        // Return destination token address and encoded interest rate for destination chain
        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(interestRate) // Preserve user's interest rate
        });
    }

    /**
     * @notice Mints tokens on destination chain when receiving cross-chain transfer
     * @dev This function is called by CCIP when tokens arrive on the destination chain.
     *      It decodes the preserved interest rate and mints tokens to the receiver with
     *      their original interest rate intact.
     * @param releaseOrMintIn Input parameters containing transfer details and encoded interest rate
     * @return releaseOrMintOut Output containing the amount of tokens minted
     *
     * Process:
     * 1. Validates the mint request using parent contract validation
     * 2. Decodes the preserved interest rate from sourcePoolData
     * 3. Mints tokens to the receiver with their original interest rate
     * 4. Returns the amount minted (should match the amount requested)
     */
    function releaseOrMint(
        Pool.ReleaseOrMintInV1 calldata releaseOrMintIn
    ) external returns (Pool.ReleaseOrMintOutV1 memory releaseOrMintOut) {
        // Perform standard CCIP validation (rate limits, chain support, etc.)
        _validateReleaseOrMint(releaseOrMintIn);

        // Decode the preserved interest rate from the source chain
        uint256 interestRate = abi.decode(
            releaseOrMintIn.sourcePoolData,
            (uint256)
        );

        // Mint tokens to the receiver with their preserved interest rate
        IRebaseToken(address(i_token)).mint(
            releaseOrMintIn.receiver,
            releaseOrMintIn.amount,
            interestRate // Restore the user's original interest rate
        );

        // Return the amount of tokens minted
        releaseOrMintOut = Pool.ReleaseOrMintOutV1({
            destinationAmount: releaseOrMintIn.amount
        });
    }
}
