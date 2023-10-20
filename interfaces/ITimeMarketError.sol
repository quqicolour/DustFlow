//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0;

interface ITimeMarketError{
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
}