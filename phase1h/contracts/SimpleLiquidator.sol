// SRW3 Phase 1H — Liquidator contract. Completes the
// Oracle -> Lending -> Liquidator authority chain from Phases 1F/1G on a
// real client: the liquidator READS oracle price and lending debt.
// Slot layout:
//   slot 0: oracle address    slot 1: lending address
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

interface IPrice { function price() external view returns (uint256); }
interface ILending {
    function debt(address) external view returns (uint256);
    function borrowCap() external view returns (uint256);
}

contract SimpleLiquidator {
    IPrice public oracle;
    ILending public lending;
    event Checked(address indexed who, uint256 price, uint256 debtAmt, bool healthy);

    constructor(address o, address l) {
        oracle = IPrice(o);
        lending = ILending(l);
    }

    function check(address who) external returns (bool) {
        uint256 p = oracle.price();
        uint256 d = lending.debt(who);
        bool healthy = (p == 0) ? true : (d < p * 1 ether);
        emit Checked(who, p, d, healthy);
        return healthy;
    }
}
