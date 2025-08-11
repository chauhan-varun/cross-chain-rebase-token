// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RebaseToken is ERC20 {
    /*//////////////////////////////////////////////////////////////
			    ERRORS
    //////////////////////////////////////////////////////////////*/

    error RebaseToken__InterestRateShouldBeLessThanPrevious();

    /*//////////////////////////////////////////////////////////////
			    VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 constant PRISION_FACTOR = 1e10;
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

    constructor() ERC20("Rebase Token", "RBT") {}

    function setInterestRate(uint256 _interestRate) public {
        if (_interestRate > s_interestRate)
            revert RebaseToken__InterestRateShouldBeLessThanPrevious();
        s_interestRate = _interestRate;
        emit InterestRateUpdated(s_interestRate, _interestRate);
    }

    function mint(address _to, uint256 _amount) external {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    function balanceOf(address _user) public view override returns (uint256) {
        return
            (super.balanceOf(_user) *
                _calculateAccumulatedInterestSinceLastUpdate(_user)) /
            PRISION_FACTOR;
    }

    function _mintAccruedInterest(address _to) internal {
        s_userLastTimestamp[_to] = block.timestamp;
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
