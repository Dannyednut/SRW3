// SRW3 Phase 1H — Oracle contract. Slot layout is deliberate and documented:
//   slot 0: price      slot 1: updatedAt      slot 2: owner
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

contract SimpleOracle {
    uint256 public price;
    uint64  public updatedAt;
    address public owner;

    event PriceSet(uint256 indexed newPrice, uint64 at);

    constructor() {
        owner = msg.sender;
    }

    function setPrice(uint256 p) external {
        require(msg.sender == owner, "oracle: not owner");
        price = p;
        updatedAt = uint64(block.timestamp);
        emit PriceSet(p, uint64(block.timestamp));
    }
}
