//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0;

interface ITimeMarket{
    //struct
    struct tradeMes{
        uint8 tradeState; 
        uint64 tradeId;
        uint56 buyTime;
        uint128 buyTotalAmount; //预期空投代币数量
        uint128 buyPrice;       //buyPrice/1000=当前价格
        uint128 buyerATokenAmount;   //购买者铸造的aave token数量
        uint128 solderATokenAmount;   //出售者铸造的aave token数量
        address tokenAddress;
        address buyerAddress;
        address solderAddress;
    }


    //error
    //购买数量<100
    error NotEnoughAmount();
    //已经放入约定的空投代币数量
    error AlreadyInjectToken();
    //没有放入约定的空投代币数量
    error NotInjectToken();
    //不是购买者
    error NotBuyer();
    //不是出售者
    error NorSolder();
    //交易成功
    error TradeSuccess();
    //注入aave错误
    error InjectAaveError();
    //已经提取代币
    error AlreadyWithdraw();
    //token转移失败
    error FailTransfer();

    //event
    event withdrawAipdrop(uint256 _amount,uint256 _time,address _userAddress);
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
}