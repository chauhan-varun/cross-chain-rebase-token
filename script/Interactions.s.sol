// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";

contract DepositScript is Script {
    // Constant value to send during deposit (0.01 ETH)
    uint256 private constant SEND_VALUE = 0.01 ether;

    /**
     * @notice Deposits funds to the specified vault.
     * @param vault The address of the vault contract.
     */
    function depositFunds(address vault) public payable {
        Vault(payable(vault)).deposit{value: SEND_VALUE}();
    }

    /**
     * @notice Runs the deposit script.
     * @param vault The address of the vault contract.
     */
    function run(address vault) external payable {
        depositFunds(vault);
    }
}

contract RedeemScript is Script {
    function redeemFunds(address vault) public {
        // Redeem from the vault
        Vault(payable(vault)).redeem(type(uint256).max);
    }

    function run(address vault) external {
        redeemFunds(vault);
    }
}
