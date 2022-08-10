// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

// s_Players could enter the lottery
// The winner should randomly get all balance of contract
// Must be minimum deposit value
// Lottery must happen every define time - 1 minute for example

contract Lottery is VRFConsumerBaseV2, KeeperCompatibleInterface {
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    // Chainlink variables
    VRFCoordinatorV2Interface COORDINATOR;
    address private immutable i_vrfCoordinator; //0x6168499c0cFfCaCD319c818142124B7A15E857ab
    uint64 private immutable i_subscriptionId; //10204
    uint32 private immutable i_callbackGasLimit; //100000;
    bytes32 private immutable i_gasLane; //0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256[] public s_randomWords;
    uint256 public s_requestId;
    address private immutable s_owner;

    // Lottery variables
    address[] public s_players;
    mapping(address => uint256) public addressesDepositFunds;
    uint256 public constant MINIMUM_VALUE = 100000000000000000;
    uint256 private immutable i_interval; // How often we need to do lottery,every 60 seconds
    uint256 public counter; // How much lotteries passed
    uint256 private s_lastTimeStamp;
    RaffleState private s_lotteryState;

    modifier onlyOwner() {
        require(msg.sender == s_owner);
        _;
    }

    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        bytes32 gasLane, // Or KeyHash
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_vrfCoordinator = vrfCoordinatorV2;
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
        require(msg.value >= MINIMUM_VALUE, "Not enough eth");
        require(s_lotteryState == RaffleState.OPEN, "Lottery must be open");
        s_players.push(msg.sender);
        addressesDepositFunds[msg.sender] += msg.value;
    }

    function findTheWinner() public {
        uint256 index = s_randomWords[0] % s_players.length;
        payable(s_players[index]).transfer(address(this).balance);
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
        bool timePassed = (block.timestamp - s_lastTimeStamp) > i_interval;
        bool hass_Players = s_players.length > 1;
        bool lotteryState = RaffleState.OPEN == s_lotteryState;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timePassed && hass_Players && lotteryState && hasBalance);
        return (upkeepNeeded, "0x0");
    }

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        uint256 winnerIndex = s_randomWords[0] % s_players.length;
        s_players = new address payable[](0);
        s_lotteryState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        payable(s_players[winnerIndex]).transfer(address(this).balance);
    }

    function performUpkeep(
        bytes calldata /* performData */
    ) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {}
        s_lotteryState = RaffleState.CALCULATING;
        s_requestId = COORDINATOR.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
    }
}
