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

    IPool private AaveV3Pool=IPool(0xcC6114B983E4Ed2737E9BD3961c9924e6216c704);

    //授权市场销毁a token,取回资产
    function approveMarket(address aToken,uint256 approveAmount)external onlyMarket{
        require(judgeInputAToken(aToken)==1);
        IERC20(aToken).safeApprove(timeMarket,approveAmount);
    }

    function changeAaveV3Pool(address _pool)external{
        AaveV3Pool=IPool(_pool);
    }

    //交易成功,买家提取期权token
    function buyerWithdrawShareOption(uint32 _id)external{
        uint256 nftId=getuserTradeNftId(msg.sender,_id,3);
        address thisNftOwner=ownerOf(nftId);
        require(msg.sender==thisNftOwner);
        TimeLibrary.tradeState newTradeState=getTradeMes(_id)._tradeState;
        require(newTradeState==TimeLibrary.tradeState.done,"Invalid order");
        // require(block.timestamp>getClearTime(),"Time has not arrived");
        //购买预期代币的数量
        address targetToken=getTargetToken();
        uint256 amount=getTradeMes(_id).amount;
        uint8 decimals=IERC20Metadata(targetToken).decimals();
        uint256 targetTokenAmount=amount*(10**decimals);
        uint256 fee=TimeLibrary.fee(decimals,targetTokenAmount);
        require(targetTokenAmount>0);
        IERC20(targetToken).safeTransfer(thisNftOwner,targetTokenAmount-fee);
        IERC20(targetToken).safeTransfer(getFeeAddress(),fee);
        require(_burnNft(nftId),"Burn fail");
    }

    //交易成功,卖家提取买家质押的money
    function sellerwithdrawMoney(uint32 _id,address aToken)external{
        require(judgeInputAToken(aToken)==1);
        uint256 nftId=getuserTradeNftId(msg.sender,_id,1);
        address thisNftOwner=ownerOf(nftId);
        require(msg.sender==thisNftOwner);
        // require(block.timestamp>getClearTime(),"Time has not arrived");
        TimeLibrary.tradeState newTradeState=getTradeMes(_id)._tradeState;
        require(newTradeState==TimeLibrary.tradeState.done,"Invalid order");
        //卖家质押的违约金+对手方money
        uint256 amount=getNftTradeIdValue(nftId)*2;
        address usedToken=getTradeMes(_id).usedToken;
        uint8 decimals1=IERC20Metadata(usedToken).decimals();
        uint8 decimals2=IERC20Metadata(aToken).decimals();
        uint256 aTokenAmount=TimeLibrary.getTargetTokenAmount(amount,decimals1,decimals2);
        //从aave取回token
        IERC20(aToken).approve(address(AaveV3Pool),aTokenAmount);
        AaveV3Pool.withdraw(
            usedToken,
            aTokenAmount,
            address(this)
        );
        require(getThisBalance(usedToken)>=amount);
        uint256 fee=TimeLibrary.fee(decimals1,amount);
        IERC20(usedToken).safeTransfer(thisNftOwner,amount-fee);
        IERC20(usedToken).safeTransfer(getFeeAddress(),fee);
        require(_burnNft(nftId),"Burn fail");
    }

    //交易违约,买家提取卖家支付的违约金以及自身质押的token
    function buyerWithdrawDedit(uint32 _id,address aToken)external{
        require(judgeInputAToken(aToken)==1);
        uint256 nftId=getuserTradeNftId(msg.sender,_id,0);
        address thisNftOwner=ownerOf(nftId);
        require(msg.sender==thisNftOwner);
        // require(block.timestamp>getClearTime(),"Time has not arrived");
        TimeLibrary.tradeState newTradeState=getTradeMes(_id)._tradeState;
        require(newTradeState==TimeLibrary.tradeState.found,"Invalid order");
        //退还个人存的以及卖家的违约金
        uint256 amount=getNftTradeIdValue(nftId)*2;
        address usedToken=getTradeMes(_id).usedToken;
        uint8 decimals1=IERC20Metadata(usedToken).decimals();
        uint8 decimals2=IERC20Metadata(aToken).decimals();
        uint256 aTokenAmount=TimeLibrary.getTargetTokenAmount(amount,decimals1,decimals2);
        //从aave取回token
        IERC20(aToken).approve(address(AaveV3Pool),aTokenAmount);
        AaveV3Pool.withdraw(
            usedToken,
            aTokenAmount,
            address(this)
        );
        require(getThisBalance(usedToken)>=amount);
        uint256 fee=TimeLibrary.fee(decimals1,amount);
        IERC20(usedToken).safeTransfer(thisNftOwner,amount-fee);
        IERC20(usedToken).safeTransfer(getFeeAddress(),fee);
        require(_burnNft(nftId),"Burn fail");
    }

    function getThisBalance(address token)private view returns(uint256){
        uint256 thisBalance=IERC20(token).balanceOf(address(this));
        return thisBalance;
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

    //得到费用地址
    function getFeeAddress()private view returns(address){
        address feeAddress=ITimeGovern(timeGovern).getFeeAddress();
        return feeAddress;
    }


    
}