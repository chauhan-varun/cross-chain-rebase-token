// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author Varun Chauhan
 * @notice A rebasing ERC20 token that automatically accrues interest over time for token holders
 * @dev This contract implements an interest-bearing token where user balances increase over time
 *      based on individual interest rates. The token uses a precision factor for accurate calculations
 *      and includes role-based access control for minting and burning operations.
 *
 * Key Features:
 * - Individual interest rates per user
 * - Automatic interest accrual on balance queries and transfers
 * - Role-based minting and burning
 * - Owner-controlled global interest rate management
 * - Support for max uint256 transfers (entire balance)
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when trying to set an interest rate higher than the current rate
    error RebaseToken__InterestRateShouldBeLessThanPrevious();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Precision factor used for interest rate calculations (1e27)
    /// @dev This high precision factor ensures accurate interest calculations
    uint256 constant PRECISION_FACTOR = 1e18;

    /// @notice Role identifier for addresses allowed to mint and burn tokens
    bytes32 constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Global interest rate (default: 5% annually represented as 5e18)
    /// @dev Interest rate is stored with PRECISION_FACTOR scaling
    uint256 private s_interestRate = 5e18;

    /// @notice Mapping of user addresses to their individual interest rates
    /// @dev Each user can have a different interest rate set during minting
    mapping(address user => uint256 interestRate) private s_userInterestRate;

    /// @notice Mapping of user addresses to their last interaction timestamp
    /// @dev Used to calculate time elapsed for interest accrual
    mapping(address user => uint256 lastTimestamp) private s_userLastTimestamp;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when the global interest rate is updated
     * @param previousInterestRate The previous interest rate
     * @param newInterestRate The new interest rate
     */
    event InterestRateUpdated(
        uint256 previousInterestRate,
        uint256 newInterestRate
    );

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the RebaseToken contract
     * @dev Sets up the ERC20 token with name "Rebase Token" and symbol "RBT"
     *      Sets the deployer as the initial owner
     */
    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    /*//////////////////////////////////////////////////////////////
                             ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Grants the MINT_AND_BURN_ROLE to a specified account
     * @dev Only the contract owner can call this function
     * @param _account The address to grant the role to
     */
    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * @notice Updates the global interest rate
     * @dev The new interest rate must be less than or equal to the current rate
     * @param _interestRate The new interest rate (scaled by PRECISION_FACTOR)
     * @custom:throws RebaseToken__InterestRateShouldBeLessThanPrevious if new rate > current rate
     */
    function setInterestRate(uint256 _interestRate) public onlyOwner {
        if (_interestRate > s_interestRate)
            revert RebaseToken__InterestRateShouldBeLessThanPrevious();

        uint256 previousRate = s_interestRate;
        s_interestRate = _interestRate;
        emit InterestRateUpdated(previousRate, _interestRate);
    }

    /*//////////////////////////////////////////////////////////////
                        MINT AND BURN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints new tokens to a specified address with a custom interest rate
     * @dev Only accounts with MINT_AND_BURN_ROLE can call this function
     *      Automatically accrues any pending interest before minting
     * @param _to The address to mint tokens to
     * @param _amount The amount of tokens to mint
     * @param _interestRate The interest rate to set for this user
     */
    function mint(
        address _to,
        uint256 _amount,
        uint256 _interestRate
    ) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = _interestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice Burns tokens from a specified address
     * @dev Only accounts with MINT_AND_BURN_ROLE can call this function
     *      Automatically accrues any pending interest before burning
     * @param _from The address to burn tokens from
     * @param _amount The amount of tokens to burn (use type(uint256).max for entire balance)
     */
    function burn(
        address _from,
        uint256 _amount
    ) external onlyRole(MINT_AND_BURN_ROLE) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                        TRANSFER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Transfers tokens from the caller to a recipient
     * @dev Overrides ERC20 transfer to include interest accrual and rate inheritance
     *      If recipient has zero balance, they inherit sender's interest rate
     * @param _recipient The address to transfer tokens to
     * @param _amount The amount to transfer (use type(uint256).max for entire balance)
     * @return bool indicating success
     */
    function transfer(
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }

        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);

        // If recipient has no balance, inherit sender's interest rate
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }

        return super.transfer(_recipient, _amount);
    }

    /**
     * @notice Transfers tokens from one address to another (with allowance)
     * @dev Overrides ERC20 transferFrom to include interest accrual and rate inheritance
     *      If recipient has zero balance, they inherit sender's interest rate
     * @param _sender The address to transfer tokens from
     * @param _recipient The address to transfer tokens to
     * @param _amount The amount to transfer (use type(uint256).max for entire balance)
     * @return bool indicating success
     */
    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }

        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);

        // If recipient has no balance, inherit sender's interest rate
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }

        return super.transferFrom(_sender, _recipient, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the balance of a user including accrued interest
     * @dev This is the main balance function that includes interest calculations
     * @param _user The address to check balance for
     * @return The total balance including accrued interest
     */
    function balanceOf(address _user) public view override returns (uint256) {
        uint256 currentPrincipalBalance = super.balanceOf(_user);
        if (currentPrincipalBalance == 0) {
            return 0;
        }

        return
            (currentPrincipalBalance *
                _calculateAccumulatedInterestSinceLastUpdate(_user)) /
            PRECISION_FACTOR;
    }

    /**
     * @notice Returns the principal balance of a user (without accrued interest)
     * @dev This shows the actual minted token amount without interest
     * @param _user The address to check principal balance for
     * @return The principal balance without interest
     */
    function principleBalanceOf(address _user) public view returns (uint256) {
        return super.balanceOf(_user);
    }

    /**
     * @notice Returns the current global interest rate
     * @return The global interest rate scaled by PRECISION_FACTOR
     */
    function getInterestRate() public view returns (uint256) {
        return s_interestRate;
    }

    /**
     * @notice Returns the interest rate for a specific user
     * @param _user The address to check interest rate for
     * @return The user's individual interest rate scaled by PRECISION_FACTOR
     */
    function getUserInterestRate(address _user) public view returns (uint256) {
        return s_userInterestRate[_user];
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints accrued interest for a user and updates their timestamp
     * @dev Internal function called before transfers and burns to realize interest
     * @param _user The address to mint accrued interest for
     */
    function _mintAccruedInterest(address _user) internal {
        uint256 previousBalance = super.balanceOf(_user);
        uint256 currentBalance = balanceOf(_user);
        uint256 increasedBalance = currentBalance - previousBalance;

        if (increasedBalance > 0) {
            _mint(_user, increasedBalance);
        }

        s_userLastTimestamp[_user] = block.timestamp;
    }

    /**
     * @notice Calculates the accumulated interest multiplier since last update
     * @dev Uses linear interest calculation: PRECISION_FACTOR + (rate * timeElapsed)
     * @param _user The address to calculate interest for
     * @return The interest multiplier scaled by PRECISION_FACTOR
     */
    function _calculateAccumulatedInterestSinceLastUpdate(
        address _user
    ) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - s_userLastTimestamp[_user];
        uint256 linearInterest = (PRECISION_FACTOR +
            (s_userInterestRate[_user] * timeElapsed));

        return linearInterest;
    }
}
