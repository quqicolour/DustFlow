//SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;
import "../libraries/SafeERC20.sol";
import "../interfaces/IERC20Metadata.sol";
import "../interfaces/IRewardPool.sol";
contract RewardPool is IRewardPool{
    using SafeERC20 for IERC20;
    address private TFAddress;  //mint的TF TOKEN

    constructor(address _TFAddress){
        TFAddress=_TFAddress;
    }

    //用户是否提取
    mapping(address=>bool)private userIfWithdraw;

    //提取奖励(50%)
    function withdrawReward(address stableAddress)external{
        uint256 personlTFERC20Amount=getTFERC20Amount(msg.sender);
        if(personlTFERC20Amount>0){revert NoTFERC20();}
        uint256 userProfit=profit(stableAddress);
        //用户授权该合约并销毁TF token
        IERC20(TFAddress).safeTransfer(address(0),personlTFERC20Amount);
        IERC20(stableAddress).safeTransfer(msg.sender,userProfit);
        userIfWithdraw[msg.sender]=true;
    }

    //计算用户的收益
    function profit(address stableAddress)public view returns(uint256 userEarn){
        uint256 stableAmount=IERC20(stableAddress).balanceOf(address(this));
        uint256 personlTFERC20Amount=getTFERC20Amount(msg.sender);
        if(userIfWithdraw[msg.sender]){revert AlreadyWithdraw();}
        //个人数量/TFERC20总数*稳定币数量
        userEarn = personlTFERC20Amount/getTotal()*stableAmount;
    }

    //获取token的总量
    function getTotal()public view returns(uint256){
        return IERC20Metadata(TFAddress).totalSupply();
    }

    //获取个人Mint的TFERC20总量
    function getTFERC20Amount(address userAddress)public view returns(uint256){
        return IERC20(TFAddress).balanceOf(userAddress);
    }
}