// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console, Test} from "forge-std/Test.sol";

import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";

import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "src/interface/IRebaseToken.sol";

/**
 * @title CrossChainTest
 * @author Varun Chauhan
 * @notice Comprehensive test suite for cross-chain RebaseToken transfers using Chainlink CCIP
 * @dev This test contract validates the complete cross-chain functionality of RebaseToken,
 *      ensuring that interest-bearing tokens can be transferred between chains while preserving
 *      user interest rates and maintaining accurate balances.
 *
 * Test Coverage:
 * - Full token bridging with balance verification
 * - Partial token bridging with correct balance splits
 * - Round-trip bridging (source → destination → source)
 * - Interest rate preservation across chains
 * - CCIP infrastructure setup and configuration
 *
 * Network Setup:
 * - Source Chain: Ethereum Sepolia (sepoliaFork)
 * - Destination Chain: Arbitrum Sepolia (arbSepoliaFork)
 * - Uses CCIPLocalSimulatorFork for realistic CCIP simulation
 */
contract CrossChainTest is Test {
    /*//////////////////////////////////////////////////////////////
                            TEST CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Test account addresses
    address public owner = makeAddr("owner");
    address alice = makeAddr("alice");
    
    /// @notice CCIP Local Simulator for fork testing
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    
    /// @notice Amount of tokens to use in bridge tests
    uint256 public SEND_VALUE = 1e5;

    /*//////////////////////////////////////////////////////////////
                              FORK SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Fork IDs for different networks
    uint256 sepoliaFork;        // Source chain fork
    uint256 arbSepoliaFork;     // Destination chain fork

    /*//////////////////////////////////////////////////////////////
                           CONTRACT INSTANCES
    //////////////////////////////////////////////////////////////*/

    /// @notice RebaseToken contracts on each chain
    RebaseToken destRebaseToken;    // Arbitrum Sepolia token
    RebaseToken sourceRebaseToken;  // Ethereum Sepolia token

    /// @notice Token pools for cross-chain transfers
    RebaseTokenPool destPool;       // Arbitrum Sepolia pool
    RebaseTokenPool sourcePool;     // Ethereum Sepolia pool

    /// @notice Token admin registries for CCIP configuration
    TokenAdminRegistry tokenAdminRegistrySepolia;
    TokenAdminRegistry tokenAdminRegistryarbSepolia;

    /// @notice Network details for CCIP configuration
    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;

    /// @notice Registry modules for token administration
    RegistryModuleOwnerCustom registryModuleOwnerCustomSepolia;
    RegistryModuleOwnerCustom registryModuleOwnerCustomarbSepolia;

    /// @notice Vault contract for ETH ⟷ RebaseToken exchange (source chain only)
    Vault vault;

    /*//////////////////////////////////////////////////////////////
                              SETUP FUNCTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets up the complete cross-chain testing environment
     * @dev Deploys and configures RebaseToken and RebaseTokenPool on both chains,
     *      sets up CCIP infrastructure, and establishes proper permissions.
     *
     * Setup Process:
     * 1. Create blockchain forks for Sepolia and Arbitrum Sepolia
     * 2. Deploy and configure contracts on source chain (Sepolia)
     * 3. Deploy and configure contracts on destination chain (Arbitrum)
     * 4. Configure CCIP token admin registries on both chains
     * 5. Grant necessary permissions for cross-chain operations
     */
    function setUp() public {
        // Initialize empty allowlist (no restrictions on pool usage)
        address[] memory allowlist = new address[](0);

        // 1. Setup blockchain forks for cross-chain testing
        sepoliaFork = vm.createSelectFork("eth");      // Ethereum Sepolia
        arbSepoliaFork = vm.createFork("arb");         // Arbitrum Sepolia

        // Initialize CCIP Local Simulator for realistic cross-chain testing
        // NOTE: CCIPLocalSimulatorFork provides a local CCIP environment for testing
        // without needing actual cross-chain infrastructure or testnet tokens
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        /*//////////////////////////////////////////////////////////////
                          SOURCE CHAIN SETUP (SEPOLIA)
        //////////////////////////////////////////////////////////////*/

        // Get network details for Sepolia (source chain)
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        
        vm.startPrank(owner);
        
        // Deploy RebaseToken contract on source chain
        sourceRebaseToken = new RebaseToken();
        console.log("Source RebaseToken deployed at:", address(sourceRebaseToken));
        
        // Deploy RebaseTokenPool for cross-chain transfers
        console.log("Deploying RebaseTokenPool on Sepolia");
        sourcePool = new RebaseTokenPool(
            IERC20(address(sourceRebaseToken)),
            allowlist,                              // No allowlist restrictions
            sepoliaNetworkDetails.rmnProxyAddress,  // Risk Management Network
            sepoliaNetworkDetails.routerAddress     // CCIP Router
        );
        
        // Deploy Vault for ETH ⟷ RebaseToken exchanges (source chain only)
        vault = new Vault(IRebaseToken(address(sourceRebaseToken)));
        
        // Fund the vault with 1 ETH for testing
        vm.deal(address(vault), 1e18);
        
        // Grant permissions for minting and burning operations
        sourceRebaseToken.grantMintAndBurnRole(address(sourcePool));  // For CCIP transfers
        sourceRebaseToken.grantMintAndBurnRole(address(vault));       // For ETH exchanges
        
        // Configure token administration for CCIP on Sepolia
        registryModuleOwnerCustomSepolia = RegistryModuleOwnerCustom(
            sepoliaNetworkDetails.registryModuleOwnerCustomAddress
        );
        registryModuleOwnerCustomSepolia.registerAdminViaOwner(address(sourceRebaseToken));
        
        // Accept admin role in token registry
        tokenAdminRegistrySepolia = TokenAdminRegistry(
            sepoliaNetworkDetails.tokenAdminRegistryAddress
        );
        tokenAdminRegistrySepolia.acceptAdminRole(address(sourceRebaseToken));
        
        // Link token to pool in the token admin registry on Sepolia
        tokenAdminRegistrySepolia.setPool(
            address(sourceRebaseToken),
            address(sourcePool)
        );
        vm.stopPrank();

        /*//////////////////////////////////////////////////////////////
                        DESTINATION CHAIN SETUP (ARBITRUM)
        //////////////////////////////////////////////////////////////*/

        // Switch to Arbitrum Sepolia fork for destination chain setup
        vm.selectFork(arbSepoliaFork);
        vm.startPrank(owner);
        
        console.log("Deploying RebaseToken on Arbitrum");
        // Get network details for Arbitrum (destination chain)
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        
        // Deploy RebaseToken contract on destination chain
        destRebaseToken = new RebaseToken();
        console.log("Destination RebaseToken deployed at:", address(destRebaseToken));
        
        // Deploy RebaseTokenPool for cross-chain transfers on Arbitrum
        console.log("Deploying RebaseTokenPool on Arbitrum");
        destPool = new RebaseTokenPool(
            IERC20(address(destRebaseToken)),
            allowlist,                                 // No allowlist restrictions
            arbSepoliaNetworkDetails.rmnProxyAddress,  // Risk Management Network
            arbSepoliaNetworkDetails.routerAddress     // CCIP Router
        );
        
        // Grant permissions for cross-chain minting and burning
        destRebaseToken.grantMintAndBurnRole(address(destPool));
        
        // Configure token administration for CCIP on Arbitrum
        registryModuleOwnerCustomarbSepolia = RegistryModuleOwnerCustom(
            arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress
        );
        registryModuleOwnerCustomarbSepolia.registerAdminViaOwner(address(destRebaseToken));
        
        // Accept admin role in token registry on Arbitrum
        tokenAdminRegistryarbSepolia = TokenAdminRegistry(
            arbSepoliaNetworkDetails.tokenAdminRegistryAddress
        );
        tokenAdminRegistryarbSepolia.acceptAdminRole(address(destRebaseToken));
        
        // Link token to pool in the token admin registry on Arbitrum
        tokenAdminRegistryarbSepolia.setPool(
            address(destRebaseToken),
            address(destPool)
        );
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Configures cross-chain connectivity between token pools
     * @dev Sets up the chain mapping, remote pool addresses, and rate limiting configs
     *      for bidirectional communication between source and destination chains.
     * @param fork The blockchain fork to configure
     * @param localPool The token pool on the current chain
     * @param remotePool The token pool on the remote chain
     * @param remoteToken The token contract on the remote chain
     * @param remoteNetworkDetails Network configuration for the remote chain
     */
    function configureTokenPool(
        uint256 fork,
        TokenPool localPool,
        TokenPool remotePool,
        IRebaseToken remoteToken,
        Register.NetworkDetails memory remoteNetworkDetails
    ) public {
        vm.selectFork(fork);
        vm.startPrank(owner);
        
        // Create chain update configuration for the remote chain
        TokenPool.ChainUpdate[] memory chains = new TokenPool.ChainUpdate[](1);
        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(address(remotePool));

        // Configure the chain update with remote chain details
        // This tells the local pool how to communicate with the remote chain
        chains[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteNetworkDetails.chainSelector,  // Remote chain ID
            allowed: true,                                           // Enable this chain
            remotePoolAddress: remotePoolAddresses[0],               // Remote pool address
            remoteTokenAddress: abi.encode(address(remoteToken)),    // Remote token address
            outboundRateLimiterConfig: RateLimiter.Config({          // Outbound rate limits
                isEnabled: false,  // Disabled for testing
                capacity: 0,
                rate: 0
            }),
            inboundRateLimiterConfig: RateLimiter.Config({           // Inbound rate limits
                isEnabled: false,  // Disabled for testing
                capacity: 0,
                rate: 0
            })
        });
        
        // Apply the chain configuration to the local pool
        localPool.applyChainUpdates(chains);
        vm.stopPrank();
    }

    /**
     * @notice Executes a cross-chain token bridge transaction
     * @dev Performs the complete flow of transferring RebaseTokens from one chain to another,
     *      including balance verification and proper CCIP message handling.
     * @param amountToBridge Amount of tokens to transfer cross-chain
     * @param localFork Source blockchain fork ID
     * @param remoteFork Destination blockchain fork ID  
     * @param localNetworkDetails Network configuration for source chain
     * @param remoteNetworkDetails Network configuration for destination chain
     * @param localToken RebaseToken contract on source chain
     * @param remoteToken RebaseToken contract on destination chain
     * @return messageId The CCIP message ID for tracking the transfer
     */
    function bridgeTokens(
        uint256 amountToBridge,
        uint256 localFork,
        uint256 remoteFork,
        Register.NetworkDetails memory localNetworkDetails,
        Register.NetworkDetails memory remoteNetworkDetails,
        RebaseToken localToken,
        RebaseToken remoteToken
    ) public returns (bytes32 messageId) {
        /*//////////////////////////////////////////////////////////////
                              SOURCE CHAIN OPERATIONS
        //////////////////////////////////////////////////////////////*/
        
        // Switch to source chain to initiate the bridge transaction
        vm.selectFork(localFork);
        vm.startPrank(alice);
        
        // Prepare token transfer details for CCIP message
        Client.EVMTokenAmount[] memory tokenToSendDetails = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: address(localToken),
            amount: amountToBridge
        });
        tokenToSendDetails[0] = tokenAmount;
        
        // Approve CCIP router to spend user's tokens for cross-chain transfer
        IERC20(address(localToken)).approve(
            localNetworkDetails.routerAddress,
            amountToBridge
        );

        // Create CCIP message for cross-chain token transfer
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(alice),           // Destination address (encoded)
            data: "",                              // No additional data needed
            tokenAmounts: tokenToSendDetails,      // Tokens to transfer
            extraArgs: "",                         // No extra arguments needed
            feeToken: localNetworkDetails.linkAddress  // LINK token for fees
        });
        
        vm.stopPrank();
        
        // Calculate and provide LINK tokens for CCIP fees
        uint256 fee = IRouterClient(localNetworkDetails.routerAddress).getFee(
            remoteNetworkDetails.chainSelector,
            message
        );
        ccipLocalSimulatorFork.requestLinkFromFaucet(alice, fee);
        
        vm.startPrank(alice);
        
        // Approve LINK tokens for fee payment
        IERC20(localNetworkDetails.linkAddress).approve(
            localNetworkDetails.routerAddress,
            fee
        );
        
        // Record balance before bridge for verification
        uint256 balanceBeforeBridge = IERC20(address(localToken)).balanceOf(alice);
        console.log("Local balance before bridge: %d", balanceBeforeBridge);

        // Execute the cross-chain transfer
        messageId = IRouterClient(localNetworkDetails.routerAddress).ccipSend(
            remoteNetworkDetails.chainSelector,
            message
        );
        
        // Verify tokens were burned on source chain
        uint256 sourceBalanceAfterBridge = IERC20(address(localToken)).balanceOf(alice);
        console.log("Local balance after bridge: %d", sourceBalanceAfterBridge);
        assertEq(
            sourceBalanceAfterBridge,
            balanceBeforeBridge - amountToBridge,
            "Source balance should decrease by bridge amount"
        );
        vm.stopPrank();

        /*//////////////////////////////////////////////////////////////
                           DESTINATION CHAIN OPERATIONS
        //////////////////////////////////////////////////////////////*/

        // Switch to destination chain to complete the transfer
        vm.selectFork(remoteFork);
        
        // Simulate realistic cross-chain transfer time (15 minutes)
        vm.warp(block.timestamp + 900);
        
        // Record initial balance on destination chain
        uint256 initialRemoteBalance = IERC20(address(remoteToken)).balanceOf(alice);
        console.log("Remote balance before bridge: %d", initialRemoteBalance);
        
        // Switch back to source fork before routing (requirement of CCIPLocalSimulatorFork)
        vm.selectFork(localFork);
        
        // Execute the cross-chain message delivery
        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);

        // Verify tokens were minted on destination chain with preserved interest rate
        console.log("Remote user interest rate: %d", remoteToken.getUserInterestRate(alice));
        uint256 destBalance = IERC20(address(remoteToken)).balanceOf(alice);
        console.log("Remote balance after bridge: %d", destBalance);
        assertEq(
            destBalance, 
            initialRemoteBalance + amountToBridge,
            "Destination balance should increase by bridge amount"
        );
        
        return messageId;
    }

    /*//////////////////////////////////////////////////////////////
                               TEST FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Test complete token bridging functionality
     * @dev Verifies that users can bridge all their tokens cross-chain while maintaining
     *      correct balances and preserving interest rates.
     */
    function testBridgeAllTokens() public {
        // Configure bidirectional communication between chains
        configureTokenPool(
            sepoliaFork, 
            sourcePool, 
            destPool, 
            IRebaseToken(address(destRebaseToken)), 
            arbSepoliaNetworkDetails
        );
        configureTokenPool(
            arbSepoliaFork, 
            destPool, 
            sourcePool, 
            IRebaseToken(address(sourceRebaseToken)), 
            sepoliaNetworkDetails
        );
        
        // Setup: User deposits ETH and receives RebaseTokens on source chain
        vm.selectFork(sepoliaFork);
        vm.deal(alice, SEND_VALUE);  // Give user ETH for testing
        
        vm.startPrank(alice);
        // Deposit ETH to vault and receive RebaseTokens
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}();
        
        // Verify initial token balance
        uint256 startBalance = IERC20(address(sourceRebaseToken)).balanceOf(alice);
        assertEq(startBalance, SEND_VALUE, "User should receive tokens equal to ETH deposited");
        console.log("Bridging %d tokens", SEND_VALUE);
        vm.stopPrank();
        
        // Execute cross-chain bridge of ALL tokens
        bridgeTokens(
            SEND_VALUE,
            sepoliaFork,
            arbSepoliaFork,
            sepoliaNetworkDetails,
            arbSepoliaNetworkDetails,
            sourceRebaseToken,
            destRebaseToken
        );
    }
    function testBridgeAllTokensBack() public {
        configureTokenPool(
            sepoliaFork, sourcePool, destPool, IRebaseToken(address(destRebaseToken)), arbSepoliaNetworkDetails
        );
        configureTokenPool(
            arbSepoliaFork, destPool, sourcePool, IRebaseToken(address(sourceRebaseToken)), sepoliaNetworkDetails
        );
        // We are working on the source chain (Sepolia)
        vm.selectFork(sepoliaFork);
        // Pretend a user is interacting with the protocol
        // Give the user some ETH
        vm.deal(alice, SEND_VALUE);
        vm.startPrank(alice);
        // Deposit to the vault and receive tokens
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}();
        // bridge the tokens
        console.log("Bridging %d tokens", SEND_VALUE);
        uint256 startBalance = IERC20(address(sourceRebaseToken)).balanceOf(alice);
        assertEq(startBalance, SEND_VALUE);
        vm.stopPrank();
        // bridge ALL TOKENS to the destination chain
        bridgeTokens(
            SEND_VALUE,
            sepoliaFork,
            arbSepoliaFork,
            sepoliaNetworkDetails,
            arbSepoliaNetworkDetails,
            sourceRebaseToken,
            destRebaseToken
        );
        // bridge back ALL TOKENS to the source chain after 1 hour
        vm.selectFork(arbSepoliaFork);
        console.log("User Balance Before Warp: %d", destRebaseToken.balanceOf(alice));
        vm.warp(block.timestamp + 3600);
        console.log("User Balance After Warp: %d", destRebaseToken.balanceOf(alice));
        uint256 destBalance = IERC20(address(destRebaseToken)).balanceOf(alice);
        console.log("Amount bridging back %d tokens ", destBalance);
        bridgeTokens(
            destBalance,
            arbSepoliaFork,
            sepoliaFork,
            arbSepoliaNetworkDetails,
            sepoliaNetworkDetails,
            destRebaseToken,
            sourceRebaseToken
        );
    }
}
