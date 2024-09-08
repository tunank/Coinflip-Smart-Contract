// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
//lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol
contract CreateSubscription is Script{
    function createSubscription(address vrfCoordinatorV2) public returns(uint256){
        vm.startBroadcast();
            uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinatorV2).createSubscription(); 
        vm.stopBroadcast();

        console.log("Creating Subscripton on Chain: ", block.chainid);
        console.log("Created SubId: ", subId);
        console.log("Update SubscriptionId in HelperConfig.s.sol");
        return subId;
    }
}

contract Fundsubscription is Script{
    uint96 constant SUBSCRIPTION_FUND_AMOUNT = 5 ether;

    function fundSubscription(address vrfCoordinatorV2, uint256 subId, address link) public{
        console.log("Funding Subscription: ", subId);
        console.log("On ChainId: ", block.chainid);
        console.log("Using vrfCoordinatorV2: ", vrfCoordinatorV2);
        if(block.chainid == 31337){
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2).fundSubscription(
                subId,
                SUBSCRIPTION_FUND_AMOUNT
            );
            vm.stopBroadcast();
        }
        else{
            console.log("Funding Subscription on: ", block.chainid);
            console.log(
                "Transferring LINK to VRF Coordinator w/SubID: ",
                subId
            );
            vm.startBroadcast();
            LinkToken(link).transferAndCall(
                vrfCoordinatorV2,
                SUBSCRIPTION_FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }
}

contract AddConsumer is Script{
    function addConsumer(address consumer, uint256 subId, address vrfcoordinator) public{
        vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfcoordinator).addConsumer(subId, consumer);
        vm.stopBroadcast();
    }
}