// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

// s_Players could enter the lottery
// The winner should randomly get all balance of contract
// Must be minimum deposit value
// Lottery must happen every define time - 1 minute for example

error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);
error Raffle__TransferFailed();
error Raffle__SendMoreToEnterRaffle();
error Raffle__RaffleNotOpen();

contract Lottery is VRFConsumerBaseV2, KeeperCompatibleInterface {
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    // Chainlink variables
    // VRFCoordinatorV2Interface COORDINATOR;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator; //0x6168499c0cFfCaCD319c818142124B7A15E857ab
    uint64 private immutable i_subscriptionId; //10204
    uint32 private immutable i_callbackGasLimit; //100000;
    bytes32 private immutable i_gasLane; //0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    address private immutable s_owner;

    // Lottery variables
    address payable[] private s_players;
    uint256 public constant MINIMUM_VALUE = 100000000000000000;
    uint256 private immutable i_interval; // How often we need to do lottery,every 60 seconds
    uint256 public counter; // How much lotteries passed
    uint256 private s_lastTimeStamp;
    RaffleState private s_lotteryState;
    address private s_recentWinner;

    event RequestedRaffleWinner(uint256 indexed requestId);
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed player);

    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        bytes32 gasLane, // Or KeyHash
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        // COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        // i_vrfCoordinator = vrfCoordinatorV2;
        i_subscriptionId = subscriptionId;
        s_owner = msg.sender;
        i_callbackGasLimit = callbackGasLimit;
        i_gasLane = gasLane;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        counter = 0;
        s_lotteryState = RaffleState.OPEN;
    }

    // Lottery functions
    function enterTheLottery() public payable {
        if (msg.value < MINIMUM_VALUE) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        if (s_lotteryState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
    }

    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        override
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        // Check if timePassed,if s_players are,
        // if lottery has balance
        // if lottery is open
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hass_Players = s_players.length > 0;
        bool lotteryState = RaffleState.OPEN == s_lotteryState;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timePassed && hass_Players && lotteryState && hasBalance);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(
        bytes calldata /* performData */
    ) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_lotteryState));
        }

        s_lotteryState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[winnerIndex];
        s_recentWinner = recentWinner;
        s_players = new address payable[](0);
        s_lotteryState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        payable(recentWinner).transfer(address(this).balance);
        emit WinnerPicked(recentWinner);
    }

    function getLotteryState() public view returns (RaffleState) {
        return s_lotteryState;
    }

    function getMinimumValue() public pure returns (uint256) {
        return MINIMUM_VALUE;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }
}
