// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {IRebaseToken} from "../src/interface/IRebaseToken.sol";
import {Vault} from "../src/Vault.sol";

/**
 * @title AdditionalCoverageTest
 * @notice Additional tests to achieve 100% code coverage for RebaseToken and Vault contracts
 * @dev This test suite focuses on covering the uncovered branches and lines identified in the coverage report
 */
contract AdditionalCoverageTest is Test {
    RebaseToken public rebaseToken;
    Vault public vault;
    MockFailingContract public failingContract;

    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    uint256 public constant INTEREST_RATE = 5e18;

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        failingContract = new MockFailingContract();
        rebaseToken.grantMintAndBurnRole(address(vault));
        rebaseToken.grantMintAndBurnRole(owner);
        vm.stopPrank();
        
        // Fund the vault with ETH
        vm.deal(owner, 100 ether);
        vm.prank(owner);
        (bool success, ) = payable(address(vault)).call{value: 100 ether}("");
        require(success, "Failed to fund vault");
    }

    /**
     * @notice Test transferFrom with type(uint256).max amount
     * @dev Covers line 197 in RebaseToken.sol: _amount = balanceOf(_sender);
     */
    function testTransferFromWithMaxAmount() public {
        // Setup: mint tokens to user1
        vm.prank(owner);
        rebaseToken.mint(user1, 1000e18, INTEREST_RATE);
        
        // Setup: user1 approves user2 to spend max amount
        vm.prank(user1);
        rebaseToken.approve(user2, type(uint256).max);
        
        uint256 user1Balance = rebaseToken.balanceOf(user1);
        uint256 user2BalanceBefore = rebaseToken.balanceOf(user2);
        
        // Execute: user2 transfers max amount from user1
        vm.prank(user2);
        rebaseToken.transferFrom(user1, user2, type(uint256).max);
        
        // Verify: user1 has 0 balance, user2 has all tokens
        assertEq(rebaseToken.balanceOf(user1), 0);
        assertEq(rebaseToken.balanceOf(user2), user1Balance + user2BalanceBefore);
    }

    /**
     * @notice Test transfer with type(uint256).max amount
     * @dev Covers line 168 in RebaseToken.sol: _amount = balanceOf(msg.sender);
     */
    function testTransferWithMaxAmount() public {
        // Setup: mint tokens to user1
        vm.prank(owner);
        rebaseToken.mint(user1, 1000e18, INTEREST_RATE);
        
        uint256 user2BalanceBefore = rebaseToken.balanceOf(user2);
        
        // Execute: user1 transfers max amount to user2
        vm.prank(user1);
        bool success = rebaseToken.transfer(user2, type(uint256).max);
        
        // Verify: transfer succeeded and user1 has 0 balance, user2 has all tokens
        assertTrue(success);
        assertEq(rebaseToken.balanceOf(user1), 0);
        assertGt(rebaseToken.balanceOf(user2), user2BalanceBefore);
    }

    /**
     * @notice Test burn with type(uint256).max amount
     * @dev Covers line 145 in RebaseToken.sol: _amount = balanceOf(_from);
     */
    function testBurnWithMaxAmount() public {
        // Setup: mint tokens to user1
        vm.prank(owner);
        rebaseToken.mint(user1, 1000e18, INTEREST_RATE);
        
        uint256 user1Balance = rebaseToken.balanceOf(user1);
        user1Balance; // silence warning
        
        // Execute: burn max amount from user1
        vm.prank(owner);
        rebaseToken.burn(user1, type(uint256).max);
        
        // Verify: user1 has 0 balance
        assertEq(rebaseToken.balanceOf(user1), 0);
    }

    /**
     * @notice Test Vault.getCurrentInterestRate function
     * @dev Covers line 142 in Vault.sol: return i_rebaseToken.getInterestRate();
     */
    function testVaultGetCurrentInterestRate() public {
        // Execute: call getCurrentInterestRate
        uint256 currentRate = vault.getCurrentInterestRate();
        
        // Verify: should return the same as rebaseToken.getInterestRate()
        assertEq(currentRate, rebaseToken.getInterestRate());
        assertEq(currentRate, INTEREST_RATE);
        
        // Test after changing interest rate
        vm.prank(owner);
        rebaseToken.setInterestRate(3e18);
        
        uint256 newRate = vault.getCurrentInterestRate();
        assertEq(newRate, rebaseToken.getInterestRate());
        assertEq(newRate, 3e18);
    }

    /**
     * @notice Test vault redeem failure when ETH transfer fails
     * @dev Covers line 117 in Vault.sol: revert Vault__RedeemFailed();
     */
    function testVaultRedeemFailure() public {
        // Setup: deploy a failing contract that has tokens but can't receive ETH
        MockFailingContract failingReceiver = new MockFailingContract();
        
        // Mint tokens to the failing contract
        vm.prank(owner);
        rebaseToken.mint(address(failingReceiver), 1000e18, INTEREST_RATE);
        
        // Execute: try to redeem from the failing contract
        vm.prank(address(failingReceiver));
        vm.expectRevert(Vault.Vault__RedeemFailed.selector);
        vault.redeem(1000e18);
    }

    /**
     * @notice Test comprehensive scenario with interest accrual and max transfers
     * @dev Additional test to ensure robustness of max amount transfers with interest
     */
    function testMaxTransferWithInterestAccrual() public {
        // Setup: mint tokens to user1
        vm.prank(owner);
        rebaseToken.mint(user1, 1000e18, INTEREST_RATE);
        
        // Wait for interest to accrue
        vm.warp(block.timestamp + 365 days);
        
        uint256 user1BalanceWithInterest = rebaseToken.balanceOf(user1);
        assertGt(user1BalanceWithInterest, 1000e18); // Should have accrued interest
        
        // Transfer max amount
        vm.prank(user1);
        rebaseToken.transfer(user2, type(uint256).max);
        
        // Verify: all balance transferred including accrued interest
        assertEq(rebaseToken.balanceOf(user1), 0);
        assertEq(rebaseToken.balanceOf(user2), user1BalanceWithInterest);
    }

    /**
     * @notice Test burn max amount with interest accrual
     * @dev Ensures max burn works correctly with accrued interest
     */
    function testBurnMaxWithInterestAccrual() public {
        // Setup: mint tokens to user1
        vm.prank(owner);
        rebaseToken.mint(user1, 1000e18, INTEREST_RATE);
        
        // Wait for interest to accrue
        vm.warp(block.timestamp + 365 days);
        
        uint256 user1BalanceWithInterest = rebaseToken.balanceOf(user1);
        assertGt(user1BalanceWithInterest, 1000e18); // Should have accrued interest
        
        // Burn max amount
        vm.prank(owner);
        rebaseToken.burn(user1, type(uint256).max);
        
        // Verify: all balance burned including accrued interest
        assertEq(rebaseToken.balanceOf(user1), 0);
    }

    /**
     * @notice Test transferFrom max amount with approval and interest
     * @dev Comprehensive test for transferFrom with max amount including interest scenarios
     */
    function testTransferFromMaxWithApprovalAndInterest() public {
        // Setup: mint tokens to user1
        vm.prank(owner);
        rebaseToken.mint(user1, 1000e18, INTEREST_RATE);
        
        // Wait for some interest to accrue
        vm.warp(block.timestamp + 100 days);
        
        // user1 approves user2 for max amount
        vm.prank(user1);
        rebaseToken.approve(user2, type(uint256).max);
        
        uint256 user1BalanceWithInterest = rebaseToken.balanceOf(user1);
        
        // user2 transfers all of user1's tokens (including interest) to themselves
        vm.prank(user2);
        rebaseToken.transferFrom(user1, user2, type(uint256).max);
        
        // Verify: all balance transferred
        assertEq(rebaseToken.balanceOf(user1), 0);
        assertEq(rebaseToken.balanceOf(user2), user1BalanceWithInterest);
        
        // Verify: user2 inherited user1's interest rate
        assertEq(rebaseToken.getUserInterestRate(user2), INTEREST_RATE);
    }

    /**
     * @notice Test edge cases for zero balance scenarios
     * @dev Additional edge case testing for better coverage
     */
    function testZeroBalanceEdgeCases() public view {
        // Test balanceOf with zero balance returns 0
        assertEq(rebaseToken.balanceOf(user1), 0);
        
        // Test getUserInterestRate for user with no tokens
        assertEq(rebaseToken.getUserInterestRate(user1), 0);
        
        // Test principleBalanceOf for user with no tokens
        assertEq(rebaseToken.principleBalanceOf(user1), 0);
    }

    /**
     * @notice Test interest calculations with different rates
     * @dev Verify interest calculations work correctly with various rates
     */
    function testInterestCalculationsWithDifferentRates() public {
        // Mint tokens with different interest rates to different users
        vm.startPrank(owner);
        rebaseToken.mint(user1, 1000e18, 3e18); // 3% interest
        rebaseToken.mint(user2, 1000e18, 7e18); // 7% interest
        vm.stopPrank();
        
        // Advance time
        vm.warp(block.timestamp + 365 days);
        
        // Check balances after interest accrual
        uint256 user1Balance = rebaseToken.balanceOf(user1);
        uint256 user2Balance = rebaseToken.balanceOf(user2);
        
        // user2 should have more interest due to higher rate
        assertTrue(user2Balance > user1Balance);
        
        // Both should have more than their initial 1000e18
        assertGt(user1Balance, 1000e18);
        assertGt(user2Balance, 1000e18);
    }

    /**
     * @notice Test vault deposit and redeem edge cases
     * @dev Additional vault testing for edge cases
     */
    function testVaultEdgeCases() public {
        // Test deposit with 0 ETH (should work but mint 0 tokens)
        vm.prank(user1);
        vault.deposit{value: 0}();
        assertEq(rebaseToken.balanceOf(user1), 0);
        
        // Test redeem with 0 amount
        vm.prank(user1);
        vault.redeem(0);
        assertEq(rebaseToken.balanceOf(user1), 0);
    }
}

/**
 * @title MockFailingContract
 * @notice A contract that cannot receive ETH (for testing redeem failure)
 * @dev This contract deliberately fails when receiving ETH to test error handling
 */
contract MockFailingContract {
    // This contract has no receive() or fallback() function
    // So it cannot receive ETH transfers, which will cause vault.redeem() to fail
    
    constructor() payable {}
    
    // Explicitly reject ETH transfers
    receive() external payable {
        revert("Cannot receive ETH");
    }
}
