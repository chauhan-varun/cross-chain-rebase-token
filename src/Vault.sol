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

    function deposit() external payable {
        i_rebaseToken.mint(
            msg.sender,
            msg.value,
            i_rebaseToken.getInterestRate()
        );
        emit Deposit(msg.sender, msg.value);
    }

    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        i_rebaseToken.burn(msg.sender, _amount);
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
