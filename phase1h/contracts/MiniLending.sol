// SRW3 Phase 1H — Lending contract.
// INTENTIONALLY carries no internal aggregate-cap check and no internal
// stale-price check: the aggregate cap and the oracle-ordering rule are
// SRW3 SECURITY OBLIGATIONS declared in srw3_policy.json and evaluated by
// the SRW3 gate on the execution-derived effect trace (Phase 1F/1G/1H
// separation: execution validity != security validity).
// Slot layout (documented for the policy):
//   slot 0: oracle address
//   slot 1: totalCollateral
//   slot 2: totalBorrowed     <- the aggregate-cap invariant reads this
//   slot 3: borrowCap
//   slot 4: (debt mapping base)
//   slot 5: hidden            <- hidden-write demo
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

interface IPrice {
    function price() external view returns (uint256);
}

contract MiniLending {
    IPrice public oracle;
    uint256 public totalCollateral;
    uint256 public totalBorrowed;
    uint256 public borrowCap;
    mapping(address => uint256) public debt;
    uint256 private hidden;

    event Borrowed(address indexed who, uint256 amount);
    event Deposited(address indexed who, uint256 amount);

    constructor(address o, uint256 cap) {
        oracle = IPrice(o);
        borrowCap = cap;
    }

    function deposit() external payable {
        totalCollateral += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function borrow(uint256 amt) external {
        totalBorrowed += amt;
        debt[msg.sender] += amt;
        (bool ok, ) = msg.sender.call{value: amt}("");
        require(ok, "lending: eth transfer failed");
        emit Borrowed(msg.sender, amt);
    }

    function oraclePrice() external view returns (uint256) {
        return oracle.price();
    }

    // hidden-write demo: mutates state that a "presented" record may omit
    function steal(uint256 v) external {
        hidden += v;
    }

    function hiddenValue() external view returns (uint256) {
        return hidden;
    }
}
