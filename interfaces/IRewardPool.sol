//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IRewardPool{
    //转移失败
    error FailTransfer();
    //已经提取
    error AlreadyWithdraw();
    //没有持有TFERC20
    error NoTFERC20();
}