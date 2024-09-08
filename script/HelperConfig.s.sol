// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script{
    struct NetworkConfig{
        address vrfCoordinator;
        uint256 subscriptionId;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        address link;
        uint16 numOfRequestConfirmations;
    }

    NetworkConfig public activeNetworkConfig; 

    event HelperConfig__CreatedMockVRFCoordinator(address vrfCoordinator);

    constructor(){
        if(block.chainid == 31337){
            activeNetworkConfig = getOrCreateNetworkAnvilNetworkConfig();
        } else if(block.chainid == 11155111){
            activeNetworkConfig = getSepoliaNetworkConfig();
        } else if(block.chainid == 42161){
            activeNetworkConfig = getArbitrumNetworkConfig();
        } else{
            revert("Unsupported network");
        }
        
    }

    function getOrCreateNetworkAnvilNetworkConfig() public returns (NetworkConfig memory anvilNetworkConfig){
        if(activeNetworkConfig.vrfCoordinator != address(0)){
            return activeNetworkConfig;
        }

        uint96 baseFee = 100 gwei;
        uint96 gasPriceLink = 1 gwei;
        int256 weiPerUnitLink = 1e18;

        // mock the link token

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock = new VRFCoordinatorV2_5Mock(
            baseFee, 
            gasPriceLink,
            weiPerUnitLink);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        emit HelperConfig__CreatedMockVRFCoordinator(
            address(vrfCoordinatorV2_5Mock)
        );

        return 
            anvilNetworkConfig = NetworkConfig({
                subscriptionId: 0,
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                callbackGasLimit: 500_000,
                vrfCoordinator: address(vrfCoordinatorV2_5Mock),
                link: address(linkToken),
                numOfRequestConfirmations:3
            });
    }

    function getSepoliaNetworkConfig() 
        public 
        pure
        returns (NetworkConfig memory){
        return 
            NetworkConfig({
                vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625, // address from sepolia
                subscriptionId: 92073824763098362347847011459742641056611387669887634843061674849498969713844, // https://vrf.chain.link/sepolia
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                callbackGasLimit: 1_000_000,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                numOfRequestConfirmations: 3
        });
    }

    function getArbitrumNetworkConfig()
        public
        pure
        returns (NetworkConfig memory)
    {
        return
            NetworkConfig({
                vrfCoordinator: 0x50d47e4142598E3411aA864e08a44284e471AC6f,
                subscriptionId: 92073824763098362347847011459742641056611387669887634843061674849498969713844,
                gasLane:  0x027f94ff1465b3525f9fc03e9ff7d6d2c0953482246dd6ae07570c45d6631414,
                callbackGasLimit: 500_000,
                link: 0xb1D4538B4571d411F07960EF2838Ce337FE1E80E,
                numOfRequestConfirmations: 1
            });
    }
}