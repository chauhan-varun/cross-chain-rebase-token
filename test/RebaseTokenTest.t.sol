// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {IRebaseToken} from "../src/interface/IRebaseToken.sol";
import {Vault} from "../src/Vault.sol";

contract RebaseTokenTest is Test {
    RebaseToken public rebaseToken;
    Vault public vault;

    address public user = makeAddr("user");
    address public owner = makeAddr("owner");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        (bool success, ) = payable(address(vault)).call{value: 1 ether}("");
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 amount) public {
        // send some rewards to the vault using the receive function
        payable(address(vault)).call{value: amount}("");
    }

    function testLinearDeposite(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();

        uint256 initialBalance = rebaseToken.balanceOf(user);
        assertEq(initialBalance, amount);

        vm.warp(block.timestamp + 1 hours);
        uint256 intermidiateBalance = rebaseToken.balanceOf(user);
        assertGt(intermidiateBalance, initialBalance);

        vm.warp(block.timestamp + 1 hours);
        uint256 finalBalance = rebaseToken.balanceOf(user);
        assertGt(finalBalance, intermidiateBalance);

        assertApproxEqAbs(
            intermidiateBalance - initialBalance,
            finalBalance - intermidiateBalance,
            1
        );
        vm.stopPrank();
    }
}
