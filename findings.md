### [H-1] Insufficient Access Control For Updating Owner of MysteryBox

**Description:**
There is no access control check on the function `MysteryBox::ChangeOwner`. This allows anyone to change the owner of the contract to an address they control and call functions that require elevated privilege, which are detrimental to the protocol in the wrong hands.

**Impact:**
For example, after calling `MysteryBox::ChangeOwner(<maliciousAddress>)` an attacker can drain the entire protocol by simply calling `MysteryBox::Withdraw`. Furthermore, they could raise the price of a mystery box to an amount prohibitively high, by calling `MysteryBox::SetBoxPrice(<extortionatePrice>)`, meaning no users will buy mystery boxes in the future. Conversely, they may set the price to 0, by calling `MysteryBox::SetBoxPrice(0)` so that the protocol is no longer able to make money and the users collectively can drain the protocol by infinitely purchasing mystery boxes until they earn rewards and redeem them from an ever decreasing reward pool.

In summary, this vulnerability allows an attacker to drain the contract completely and dramatically alter the protocol functionality by changing the mystery box price.

**Proof of Concept:**
The steps below display how anyone can take ownership of the contact and drain the contract:

1. Change ownership of the contract to malicious address
   `MysteryBox::changeOwner(attackerAddress) `

2. Drain the contract of funds by calling withdraw
   `MysteryBox::withdraw()`

**Recommended Mitigation:**
Add a check to ensure that the `msg.sender` is the owner of the contract, as is done with `MysteryBox::addReward()`.

```solidity
  function changeOwner(address _newOwner) public {
    require(msg.sender == owner, "Only owner can change ownership of contract");
    owner = _newOwner;
  }
```

### [H-2] Reentrancy attack on the function `MysteryBox::claimAllRewards`

**Description:**
`MysteryBox::ClaimAllRewards` does not follow the checks, effects and interactions pattern and is vulnerable to a reentrancy attack.

**Impact:**
An attacker can make use of a malicious drainer contract that has a `fallback` function that will continuously call `MysteryBox::ClaimAllRewards` until all the eth is drained from the contract, before the contract itself has a chance to update the state related to the rewards owned by the user.

In short this vulnerability results in the complete loss of funds of the contract.

**Proof of Concept:**

**Recommended Mitigation:**
Implement the checks, effects and interactions pattern in `MysteryBox::ClaimAllRewards()`, as seen below:

```solidity
  function claimAllRewards() public {
    // Checks
    uint256 totalValue = 0;
    for (uint256 i = 0; i < rewardsOwned[msg.sender].length; i++) {
      totalValue += rewardsOwned[msg.sender][i].value;
    }
    require(totalValue > 0, "No rewards to claim");

    // Effects
    delete rewardsOwned[msg.sender];

    // Interactions
    (bool success,) = payable(msg.sender).call{value: totalValue}("");
    require(success, "Transfer failed");
  }
```

### [H-2] Reentrancy attack on the function `MysteryBox::claimSingleReward`

**Description:**
`MysteryBox::claimSingleReward` does not follow the checks, effects and interactions pattern and is vulnerable to a reentrancy attack.

**Impact:**
An attacker can make use of a malicious drainer contract that has a `fallback` function that will continuously call `MysteryBox::claimSingleReward` until all the eth is drained from the contract, before the contract itself has a chance to update the state related to the rewards owned by the user.

In short this vulnerability results in the complete loss of funds of the contract.

**Proof of Concept:**

**Recommended Mitigation:**
Implement the checks, effects and interactions pattern in `MysteryBox::ClaimAllRewards()`, as seen below:

```solidity
  function claimSingleReward(uint256 _index) public {
    // Checks
    require(_index <= rewardsOwned[msg.sender].length, "Invalid index");
    uint256 value = rewardsOwned[msg.sender][_index].value;
    require(value > 0, "No reward to claim");

    // Effects
    delete rewardsOwned[msg.sender][_index];

    // Interactions
    (bool success,) = payable(msg.sender).call{value: value}("");
    require(success, "Transfer failed");

  }
```

### [S-3] Weak randomness

**Description:**
Randomness seed is generated from user address and block number. Both these parameters are deterministic and therefore the can be gamed to ensure the box is opened to gain the optimal reward.

### [S-4] Business logic error for new rewards

**Description:**
You can add new reward types to the contract, but the box opening logic is hardcoded, therefore the new reward type will never be attained.

### [S-5] Dos on claim all rewards

**Description**
You have to iterate over all the rewards, the more rewards, the more gas it costs the user to redeem them

### [S-5] Repetition on getter

**Description**
The state variable `MysteryBox::rewardPool` is already `public` therefore it doesn't need a getter function.
