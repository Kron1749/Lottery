// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

// Players could enter the lottery
// The winner should randomly get all balance of contract
// Must be minimum deposit value
// Lottery must happen every define time - 1 minute for example

contract Lottery is VRFConsumerBaseV2 {
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
    address s_owner;
    modifier onlyOwner() {
        require(msg.sender == s_owner);
        _;
    }

    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        bytes32 gasLane // Or KeyHash
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_vrfCoordinator = vrfCoordinatorV2;
        i_subscriptionId = subscriptionId;
        s_owner = msg.sender;
        i_callbackGasLimit = callbackGasLimit;
        i_gasLane = gasLane;
    }

    function requestRandomWords() external onlyOwner {
        // Will revert if subscription is not set and funded.
        s_requestId = COORDINATOR.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
    }

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        s_randomWords = randomWords;
    }

    // Lottery variables
    address[] public players;
    mapping(address => uint256) public addressesDepositFunds;
    uint256 public constant MINIMUM_VALUE = 100000000000000000;

    // Lottery functions
    function enterTheLottery() public payable {
        require(msg.value >= MINIMUM_VALUE, "Not enough eth");
        players.push(msg.sender);
        addressesDepositFunds[msg.sender] += msg.value;
    }

    function findTheWinner() public {
        uint256 index = pseudoRandom() % players.length;
        payable(players[index]).transfer(address(this).balance);
    }

    function pseudoRandom() private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, players)));
    }
}
