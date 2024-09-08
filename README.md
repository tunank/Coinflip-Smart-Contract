# CoinFlip Solidity Smart Contract

## Overview

The **CoinFlip** smart contract is a decentralized betting game where users can wager on the outcome of a coin flip (heads or tails). It uses the **Chainlink VRF (Verifiable Random Function)** to generate provably random results for the coin flips, ensuring fairness and transparency. Players place bets in Ether, and if they guess the outcome correctly, they win double their bet amount. The contract also implements security features like reentrancy protection and error handling.

## Features

- **Bet on Coin Flips:** Players can bet on either heads or tails by sending Ether and specifying their choice.
- **Randomness by Chainlink VRF:** Each coin flip is resolved using Chainlink VRF to provide a fair and tamper-proof random outcome.
- **Reentrancy Protection:** The contract uses OpenZeppelin's `ReentrancyGuard` to prevent reentrancy attacks.
- **Error Handling:** Custom error messages ensure clear communication when something goes wrong, such as insufficient funds or invalid requests.
- **Events:** Logs key events like bets, wins, losses, contract funding, and payouts.

## Prerequisites

- **Solidity Version:** 0.8.25
- **Chainlink VRF Setup:** You need to set up a Chainlink subscription and have access to the VRF Coordinator.

## Contract Structure

1. **Pragmas:** Solidity compiler version and license identifier.
2. **Imports:**
   - `VRFConsumerBaseV2Plus`: For Chainlink VRF interaction.
   - `VRFV2PlusClient`: For making random word requests.
   - `ReentrancyGuard`: From OpenZeppelin to prevent reentrancy attacks.
3. **Enums:**
   - `State`: Tracks the state of each coin flip bet (`OPEN`, `WIN`, `LOSS`).
   - `Choice`: Represents user’s bet choice (`HEADS`, `TAILS`).
4. **Structs:**
   - `CoinFlipRequest`: Stores details of each bet, such as bet amount, choice, state, user, and the request ID.
5. **Errors:** Custom error messages for common issues like insufficient funds or duplicate bet placement.
6. **Events:** Key actions are logged, such as successful bets, wins, losses, and failed payments.
