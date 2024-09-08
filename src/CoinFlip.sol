// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 Solidity Contract Layout: 
    1. Pragmas
    2. Import Statements
    3. Interfaces
    4. Libraries
    5. Contracts
    6. Enums and Structs
    7. Errors
    7. Events
    8. State Variables
    9. Constructor
    11. Functions
    10. Modifiers
 */

/**
 * @title CoinFlip Contract
 * @author TunAnk
 * @dev This contract implements a coin flip betting game using Chainlink VRF for randomness.
 */

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract CoinFlip is VRFConsumerBaseV2Plus, ReentrancyGuard{
    /*//////////////////////////////////////////////////////////////
                                 Enums
    //////////////////////////////////////////////////////////////*/

    ///@notice The state of the game 
    
    enum State{
        OPEN, // 0
        WIN,  // 1
        LOSS // 2
    }

    // Even = Heads, Odd = Tails
    enum Choice {
        HEADS, // 0
        TAILS // 1
    }

    /*//////////////////////////////////////////////////////////////
                                 STRUCT
    //////////////////////////////////////////////////////////////*/

    struct CoinFlipRequest {
        uint256 requestId;
        uint256 amount;
        State state;
        address user;
        Choice choice;
    }

    // Errors
    /// @notice Bet is below the minimum amount
    error CoinFlip__BetIsBelowMinimumAmount(address player, uint256 amount);
    /// @notice Existing bet in progress (can only place 1 live bet at a time)
    error CoinFlip__ExistingBetIsInProgress(address player);
    /// @notice CoinFlip contract has insufficient funds to payout potential bet.
    error CoinFlip__InsufficientFundsForPayout(
        address player,
        uint256 wageAmount,
        uint256 balance
    );
    /// @notice Unable to associate result with bet placed due to requestId not found.
    error CoinFlip__NoBetFoundForRequestId(uint256 requestId);
    /// @notice Error with the call function (sending payout)
    error CoinFlip__PayoutFailed(
        address player,
        uint256 requestId,
        uint256 amount
    );
    error CoinFlip__InsufficientFundsToWithdraw(uint256 amount);

    /// @notice Logs when a payment to a winning player fails
    event CoinFlip__PaymentFailed(
        address indexed user,
        uint256 indexed requestId,
        uint256 indexed amount
    );
    /// @notice Logs a winning (0 ether) bet which should never occur
    event CoinFlip__ErrorLog(string message, uint256 indexed requestId);
    /// @notice Logs a players coin flip bet
    event CoinFlip__FlipRequest(
        address indexed player,
        uint256 indexed requestId,
        uint256 amount,
        Choice choice
    );
    event CoinFlip__FlipWin(
        address indexed player,
        uint256 indexed requestId,
        uint256 amount
    );
    event CoinFlip__FlipLoss(
        address indexed player,
        uint256 indexed requestId,
        uint256 amount
    );
    event CoinFlip__Funded(address indexed funder, uint256 indexed amount);
    event CoinFlip__Withdrawl(uint256 indexed balance, uint256 indexed amount);

    /*//////////////////////////////////////////////////////////////
                                 State Variables
    //////////////////////////////////////////////////////////////*/

   // VRF State Variables
    /// @dev Number of random words to request from Chainlink VRF
    uint32 private constant NUMBER_OF_WORDS = 1;
    /// @dev Address of Chainlink VRF Coordinator
    address s_vrfCoordinatorAddress;
    /// @dev Chainlink VRF subscription id.
    uint256 private immutable i_subscriptionId;
    /// @dev Maximum gas we are willing to pay for gas used by our fulfillRandomWords
    uint32 private immutable i_callbackGasLimit;
    /// @dev Specifies the maximum gas price we are willing to pay to make a request.
    bytes32 private immutable i_gasLane;
    /// @dev Minimum number of blocks to be confirmed before Chainlink VRF invokes our fulfillRandomWords (sends us our random word.)
    uint16 private immutable i_numOfRequestConfirmations;
    /// @dev ReEntrancy locks per user.
    mapping(address => bool) internal s_locksByUser;

    /// @dev minimum amount a user must wage.
    uint256 immutable MINIMUM_WAGER;
    /// @dev Tracks the potential amount the contract is required to potentially payout (tracks potential payout of unconcluded games)
    uint256 private s_totalPotentialPayout;
    /// @dev Status of coin flip game by request ID
    mapping(uint256 => CoinFlipRequest) private s_flipRequestByRequestId;
    /// @dev Status of most recent coin flip game by address
    mapping(address => CoinFlipRequest) private s_recentFlipRequestByAddress;
    /// @dev Tracks potential payout of in-play (unconcluded) games by address.
    mapping(address => uint256) private s_potentialPayoutByAddress;


    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Constructor to initialize the CoinFlip contract
     * @param minimumWager The minimum amount required to place a bet
     * @param vrfCoordinatorAddress The address of the VRF Coordinator
     * @param subscriptionId The subscription ID for Chainlink VRF
     * @param gasLane The gas lane key hash for VRF
     * @param callbackGasLimit The gas limit for the VRF callback
     */
    constructor(
        uint256 minimumWager,
        address vrfCoordinatorAddress,
        uint256 subscriptionId,
        bytes32 gasLane,
        uint32 callbackGasLimit,
        uint16 numOfRequestConfirmations
    ) VRFConsumerBaseV2Plus(vrfCoordinatorAddress){
        MINIMUM_WAGER = minimumWager;
        s_vrfCoordinatorAddress = vrfCoordinatorAddress;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        i_gasLane = gasLane;
        i_numOfRequestConfirmations = numOfRequestConfirmations;
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE & FALLBACK
    //////////////////////////////////////////////////////////////*/
    receive() external payable{}
    fallback() external payable{}

    /*//////////////////////////////////////////////////////////////
                                 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice fund the contract with Eth
    function fund() external payable nonReentrant {
        require(msg.value > 0, "Cannot fund with zero ether");
        emit CoinFlip__Funded(msg.sender, msg.value);
    }

    /**
     * @notice Function only owner can call to withdraw funds from the contract
     * @param amount amount to withdraw
     */
    function withdraw(uint256 amount) external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        if (balance < amount) {
            revert CoinFlip__InsufficientFundsToWithdraw(amount);
        }
        (bool sent /* bytes memory */, ) = msg.sender.call{value: amount}("");
        require(sent, "Withdrawal failed");
        emit CoinFlip__Withdrawl(balance, amount);
    }

    /**
     * @notice function to help players bet
     * @param userChoice user choice of head or tail
     */
    function bet(uint8 userChoice) external payable nonReentrant {
        // Checks
        // User bets above minimum amount
        if (msg.value < MINIMUM_WAGER) {
            revert CoinFlip__BetIsBelowMinimumAmount(msg.sender, msg.value);
        }

        // If user has never played a game before, recentFlipRequest will have a state of OPEN, amount will be 0, we can use this.
        CoinFlipRequest memory recentFlipRequest = s_recentFlipRequestByAddress[
            msg.sender
        ];
        if (
            recentFlipRequest.amount != 0 &&
            (recentFlipRequest.state == State.OPEN)
        ) {
            // Users recent
            revert CoinFlip__ExistingBetIsInProgress(msg.sender);
        }

        // Check if contract has amount to pay user excluding the funds the user has provided.
        uint256 contractBalanceExcludingBet = address(this).balance - msg.value;
        if (contractBalanceExcludingBet - s_totalPotentialPayout < msg.value) {
            revert CoinFlip__InsufficientFundsForPayout(
                msg.sender,
                msg.value,
                contractBalanceExcludingBet
            );
        }

        // Effects
        uint256 payoutAmount = 2 * msg.value;
        s_potentialPayoutByAddress[msg.sender] = payoutAmount;
        s_totalPotentialPayout += payoutAmount;
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: i_numOfRequestConfirmations,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUMBER_OF_WORDS,
                extraArgs: ""
            })
        );

        emit CoinFlip__FlipRequest(
            msg.sender,
            requestId,
            msg.value,
            Choice(userChoice % 2)
        );

        CoinFlipRequest memory flipRequest = CoinFlipRequest({
            amount: msg.value,
            state: State.OPEN,
            requestId: requestId,
            user: msg.sender,
            choice: Choice(userChoice % 2)
        });

        s_flipRequestByRequestId[requestId] = flipRequest;
        s_recentFlipRequestByAddress[msg.sender] = flipRequest;
    }



    /**
     * @notice Function called by VRF coordinator to fulfill random words request
     * @param requestId The ID of the VRF request
     * @param randomWords The array of random words generated
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        // This function will be called by the VRF service
        Choice result = Choice(randomWords[0] % 2);
        CoinFlipRequest memory recentRequest = s_flipRequestByRequestId[
            requestId
        ];
        if (recentRequest.amount == 0) {
            emit CoinFlip__ErrorLog("Invalid request data", requestId);
            return;
        }
        uint256 potentialPayoutAmount = 2 * recentRequest.amount;
        s_totalPotentialPayout -= potentialPayoutAmount;
        delete s_potentialPayoutByAddress[recentRequest.user];

        if (recentRequest.choice == result) {
            recentRequest.state = State.WIN;
            s_flipRequestByRequestId[requestId] = recentRequest;
            s_recentFlipRequestByAddress[recentRequest.user] = recentRequest;
            // User has won.
            (bool sent /* bytes memory data */, ) = (recentRequest.user).call{
                value: potentialPayoutAmount
            }("");

            if (!sent) {
                emit CoinFlip__PaymentFailed(
                    recentRequest.user,
                    requestId,
                    potentialPayoutAmount
                );
            }

            emit CoinFlip__FlipWin(
                recentRequest.user,
                requestId,
                potentialPayoutAmount
            );
        } else {
            recentRequest.state = State.LOSS;
            s_flipRequestByRequestId[requestId] = recentRequest;
            s_recentFlipRequestByAddress[recentRequest.user] = recentRequest;
            // User has lost.
            emit CoinFlip__FlipLoss(
                recentRequest.user,
                requestId,
                potentialPayoutAmount
            );
        }
    }

    /**
     * @notice Get the most recent coin flip result for a given address
     * @param user The address of the user
     * @return CoinFlipRequest The most recent coin flip request
     */
    function getRecentCoinFlipResultByAddress(
        address user
    ) public view returns (CoinFlipRequest memory) {
        return s_recentFlipRequestByAddress[user];
    }

    /**
     * @notice Get the total potential payout for all bets
     * @return uint256 The total potential payout
     */
    function getTotalPotentialPayout() public view returns (uint256) {
        return s_totalPotentialPayout;
    }

    /**
     * @notice Get the potential payout for a specific user
     * @param user The address of the user
     * @return uint256 The potential payout for the user
     */
    function getPotentialPayoutForAddress(
        address user
    ) public view returns (uint256) {
        return s_potentialPayoutByAddress[user];
    }

    /**
     * @notice Get the coin flip result by request ID
     * @param requestId The ID of the request
     * @return CoinFlipRequest The coin flip request data
     */
    function getResultByRequestId(
        uint256 requestId
    ) public view returns (CoinFlipRequest memory) {
        return s_flipRequestByRequestId[requestId];
    }
}
