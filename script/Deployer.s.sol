// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interface/IRebaseToken.sol";
import {RebaseToken} from "../src/RebaseToken.sol";

import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";

contract TokenAndPoolDeployer is Script {
    function run(
        address _rebaseToken
    ) public returns (RebaseToken rebaseToken, RebaseTokenPool pool) {
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork
            .getNetworkDetails(block.chainid);
        vm.startBroadcast();
        rebaseToken = new RebaseToken();
        pool = new RebaseTokenPool(
            IERC20(_rebaseToken),
            new address[](0),
            networkDetails.rmnProxyAddress,
            networkDetails.routerAddress
        );
        IRebaseToken(_rebaseToken).grantMintAndBurnRole(address(pool));

        // Configure token administration for CCIP on Sepolia
        RegistryModuleOwnerCustom registryModuleOwnerCustomSepolia = RegistryModuleOwnerCustom(
                networkDetails.registryModuleOwnerCustomAddress
            );
        registryModuleOwnerCustomSepolia.registerAdminViaOwner(
            address(rebaseToken)
        );

        // Accept admin role in token registry
        TokenAdminRegistry tokenAdminRegistrySepolia = TokenAdminRegistry(
            networkDetails.tokenAdminRegistryAddress
        );
        tokenAdminRegistrySepolia.acceptAdminRole(address(rebaseToken));

        // Link token to pool in the token admin registry
        tokenAdminRegistrySepolia.setPool(address(rebaseToken), address(pool));
        vm.stopBroadcast();
    }
}

contract VaultDeployer is Script {
    function run(address _rebaseToken) public returns (Vault vault) {
        vm.startBroadcast();
        vault = new Vault(IRebaseToken(_rebaseToken));
        IRebaseToken(_rebaseToken).grantMintAndBurnRole(address(vault));
        vm.stopBroadcast();
    }
}
