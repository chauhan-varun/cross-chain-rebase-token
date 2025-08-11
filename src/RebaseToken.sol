// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract RebaseToken is ERC20, Ownable, AccessControl {
    /*//////////////////////////////////////////////////////////////
			    ERRORS
    //////////////////////////////////////////////////////////////*/

    error RebaseToken__InterestRateShouldBeLessThanPrevious();

    /*//////////////////////////////////////////////////////////////
			    VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 constant PRISION_FACTOR = 1e10;
    bytes32 constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private s_interestRate = 5e10;

    mapping(address user => uint256 interstRate) private s_userInterestRate;
    mapping(address user => uint256 lastTimestamp) private s_userLastTimestamp;

    /*//////////////////////////////////////////////////////////////
			    EVENTS
    //////////////////////////////////////////////////////////////*/

    event InterestRateUpdated(
        uint256 previousInterestRate,
        uint256 newInterestRate
    );

    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    function setInterestRate(uint256 _interestRate) public onlyOwner {
        if (_interestRate > s_interestRate)
            revert RebaseToken__InterestRateShouldBeLessThanPrevious();
        s_interestRate = _interestRate;
        emit InterestRateUpdated(s_interestRate, _interestRate);
    }

    function mint(
        address _to,
        uint256 _amount
    ) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    function transfer(
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    function principleBalanceOf(address _user) public view returns (uint256) {
        return super.balanceOf(_user);
    }

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

    function balanceOf(address _user) public view override returns (uint256) {
        return
            (super.balanceOf(_user) *
                _calculateAccumulatedInterestSinceLastUpdate(_user)) /
            PRISION_FACTOR;
    }

    function _mintAccruedInterest(address _user) internal {
        uint256 priviousBalance = super.balanceOf(_user);
        uint256 currentBalance = balanceOf(_user);
        uint256 increasedBalance = currentBalance - priviousBalance;
        s_userLastTimestamp[_user] = block.timestamp;
        _mint(_user, increasedBalance);
    }

    function _calculateAccumulatedInterestSinceLastUpdate(
        address _user
    ) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - s_userLastTimestamp[_user];
        uint256 linearInterest = (PRISION_FACTOR +
            (s_userInterestRate[_user] * timeElapsed));

        return linearInterest;
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getInterestRate() public view returns (uint256) {
        return s_interestRate;
    }

    function getUserInterestRate(address _user) public view returns (uint256) {
        return s_userInterestRate[_user];
    }
}
