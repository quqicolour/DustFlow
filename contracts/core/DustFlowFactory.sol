// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {IDustFlowFactory} from "../interfaces/IDustFlowFactory.sol";
import {IGovernance} from "../interfaces/IGovernance.sol";
import {DustFlowCore} from "./DustFlowCore.sol";
contract DustFlowFactory is IDustFlowFactory {

    uint256 public marketId;
    address private governance;

    constructor(address _governance) {
        governance = _governance;
    }

    mapping(uint256 => MarketInfo) private marketInfo;

    function createMarket() external {
        address currentManager = IGovernance(governance).manager();
        require(msg.sender == currentManager);
        address DustFlowCore = address(
            new DustFlowCore{
                salt: keccak256(abi.encodePacked(marketId, block.timestamp, block.chainid))
            }(governance, currentManager, marketId)
        );
        marketInfo[marketId] = MarketInfo({
            market: DustFlowCore,
            createTime: uint64(block.timestamp)
        });
        emit CreateMarket(marketId, DustFlowCore);
        marketId++;
        require(DustFlowCore != address(0), "Zero address");
    }

    function getMarketInfo(uint256 id) external view returns(MarketInfo memory) {
        return marketInfo[id];
    }
}