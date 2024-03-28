//SPDX-License-Identifier:MIT
pragma solidity ^0.8.9;
import "../libraries/SafeERC20.sol";
import "../interfaces/ITimeMarket.sol";
import "../interfaces/IERC20Metadata.sol";
import "../interfaces/ITimeGovern.sol";
import "../interfaces/ITimeCapitalPool.sol";
import "./TimeERC721.sol";

//aave v3
import "../interfaces/AaveV3/IPool.sol";

contract TimeCapitalPool is TimeERC721, ITimeCapitalPool{
    using SafeERC20 for IERC20;
    
    uint256 private thisMarketId;

    IPool private AaveV3Pool=IPool(0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951);

    mapping(uint256=>withdrawMes)private _withdrawMes;

    //授权市场销毁a token,取回资产
    function approveMarket(address aToken,uint256 approveAmount)external onlyMarket{
        require(judgeInputAToken(aToken)==1,"Non allowed token");
        IERC20(aToken).safeApprove(timeMarket,approveAmount);
    }

    //交易成功,买家提取期权token
    function buyerWithdrawShareOption(uint32 _id)external{
        uint256 nftId=getuserTradeNftId(msg.sender,_id);
        address thisNftOwner=ownerOf(nftId);
        require(msg.sender==thisNftOwner,"Non owner");
        require(block.timestamp>getClearTime(),"Time has not arrived");
        //购买预期代币的数量
        uint256 amount=getTradeMes(_id).amount;
        address targetToken=getTargetToken();
        IERC20(targetToken).safeTransfer(thisNftOwner,amount);
        _withdrawMes[_id]=withdrawMes({
            tradeId: _id,
            amount: amount,
            userAddress: thisNftOwner,
            tokenAddress: targetToken
        });
        require(_burnNft(nftId),"Burn fail");
    }

    //交易成功,卖家提取买家质押的money
    function sellerwithdrawMoney(uint32 _id,address aToken)external{
        require(judgeInputAToken(aToken)==1,"Non allowed token");
        address buyer=getTradeMes(_id).buyerAddress;
        uint256 nftId=getuserTradeNftId(msg.sender,_id);
        address thisNftOwner=ownerOf(nftId);
        require(msg.sender==thisNftOwner,"Non owner");
        require(block.timestamp>getClearTime(),"Time has not arrived");
        TimeLibrary.tradeState newTradeState=getTradeMes(_id)._tradeState;
        require(newTradeState==TimeLibrary.tradeState.found,"Invalid order");
        uint256 amount=getUserDeposite(_id,buyer).depositeAmount;
        address usedToken=getTradeMes(_id).usedToken;
        //从aave取回token
        IERC20(aToken).approve(address(AaveV3Pool),amount);
        AaveV3Pool.withdraw(
            usedToken,
            amount,
            address(this)
        );

        IERC20(usedToken).safeTransfer(thisNftOwner,amount);
        _withdrawMes[_id]=withdrawMes({
            tradeId: _id,
            amount: amount,
            userAddress: thisNftOwner,
            tokenAddress: usedToken
        });
        require(_burnNft(nftId),"Burn fail");
    }

    //交易违约,买家提取卖家支付的违约金
    function buyerWithdrawDedit(uint32 _id,address aToken)external{
        require(judgeInputAToken(aToken)==1,"Non allowed token");
        address seller=getTradeMes(_id).sellerAddress;
        uint256 nftId=getuserTradeNftId(msg.sender,_id);
        address thisNftOwner=ownerOf(nftId);
        require(msg.sender==thisNftOwner,"Non owner");
        require(block.timestamp>getClearTime(),"Time has not arrived");
        TimeLibrary.tradeState newTradeState=getTradeMes(_id)._tradeState;
        require(newTradeState==TimeLibrary.tradeState.found,"Invalid order");
        uint256 amount=getUserDeposite(_id,seller).depositeAmount;
        address usedToken=getTradeMes(_id).usedToken;
        //从aave取回token
        IERC20(aToken).approve(address(AaveV3Pool),amount);
        AaveV3Pool.withdraw(
            usedToken,
            amount,
            address(this)
        );
        IERC20(usedToken).safeTransfer(thisNftOwner,amount);
        _withdrawMes[_id]=withdrawMes({
            tradeId: _id,
            amount: amount,
            userAddress: thisNftOwner,
            tokenAddress: usedToken
        });
        require(_burnNft(nftId),"Burn fail");
    }

    //判断传入的a token是否允许
    function judgeInputAToken(address inputAToken)private view returns(uint256 state){
        address[] memory allowedATokens=ITimeGovern(timeGovern).getAllowedATokens();
        state=TimeLibrary.judgeInputToken(inputAToken,allowedATokens);
    }

    //得到trade信息
    function getTradeMes(uint32 _id)private view returns(TimeLibrary.tradeMes memory){
        return ITimeMarket(timeMarket).getTradeMes(_id);
    }

    //得到个人deposite信息
    function getUserDeposite(uint32 _id,address userAddress)private view returns(TimeLibrary.userDeposite memory){
        return ITimeMarket(timeMarket).getUserDeposite(_id,userAddress);
    }

    //返回当前清算时间
    function getClearTime()private view returns(uint256){
        uint256 time=ITimeGovern(timeGovern).getClearingTime(thisMarketId);
        return time;
    }

    //返回当前目标token
    function getTargetToken()private view returns(address){
        address targetToken=ITimeGovern(timeGovern).getTargetToken(thisMarketId);
        return targetToken;
    }


    
}