// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

interface IDustCore{

    enum FlowWay{
        doTransfer,
        flow
    }

    enum UserFlowState{
        sendFlow,
        receiveFlow
    }

    struct DustCollateralInfo {
        bytes1 activeState;
        uint8 liquidationRatio;
        uint16 liquidationRewardRatio; 
        uint256 reserve;
    }

    struct DustFlowInfo {
        FlowWay way;
        address sender;
        address receiver;
        address flowToken;
        uint64 startTime;
        uint64 endTime;
        uint128 amount;
        uint128 doneAmount;
        uint256 lastestWithdrawTime;
    } 
    
    event ChangeOwner(address older, address newer);
    event ChangeManager(address older, address newer);
    event Initialize(bytes1 state);
    event LockEvent(bytes1 state);
    event ChangeFeeInfo(address newFeeReceier, uint64 newFee);
    event UpdateComt(address comt, address rewards);
    event Blacklist(address blacklist, bool state);
    event MintDUST(address receiver, uint256 collateralAmount, uint256 dustAmount);
    event Refund(address receiver, uint256 collateralAmount, uint256 dustAmount);
    event Flow(FlowWay indexed way, address indexed sender, address receiver, uint256 amount);
    event FlowReceive(address receiver, address token, uint256 amount);

}

