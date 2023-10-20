//SPDX-License-Identifier:MIT
pragma solidity >=0.8.9;
pragma abicoder v2;
import "../libraries/SafeERC20.sol";
import "../interfaces/ITimeMarketStruct.sol";
import "../interfaces/ITimeMarketError.sol";
import "../libraries/TimeFee.sol";
import "../interfaces/IERC20Metadata.sol";

//TFERC20
import "./TFERC20.sol";

//aave v3
import "../interfaces/AaveV3/IPool.sol";

contract TimeMarket is ITimeMarketStruct, ITimeMarketError, TFERC20{
    using SafeERC20 for IERC20;
    uint56 private clearingTime;
    uint64 id;
    address private airdropToken;
    address private feeAddress=0x57Ea5438bF59C87F579F9872dCBE575f46e529Fe; //费用接shou地址

    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    //AAVE V3 (sepolia)
    IPool private AaveV3Pool=IPool(0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951);

    //aave usdt=0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0
    address AUSDT=0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0;

    constructor(address _airdropToken,uint _clearingTime){
        airdropToken=_airdropToken;
        clearingTime=uint56(_clearingTime);
    }

    mapping(uint64=>tradeMes)private _tradeMes;
    //出售者是否在交易时间结束前存入某个交易的空投代币
    mapping(address => mapping(uint256=>bool))private ifInject; 
    //记录用户的流动性数量
    mapping(address=>mapping(uint64=>uint)) private userLiquidity;

    //交易成功，购买者是否提取空投代币
    mapping(address => mapping(uint256=>bool))public userIfWithdraw1;
    //交易成功，出售者是否提取稳定币
    mapping(address => mapping(uint256=>bool))public userIfWithdraw2;
    //交易失败，购买者是否提取违约金
    mapping(address => mapping(uint256=>bool))public userIfWithdraw3;

    //购买(最小购买价格_buyPrice==1==0.001U)
    function buy(address _tokenAddress,uint128 _buyAmount,uint128 _buyPrice)external{
        //小数点后标志位
        uint8 decimals=IERC20Metadata(_tokenAddress).decimals();
        uint256 total = (_buyAmount*10**decimals)* _buyPrice / 1000;
        uint256 beforeBalance=IERC20(AUSDT).balanceOf(address(this));
        if(total<100*10**decimals){
            revert NotEnoughAmount();
        }
        
        //将代币转入该合约
        IERC20(_tokenAddress).safeTransferFrom(msg.sender,address(this),total);
        //授权给AAVE V3的pool
        IERC20(_tokenAddress).approve(address(AaveV3Pool),total);
        //供应到AAVE V3
        AaveV3Pool.supply(
            _tokenAddress,       //供应的token地址
            total,               //供应数量
            address(this),       //接收a token地址
            0                    //当前referralCode=0
        );
        
        uint256 afterBalance=IERC20(AUSDT).balanceOf(address(this));
        uint128 Abalance=uint128(afterBalance-beforeBalance);
        uint128 mintAmount = Abalance==0?uint128(total):Abalance;
        tradeMes memory newTradeMes=tradeMes({
            tradeState: 1,
            tradeId: id,
            buyTime: uint56(block.timestamp),
            buyTotalAmount: _buyAmount,
            buyPrice: _buyPrice,
            buyerATokenAmount: mintAmount,
            solderATokenAmount: 0,
            tokenAddress: _tokenAddress,
            buyerAddress: msg.sender,
            solderAddress: address(this)
        });
        _tradeMes[id]=newTradeMes;
        
        id++;
    }

    //出售版本 
    function Sale(uint64 _id) external {
        tradeMes memory maxTradeMes=_tradeMes[_id];
        require(maxTradeMes.tradeState==1);  //未产生交易的事务
        address promiseStableToken=maxTradeMes.tokenAddress;
        uint256 penalAmount=getPenal(promiseStableToken,maxTradeMes.buyPrice, maxTradeMes.buyTotalAmount);
        uint256 beforeBalance=IERC20(AUSDT).balanceOf(address(this));
        //质押违约金
        IERC20(promiseStableToken).safeTransferFrom(
            msg.sender,
            address(this),
            penalAmount
        );

        //授权给AAVE V3的pool
        IERC20(promiseStableToken).approve(address(AaveV3Pool),penalAmount);
        //供应到AAVE V3
        AaveV3Pool.supply(
            promiseStableToken,       //供应的token地址
            penalAmount,               //供应数量
            address(this),       //接收a token地址
            0                    //当前referralCode=0
        );
        
        _tradeMes[_id].solderAddress=msg.sender;
        //更改为2
        _tradeMes[_id].tradeState=2;

        uint256 afterBalance=IERC20(AUSDT).balanceOf(address(this));
        uint128 Abalance = uint128(afterBalance-beforeBalance);
        uint128 mintAmount = Abalance==0?uint128(penalAmount):Abalance;

        _tradeMes[_id].solderATokenAmount=mintAmount;

    }

    //出售者放入自己成交的空投token数量(在清算结束1小时前存入空投代币，否则视为违约)
    function injectFutureToken(uint64 _id)external{
        //是否已放入约定的空投代币数量
        if(ifInject[msg.sender][_id]){revert AlreadyInjectToken();}
        //发送者是否是出售者,同时也意味着出售者已经质押
        if(getSolder(_id)!=msg.sender){revert NorSolder();}
        uint256 beforeBalance=IERC20(airdropToken).balanceOf(address(this));
        //需要质押的空投代币数量
        uint8 decimals=IERC20Metadata(airdropToken).decimals();
        uint256 thisAirdropAmount=_tradeMes[_id].buyTotalAmount;
        uint256 injectAmount=thisAirdropAmount*10**decimals;
        IERC20(airdropToken).safeTransferFrom(msg.sender,address(this),injectAmount);
        ifInject[msg.sender][_id]=true;
        _tradeMes[_id].tradeState=3;
        uint256 afterBalance=IERC20(airdropToken).balanceOf(address(this));
        //检查交易
        if(beforeBalance + injectAmount != afterBalance){
            revert FailTransfer();
        }
    }

    //提取交易成功的空投代币数量（出售者按期注入空投代币）
    function buyerWithdrawAirdorp(uint64 _id)external{
        address buyer=getBuyer(_id);
        //是否是该购买者
        if(msg.sender!=buyer){revert NotBuyer();}
        //该笔交易是否出售者已经质押空投代币
        if(_tradeMes[_id].tradeState!=3){revert NotInjectToken();} 
        uint8 decimals=IERC20Metadata(airdropToken).decimals();
        uint128 buyAmount=_tradeMes[_id].buyTotalAmount;
        uint256 withdrawAmount=buyAmount*10**decimals;
        uint128 buyerPrice=_tradeMes[_id].buyPrice;
        uint256 beforeBalance=IERC20(airdropToken).balanceOf(address(this));
        //费用=购买数量*购买价格
        uint256 fee=TimeFee.fee(decimals,buyerPrice*withdrawAmount/1000);
        if(fee!=0){
            //转移费用给协议所有者
            IERC20(airdropToken).safeTransfer(feeAddress,fee);
        }
        uint256 withdrawMoney=withdrawAmount-fee;
        //转移给购买者
        IERC20(airdropToken).safeTransfer(buyer,withdrawMoney);
        _tradeMes[_id].tradeState=4;
        uint256 afterBalance=IERC20(airdropToken).balanceOf(address(this));
        //检查交易
        if(beforeBalance - afterBalance != withdrawMoney){
            revert FailTransfer();
        }

    }

    //交易成功,出售者提取稳定币
    function solderWithdrawStable(uint64 _id)external{
        // address buyer=getBuyer(_id);
        address solder=getSolder(_id);
        //是否是该出售者
        if(msg.sender != solder){revert NorSolder();} 
        //交易对手是否质押相应成交的空投token
        if(ifInject[solder][_id]==false){revert AlreadyInjectToken();}
        //购买者是否提取
        if(userIfWithdraw2[msg.sender][_id]){revert AlreadyWithdraw();}

        address promiseStableToken=_tradeMes[_id].tokenAddress;
        uint8 decimals=IERC20Metadata(promiseStableToken).decimals();
        uint256 buyTotal=_tradeMes[_id].buyPrice*_tradeMes[_id].buyTotalAmount;
        uint256 penalSumAmount=getPenal(promiseStableToken,_tradeMes[_id].buyPrice,_tradeMes[_id].buyTotalAmount);
        // uint256 beforeBalance=IERC20(promiseStableToken).balanceOf(address(this));
        //按交易总量计算费用，质押的保证金不计入
        uint256 fee=TimeFee.fee(decimals,buyTotal*(10**decimals)/1000);
        //购买者的（质押金+出售者的违约金质押到aave获得的a token数量）
        uint256 total=_tradeMes[_id].buyerATokenAmount+_tradeMes[_id].solderATokenAmount;
        //授权给AaveV3Pool
        IERC20(AUSDT).approve(address(AaveV3Pool),total);
        //从aave v3提取供应的代币数量
        AaveV3Pool.withdraw(
            promiseStableToken,
            total,
            address(this)
        );

        // uint256 afterBalance=IERC20(promiseStableToken).balanceOf(address(this));
        //转移费用给协议所有者
        if(fee!=0){
            //转移费用给协议所有者
            IERC20(promiseStableToken).safeTransfer(feeAddress,fee);
        }
    
        //转移给出售者
        IERC20(promiseStableToken).safeTransfer(
            solder,
            buyTotal+penalSumAmount-fee
        );
        //收益
        // uint256 profit=(afterBalance-beforeBalance)-(buyTotal+penalSumAmount)>0
        // ?(afterBalance-beforeBalance)-(buyTotal+penalSumAmount)
        // :0;

        //转移质押利润给购买者和出售者
        // if(profit>0){
        //     IERC20(promiseStableToken).safeTransfer(
        //         solder,
        //         profit*10/3
        //     );   //30%利息
        //     IERC20(promiseStableToken).safeTransfer(
        //         buyer,
        //         profit*10/7
        //     );  //70%
        // }
        
        //用户提取设置为true
        userIfWithdraw2[msg.sender][_id]=true; 
    }

    //交易失败，购买者提取违约金（未产生交易退回money）
    function buyerWithdrawRefund(uint64 _id)external{
        address buyer=getBuyer(_id);
        address solder=getSolder(_id);
        //是否是该出售者
        if(msg.sender != buyer){revert NotBuyer();} 
        //交易对手是否质押相应成交的空投token
        if(ifInject[solder][_id]){revert NotInjectToken();}
        //购买者是否提取
        if(userIfWithdraw3[msg.sender][_id]){revert AlreadyWithdraw();}

        address promiseStableToken=_tradeMes[_id].tokenAddress;
        uint8 decimals=IERC20Metadata(promiseStableToken).decimals();
        uint256 beforeBalance=IERC20(promiseStableToken).balanceOf(address(this));
        uint256 penalSumAmount=getPenal(promiseStableToken,_tradeMes[_id].buyPrice,_tradeMes[_id].buyTotalAmount);
        uint256 buyTotal=_tradeMes[_id].buyPrice*_tradeMes[_id].buyTotalAmount;
        //费用(按交易失败，出售者的违约金计算)
        uint256 fee=TimeFee.fee(decimals,penalSumAmount);
        //购买者的质押金+出售者的违约金mint的a toke数量
        uint256 total=_tradeMes[_id].buyerATokenAmount+_tradeMes[_id].solderATokenAmount;

        // 如果交易状态为2则代表出售者违约，如果交易状态为1则代表没有匹配到卖家，否则报错
        if(_tradeMes[_id].tradeState==2){
            //授权给AaveV3Pool
            IERC20(AUSDT).approve(address(AaveV3Pool),total);
            //从aave v3提取供应的代币数量
            AaveV3Pool.withdraw(
                promiseStableToken,
                total,
                address(this)
            );
            //费用
            if(fee!=0){
                //转移费用给协议所有者
                IERC20(airdropToken).safeTransfer(feeAddress,fee);
            }
            uint256 afterBalance=IERC20(promiseStableToken).balanceOf(address(this));
            uint256 totalMoney = (afterBalance-beforeBalance-fee)>0?(afterBalance-beforeBalance-fee):(buyTotal+penalSumAmount-fee);
            //转移相应稳定币到购买者
            IERC20(promiseStableToken).safeTransfer(
                buyer,
                totalMoney
            );
            userIfWithdraw3[msg.sender][_id]=true;

            _tradeMes[_id].tradeState=5;
        }else if(_tradeMes[_id].tradeState==1){
            //购买者铸造的aave的atoken
            uint128 buyerATokenAmount=_tradeMes[_id].buyerATokenAmount;
            //授权给AaveV3Pool
            IERC20(AUSDT).approve(address(AaveV3Pool),buyerATokenAmount);
            //从aave v3提取供应的代币数量
            AaveV3Pool.withdraw(
                promiseStableToken,
                buyerATokenAmount,
                address(this)
            );
            uint256 afterBalance=IERC20(promiseStableToken).balanceOf(address(this));
            uint256 totalMoney = (afterBalance-beforeBalance)>0?(afterBalance-beforeBalance):(buyTotal+penalSumAmount);
            //转移相应稳定币到购买者
            IERC20(promiseStableToken).safeTransfer(
                buyer,
                totalMoney
            );
            //取走置0
            _tradeMes[_id].tradeState=0;
            _tradeMes[_id].buyTotalAmount=0;
        }else{
            revert TradeSuccess();
        }
    }
   
    //根据交易id获取到购买者
    function getBuyer(uint64 _id)internal view returns(address){
        return _tradeMes[_id].buyerAddress;
    }

    //根据交易id获取到出售者
    function getSolder(uint64 _id)internal view returns(address){
        return _tradeMes[_id].solderAddress;
    }

    //计算出售者需要质押的违约金(稳定币)
    function getPenal(address token,uint128 _soldPrice, uint128 _soldAmount)public view returns (uint256){
        uint8 decimals=IERC20Metadata(token).decimals();
        uint256 thisAmount = (_soldPrice*10**decimals)/1000*_soldAmount;
        if (thisAmount >= 100*10**decimals && thisAmount < 1000*10**decimals) {
            return (thisAmount * 50) / 100;
        } else if (thisAmount >= 1000*10**decimals && thisAmount < 10000*10**decimals) {
            return (thisAmount * 40) / 100;
        } else if (thisAmount > 10000*10**decimals) {
            return (thisAmount * 25) / 100;
        } else {
            revert NotEnoughAmount();
        }
    }

    //根据交易id得到_tradeMes
    function getTradeMes(uint64 _id)external view returns(tradeMes memory){
        return _tradeMes[_id];
    }

}