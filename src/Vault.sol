// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRebaseToken} from "./interface/IRebaseToken.sol";

/**
 * @title Vault
 * @author Varun Chauhan
 * @notice A vault contract that allows users to deposit ETH and receive rebase tokens in return
 * @dev This contract acts as a bridge between ETH and RebaseToken, allowing users to:
 *      - Deposit ETH and receive equivalent RebaseToken amount
 *      - Redeem RebaseTokens to get back ETH
 *      - The vault holds ETH reserves while users hold interest-bearing RebaseTokens
 *
 * Key Features:
 * - 1:1 ETH to RebaseToken exchange rate
 * - Automatic interest rate assignment from RebaseToken contract
 * - Support for full balance redemption using type(uint256).max
 * - Secure ETH transfer handling with proper error checking
 */
contract Vault {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The RebaseToken contract interface for minting/burning operations
    /// @dev Immutable to ensure the token contract cannot be changed after deployment
    IRebaseToken private immutable i_rebaseToken;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a user deposits ETH and receives RebaseTokens
     * @param from The address that made the deposit
     * @param amount The amount of ETH deposited (and RebaseTokens minted)
     */
    event Deposit(address indexed from, uint256 amount);

    /**
     * @notice Emitted when a user redeems RebaseTokens for ETH
     * @param from The address that made the redemption
     * @param amount The amount of RebaseTokens redeemed (and ETH withdrawn)
     */
    event Redeem(address indexed from, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when ETH transfer to user fails during redemption
    error Vault__RedeemFailed();

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the Vault contract with a RebaseToken interface
     * @dev Sets the RebaseToken contract address as immutable
     * @param _rebaseToken The address of the RebaseToken contract
     */
    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE FUNCTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows the contract to receive ETH directly
     * @dev This enables the contract to hold ETH reserves for redemptions
     */
    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows users to deposit ETH and receive equivalent RebaseTokens
     * @dev Mints RebaseTokens to the sender using the current global interest rate
     *      The exchange rate is 1:1 (1 ETH = 1 RebaseToken unit)
     * @custom:emits Deposit event with sender address and deposited amount
     */
    function deposit() external payable {
        i_rebaseToken.mint(
            msg.sender,
            msg.value,
            i_rebaseToken.getInterestRate()
        );
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Allows users to redeem RebaseTokens for ETH
     * @dev Burns the specified amount of RebaseTokens and transfers equivalent ETH
     *      Uses secure transfer pattern with proper error handling
     * @param _amount The amount of RebaseTokens to redeem (use type(uint256).max for full balance)
     * @custom:throws Vault__RedeemFailed if ETH transfer to user fails
     * @custom:emits Redeem event with sender address and redeemed amount
     */
    function redeem(uint256 _amount) external {
        // Handle max redemption case
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }

        // Burn the RebaseTokens from user's balance
        i_rebaseToken.burn(msg.sender, _amount);

        // Transfer equivalent ETH to the user
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }

        emit Redeem(msg.sender, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the address of the RebaseToken contract
     * @dev Useful for frontend interfaces and contract verification
     * @return The address of the RebaseToken contract
     */
    function getRebaseTokenAddress() public view returns (address) {
        return address(i_rebaseToken);
    }

    /**
     * @notice Returns the current global interest rate from the RebaseToken
     * @dev Convenience function to check interest rate without calling RebaseToken directly
     * @return The current interest rate scaled by the RebaseToken's precision factor
     */
    function getCurrentInterestRate() public view returns (uint256) {
        return i_rebaseToken.getInterestRate();
    }
}
