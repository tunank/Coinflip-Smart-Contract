// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {CreateSubscription, Fundsubscription, AddConsumer} from "./Interaction.s.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Script, console} from "forge-std/Script.sol";
import {CoinFlip} from "../src/CoinFlip.sol";

contract DeployCoinFlip is Script {
    uint256 constant MINIMUM_WAGER = 0.001 ether; // Change this to 0.0025. Post Testing

    function run() external returns (CoinFlip, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            address vrfCoordinator,
            uint256 subscriptionId,
            bytes32 gasLane,
            uint32 callbackGasLimit,
            address link,
            uint16 numOfRequestConfirmations
        ) = helperConfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            // Ideally only on Anvil (otherwise we can create)
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(
                vrfCoordinator
            );
            Fundsubscription fundSubscription = new Fundsubscription();
            fundSubscription.fundSubscription(
                vrfCoordinator,
                subscriptionId,
                link
            );
        }

        vm.startBroadcast();
        CoinFlip coinFlip = new CoinFlip(
            MINIMUM_WAGER,
            vrfCoordinator,
            subscriptionId,
            gasLane,
            callbackGasLimit,
            numOfRequestConfirmations
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(coinFlip),
            subscriptionId,
            vrfCoordinator
        );
        console.log("Deployer Address: ", address(this));
        return (coinFlip, helperConfig);
    }
}
