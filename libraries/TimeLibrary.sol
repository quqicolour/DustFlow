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
        uint32 price;       //buyPrice/1000=当前价格
        uint56 time;        //购买时的时间
        uint128 amount; //预期空投代币数量
        uint256 tokenOneAmount;  //1单位数量
        address usedToken;  //交易采用的token
        address buyerAddress;
        address sellerAddress;
        tradeState _tradeState;
    }

    struct userDeposite{
        uint32 tradeId;
        uint56 startTime;
        uint56 endTime;
        uint256 depositeAmount;
        uint256 earnAmount;
        address user;
    }

    //清算相关信息
    struct clearingMes{
        uint256 _marketId;
        uint256 _clearingTime;
        address _tokenAddress;
    }

    /*
        *  100 ether<=amount<1000 ether, 1%
        *  1000 ether<=amount<10000 ether,0.8%
        *  amount>10000 ether,0.5%
        * other error
    */
    function fee(uint256 _tokenOneAmount,uint256 stableAmount)internal pure returns(uint256 stableFee){
        if(stableAmount>=100*_tokenOneAmount && stableAmount<1000*_tokenOneAmount){
            return stableAmount/100;
        }else if(stableAmount>=1000*_tokenOneAmount && stableAmount<10000*_tokenOneAmount){
            return stableAmount/125;
        }else if(stableAmount>=10000*_tokenOneAmount){
            return stableAmount/200;
        }else{
            return 0;
        }
    }

    //计算出售者需要质押的违约金(稳定币)
    function getPenal(uint32 _soldPrice, uint128 _soldAmount,uint256 _tokenOneAmount)internal pure returns (uint256){
        uint256 thisAmount = (_soldPrice*_tokenOneAmount)/1000*_soldAmount;
        if (thisAmount >= 100*_tokenOneAmount && thisAmount < 1000*_tokenOneAmount) {
            return (thisAmount * 50) / 100;
        } else if (thisAmount >= 1000*_tokenOneAmount && thisAmount < 10000*_tokenOneAmount) {
            return (thisAmount * 40) / 100;
        } else if (thisAmount > 10000*_tokenOneAmount) {
            return (thisAmount * 25) / 100;
        } else {
            revert("NotEnoughAmount");
        }
    }

    //计算总质押稳定币数量
    function getTotalStable(uint32 _soldPrice, uint128 _soldAmount,uint256 _tokenOneAmount)internal pure returns(uint256){
        return _soldAmount*_soldPrice/1000*_tokenOneAmount;
    }

    function judgeInputToken(address inputToken,address[] memory allowedTokens)internal pure returns(uint256 state){
        for(uint256 i;i<allowedTokens.length;i++){
            if(inputToken==allowedTokens[i]){
                state = 1;
            }
        }
    }
}