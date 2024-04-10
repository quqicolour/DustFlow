//SPDX-License-Identifier:MIT
pragma solidity >=0.8.9;

library TimeLibrary{

    //inexistence订单不存在，
    //buying正在寻找卖家，
    //selling正在寻找买家，
    //found订单已匹配，
    //done订单已匹配，
    //出售者已支付期权token
    enum tradeState{inexistence,buying,selling,found,done}

    //struct
    struct tradeMes{
        uint32 tradeId;
        uint32 time;        //购买时的时间
        uint64 amount;      //目标代币数量
        uint128 price;       //buyPrice
        address usedToken;  //交易采用的token
        uint256 buyerNftId;  //购买者的nftId
        uint256 sellerNftId;  //出售者的nftId
        uint256 injectNftId;  //放入目标的nftId
        tradeState _tradeState;
    }

    //清算相关信息
    struct clearingMes{
        uint256 _marketId;
        uint256 _clearingTime;
        address _tokenAddress;
    }

    /*
        *  10 ether<=amount<1000 ether, 1%
        *  1000 ether<=amount<10000 ether,0.8%
        *  amount>10000 ether,0.5%
        * other error
    */
    function fee(uint8 decimals,uint256 stableAmount)internal pure returns(uint256 stableFee){
        uint256 _tokenOneAmount=10**decimals;
        if(stableAmount>=10*_tokenOneAmount && stableAmount<1000*_tokenOneAmount){
            return stableAmount/100;  //1%
        }else if(stableAmount>=1000*_tokenOneAmount && stableAmount<10000*_tokenOneAmount){
            return stableAmount/125;  //0.8%
        }else if(stableAmount>=10000*_tokenOneAmount){
            return stableAmount/200;  //0.5%
        }else{
            revert("Inexistence");
        }
    }

    function judgeInputToken(address inputToken,address[] memory allowedTokens)internal pure returns(uint256 state){
        for(uint256 i;i<allowedTokens.length;i++){
            if(inputToken==allowedTokens[i]){
                state = 1;
            }
        }
    }

    function getTargetTokenAmount(uint256 amount,uint8 decimals1,uint8 decimals2)internal pure returns(uint256){
        require(amount>0,"Zero");
        uint256 aTokenAmount=amount/(10**decimals1)*(10**decimals2);
        return aTokenAmount;
    }
}