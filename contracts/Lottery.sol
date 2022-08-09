// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

// Players could enter the lottery
// The winner should randomly get all balance of contract
// The minimum deposit is 0,1 eth
contract Lottery {
    address[] public players;
    mapping(address => uint256) public addressesDepositFunds;
    uint256 public constant MINIMUM_VALUE = 100000000000000000;

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
