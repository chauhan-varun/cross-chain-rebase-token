// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRebaseToken} from "src/interface/IRebaseToken.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {RebaseTokenPool} from "src/RebaseTokenPool.sol";
import {Vault} from "src/Vault.sol";
import {Test, console2} from "forge-std/Test.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";

contract CrossChainTest is Test {
    uint256 public sepoliaFork;
    uint256 public arbSepolia;
    CCIPLocalSimulatorFork public simulator;

    address owner = makeAddr("owner");

    RebaseToken sepoliaToken;
    RebaseToken arbSepoliaToken;
    Vault vault;

    RebaseTokenPool sepoliaPool;
    RebaseTokenPool arbSepoliaPool;

    Register.NetworkDetails sepoliaDetails;
    Register.NetworkDetails arbSepoliaDetails;

    function setUp() external {
        sepoliaFork = vm.createSelectFork("sepolia");
        arbSepolia = vm.createSelectFork("arb-sepolia");

        simulator = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(simulator));

        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(sepoliaToken)));
        sepoliaPool = new RebaseTokenPool(
            IRebaseToken(address(sepoliaToken)),
            address(vault)
        );
        vm.stopPrank();

        vm.startPrank(owner);
        arbSepoliaToken = new RebaseToken();
        arbSepoliaPool = new RebaseTokenPool(
            IRebaseToken(address(arbSepoliaToken)),
            address(vault)
        );
        vm.stopPrank();
    }
}
