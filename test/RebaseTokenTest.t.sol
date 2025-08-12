// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {IRebaseToken} from "../src/interface/IRebaseToken.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Vault} from "../src/Vault.sol";

contract RebaseTokenTest is Test {
    RebaseToken public rebaseToken;
    Vault public vault;

    address public user = makeAddr("user");
    address public owner = makeAddr("owner");
    uint256 public constant INTEREST_RATE = 5e18;

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        (bool success, ) = payable(address(vault)).call{value: 1 ether}("");
        success;
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 amount) public {
        // send some rewards to the vault using the receive function
        (bool success, ) = payable(address(vault)).call{value: amount}("");
        success;
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

    function testRedeemStrightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        uint256 initialBalance = rebaseToken.balanceOf(user);
        assertEq(initialBalance, amount);
        vault.redeem(initialBalance);
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, amount);
        vm.stopPrank();
    }

    function testRedeemAfterSomeTime(uint256 amount, uint256 time) public {
        amount = bound(amount, 1e5, type(uint96).max);
        time = bound(time, 1000, type(uint96).max);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        vm.warp(block.timestamp + time);

        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(user);

        vm.deal(owner, balanceAfterSomeTime - amount);
        vm.prank(owner);
        addRewardsToVault(balanceAfterSomeTime - amount);

        vm.prank(user);
        vault.redeem(type(uint256).max);

        uint256 ethBalance = address(user).balance;
        assertGt(ethBalance, amount);
        assertEq(ethBalance, balanceAfterSomeTime);
        vm.stopPrank();
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e3, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e3);

        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
        uint256 initialUserBalance = rebaseToken.balanceOf(user);
        assertEq(initialUserBalance, amount);

        vm.prank(owner);
        rebaseToken.setInterestRate(4e18);

        address user2 = makeAddr("user2");
        uint256 initialUser2Balance = rebaseToken.balanceOf(user2);
        assertEq(initialUser2Balance, 0);

        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);
        uint256 finalUserBalance = rebaseToken.balanceOf(user);
        uint256 finalUser2Balance = rebaseToken.balanceOf(user2);

        vm.warp(block.timestamp + 1 days);
        uint256 userBalanceAfterWarp = rebaseToken.balanceOf(user);
        uint256 userTwoBalanceAfterWarp = rebaseToken.balanceOf(user2);

        assertEq(finalUserBalance, initialUserBalance - amountToSend);
        assertEq(finalUser2Balance, amountToSend);

        assertEq(rebaseToken.getUserInterestRate(user), INTEREST_RATE);
        assertEq(rebaseToken.getUserInterestRate(user2), INTEREST_RATE);

        assertGt(userBalanceAfterWarp, finalUserBalance);
        assertGt(userTwoBalanceAfterWarp, finalUser2Balance);
    }

    function testUserCantSetInterestRate(uint256 newInterestRate) public {
        vm.prank(user);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testUserCantMintAndBurn() public {
        vm.deal(user, 1e5);
        vm.startPrank(user);

        vm.expectPartialRevert(
            IAccessControl.AccessControlUnauthorizedAccount.selector
        );
        rebaseToken.mint(user, 1e5, 1e4);

        vm.expectPartialRevert(
            IAccessControl.AccessControlUnauthorizedAccount.selector
        );
        rebaseToken.burn(user, 1e5);

        vm.stopPrank();
    }

    function testGetPrincipleAmount(uint256 amount) public {
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.principleBalanceOf(user), amount);

        vm.warp(block.timestamp + 1 days);
        assertEq(rebaseToken.principleBalanceOf(user), amount);
    }

    function testGetRebaseTokenAddress() public view {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 oldInterestRate = rebaseToken.getInterestRate();
        newInterestRate = bound(
            newInterestRate,
            oldInterestRate + 1,
            type(uint96).max
        );
        vm.prank(owner);
        vm.expectPartialRevert(
            RebaseToken
                .RebaseToken__InterestRateShouldBeLessThanPrevious
                .selector
        );
        rebaseToken.setInterestRate(newInterestRate);
        assertEq(rebaseToken.getInterestRate(), oldInterestRate);
    }
}
