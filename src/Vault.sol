// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRebaseToken} from "./interface/IRebaseToken.sol";

contract Vault {
    IRebaseToken private immutable i_rebaseToken;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Deposit(address indexed from, uint256 amount);
    event Redeem(address indexed from, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error Vault__RedeemFailed();

    constructor(IRebaseToken _i_rebaseToken) {
        i_rebaseToken = _i_rebaseToken;
    }

    receive() external payable {}

    function deposit(address _to, uint256 _amount) external {
        i_rebaseToken.mint(_to, _amount);
        emit Deposit(_to, _amount);
    }

    function redeem(address _from, uint256 _amount) external {
        i_rebaseToken.burn(_from, _amount);
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                                 GETTERS
    //////////////////////////////////////////////////////////////*/
    function getRebaseTokenAddress() public view returns (address) {
        return address(i_rebaseToken);
    }
}
