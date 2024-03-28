//SPDX-License-Identifier:MIT
pragma solidity ^0.8.9;
import "../libraries/SafeERC20.sol";
import "../libraries/TimeLibrary.sol";
import "../interfaces/ITimeMarket.sol";
import "../interfaces/IERC20Metadata.sol";
import "../interfaces/ITimeMarketFactory.sol";
import "../interfaces/ITimeCapitalPoolFactory.sol";
import "../interfaces/ITimeCapitalPool.sol";
import "../interfaces/ITimeGovern.sol";
import "../interfaces/IERC721.sol";

//aave v3
import "../interfaces/AaveV3/IPool.sol";

//计算个人获得的利息=个人质押数量/总质押数量*利息总数量+个人质押数量

contract TimeMarket is ITimeMarket{
    using SafeERC20 for IERC20;
    uint32 private id;  //交易订单次数
    uint256 private thisMarketId;
    uint256 private totalStable;  //总质押的稳定币数量

    bool private initState;

    address private owner;  
    address private timeCapitalPoolFactory;
    address private timeGovern;
    address private timeERC721;

    // address private AUSDT=0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0;   //aave usdt=0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0
    // address private AEthUsdt=0xAF0F6e8b0Dc5c913bbF4d14c22B4E78Dd14310B6;

    //AAVE V3 (sepolia)
    IPool private AaveV3Pool=IPool(0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951);

    constructor(uint256 _thisMarketId){
        thisMarketId=_thisMarketId;
        owner=msg.sender;
    }

    //记录对应下的交易信息
    mapping(uint32=>TimeLibrary.tradeMes)private _tradeMes;
    //
    mapping(uint32=>mapping(address=>TimeLibrary.userDeposite))private _userDeposite;
    //记录用户的流动性数量
    mapping(address=>mapping(uint64=>uint)) private userLiquidity;

    function initialize(address _timeERC721,address _timeCapitalPoolFactory,address _timeGovern)external{
        require(msg.sender==owner,"Non owner");
        require(initState==false,"Already init");
        timeERC721=_timeERC721;
        timeCapitalPoolFactory=_timeCapitalPoolFactory;
        timeGovern=_timeGovern;
        initState=true;
    }

    //挂单(买卖)
    function putTrade(address _tokenAddress,uint32 _price,uint128 _amount,uint256 doState)external{
        require(judgeInputStableToken(_tokenAddress)==1,"Non allowed token");
        //小数点后标志位
        uint8 decimals=IERC20Metadata(_tokenAddress).decimals();
        uint256 oneToken=10**decimals;
        uint256 total = TimeLibrary.getTotalStable(_price,_amount,oneToken);
        require(total>=10*oneToken);

        address buyer;
        address seller;

        TimeLibrary.tradeState newTradeState;
        if(doState==0){
            buyer=msg.sender;
            newTradeState=TimeLibrary.tradeState.buying;
        }else if(doState==1){
            newTradeState=TimeLibrary.tradeState.selling;
            seller=msg.sender;
        }else{
            revert("Non");
        }

        //清算时间24h前不能挂单
        require(block.timestamp<=getClearTime()-1 days,"Not time");
        
        //将代币转入该合约
        IERC20(_tokenAddress).safeTransferFrom(msg.sender,address(this),total);
        //授权给AAVE V3的pool
        IERC20(_tokenAddress).approve(address(AaveV3Pool),total);
        //供应到AAVE V3
        AaveV3Pool.supply(
            _tokenAddress,       //供应的token地址
            total,               //供应数量
            getTimeCatpitalPool(),       //接收a token地址
            0                    //当前referralCode=0
        );

        _tradeMes[id].tradeId=id;
        _tradeMes[id].price=_price;
        _tradeMes[id].time=uint56(block.timestamp);
        _tradeMes[id].amount=_amount;
        _tradeMes[id].tokenOneAmount=oneToken;
        _tradeMes[id].usedToken=_tokenAddress;
        _tradeMes[id].buyerAddress=buyer;
        _tradeMes[id].sellerAddress=seller;
        _tradeMes[id]._tradeState=newTradeState;

        _userDeposite[id][msg.sender].tradeId=id;
        _userDeposite[id][msg.sender].startTime=_tradeMes[id].time;
        _userDeposite[id][msg.sender].endTime=0;
        _userDeposite[id][msg.sender].depositeAmount=total;
        _userDeposite[id][msg.sender].earnAmount=0;
        _userDeposite[id][msg.sender].user=msg.sender;
        
        //总质押稳定币数量相加新的质押数量
        totalStable+=total;
        id++;
        require(IERC721(timeERC721).marketMint(msg.sender,id,total,doState,_tokenAddress));
    }

    //匹配订单
    function matchTrade(uint32 _id) external{
        uint256 doState;
        if(_tradeMes[_id]._tradeState==TimeLibrary.tradeState.buying){
            doState=0;
        }else if(_tradeMes[_id]._tradeState==TimeLibrary.tradeState.selling){
            doState=1;
        }else{
            revert("Non");
        }

        require(msg.sender!=_tradeMes[_id].buyerAddress || msg.sender!=_tradeMes[_id].sellerAddress,"Same address");
        //清算时间24h前不能买入或卖出
        require(block.timestamp<=getClearTime()-1 days,"Not time");
        TimeLibrary.tradeMes memory maxTradeMes=_tradeMes[_id];

        address _tokenAddress=maxTradeMes.usedToken;
        uint256 _tokenOneAmount=maxTradeMes.tokenOneAmount;
        uint256 total=TimeLibrary.getTotalStable(maxTradeMes.price,maxTradeMes.amount,_tokenOneAmount);
        //质押违约金
        IERC20(_tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            total
        );

        //授权给AAVE V3的pool
        IERC20(_tokenAddress).approve(address(AaveV3Pool),total);
        //供应到AAVE V3
        AaveV3Pool.supply(
            _tokenAddress,       //供应的token地址
            total,               //供应数量
            getTimeCatpitalPool(),       //接收a token地址
            0                    //当前referralCode=0
        );
        if(maxTradeMes._tradeState==TimeLibrary.tradeState.buying){
            _tradeMes[_id].sellerAddress=msg.sender;
        }else if(maxTradeMes._tradeState==TimeLibrary.tradeState.selling){
            _tradeMes[_id].buyerAddress=msg.sender;
        }else{
            revert("Trade error");
        }
        
        _tradeMes[_id]._tradeState=TimeLibrary.tradeState.found;
        _userDeposite[_id][msg.sender].tradeId=_id;
        _userDeposite[_id][msg.sender].startTime=uint56(block.timestamp);
        _userDeposite[_id][msg.sender].endTime=0;
        _userDeposite[_id][msg.sender].depositeAmount=total;
        _userDeposite[_id][msg.sender].earnAmount=0;
        _userDeposite[_id][msg.sender].user=msg.sender;
        totalStable+=total;
        require(IERC721(timeERC721).marketMint(msg.sender,_id,total,doState,_tokenAddress));
    }

    //取消订单
    function cancelOrder(uint32 _id,address aToken)external{
        require(judgeInputAToken(aToken)==1,"Non allowed token");
        require(_tradeMes[_id]._tradeState==TimeLibrary.tradeState.buying ||
        _tradeMes[_id]._tradeState==TimeLibrary.tradeState.selling,"Invalid order");
        require(block.timestamp<=getClearTime()-1 days,"Time closed");
        uint256 _depositeAmount=_userDeposite[_id][msg.sender].depositeAmount;
        uint256 userNftId=IERC721(timeERC721).getuserTradeNftId(msg.sender,_id);
        require(_depositeAmount>0,"Not deposite");
        address usedToken=_tradeMes[_id].usedToken;
        address timeCapitalPool=getTimeCatpitalPool();
        //从timeCapitalPool取回a token
        ITimeCapitalPool(timeCapitalPool).approveMarket(aToken,_depositeAmount);
        IERC20(aToken).safeTransferFrom(timeCapitalPool,address(this),_depositeAmount);
        //授权给AaveV3Pool
        IERC20(aToken).approve(address(AaveV3Pool),_depositeAmount);
        //从aave v3提取供应的代币数量
        AaveV3Pool.withdraw(
            usedToken,
            _depositeAmount,
            msg.sender
        );
        _userDeposite[_id][msg.sender].depositeAmount=0;
        _tradeMes[_id]._tradeState=TimeLibrary.tradeState.inexistence;
        require(IERC721(timeERC721).burnNft(userNftId),"Burn fail");
    }

    //交易未达成,退款
    function refund(uint32 _id,address aToken)external{
        require(judgeInputAToken(aToken)==1,"Non allowed token");
        require(block.timestamp>getClearTime(),"Time has not arrived");
        require(
            _tradeMes[_id]._tradeState==TimeLibrary.tradeState.buying || 
            _tradeMes[_id]._tradeState==TimeLibrary.tradeState.selling
        );
        uint256 _depositeAmount=_userDeposite[_id][msg.sender].depositeAmount;
        uint256 userNftId=IERC721(timeERC721).getuserTradeNftId(msg.sender,_id);
        address _usedToken=_tradeMes[_id].usedToken;
        address timeCapitalPool=getTimeCatpitalPool();
        //从timeCapitalPool取回a token
        ITimeCapitalPool(timeCapitalPool).approveMarket(aToken,_depositeAmount);
        IERC20(aToken).safeTransferFrom(timeCapitalPool,address(this),_depositeAmount);

        //授权给AaveV3Pool
        IERC20(aToken).approve(address(AaveV3Pool),_depositeAmount);
        uint256 beforeAmount=IERC20(_usedToken).balanceOf(msg.sender);
        //从aave v3提取供应的代币数量
        AaveV3Pool.withdraw(
            _usedToken,
            _depositeAmount,
            msg.sender
        );
        uint256 afterAmount=IERC20(_usedToken).balanceOf(msg.sender);
        _userDeposite[_id][msg.sender].depositeAmount=0;
        _tradeMes[_id]._tradeState=TimeLibrary.tradeState.inexistence;
        require(IERC721(timeERC721).burnNft(userNftId),"Burn fail");
        emit RefundEvent(_id,afterAmount-beforeAmount,msg.sender);
    }

    //交易达成,支付期权token
    function deposite(uint32 _id)external{
        require(_tradeMes[_id]._tradeState==TimeLibrary.tradeState.found,"Not found");
        address seller=_tradeMes[_id].sellerAddress;
        require(msg.sender==seller,"Not the seller");
        uint256 targetTokenAmount=_tradeMes[_id].amount;
        address targetToken=getTargetToken();
        IERC20(targetToken).safeTransferFrom(msg.sender,address(this),targetTokenAmount);
        _tradeMes[_id]._tradeState=TimeLibrary.tradeState.done;
        require(IERC721(timeERC721).marketMint(msg.sender,_id,targetTokenAmount,2,targetToken));
    }

    //判断传入token是否允许
    function judgeInputStableToken(address inputToken)private view returns(uint256 state){
        address[] memory allowedTokens=ITimeGovern(timeGovern).getAllowedStableToken();
        state=TimeLibrary.judgeInputToken(inputToken,allowedTokens);
    }

    //判断传入的a token是否允许
    function judgeInputAToken(address inputAToken)private view returns(uint256 state){
        address[] memory allowedATokens=ITimeGovern(timeGovern).getAllowedATokens();
        state=TimeLibrary.judgeInputToken(inputAToken,allowedATokens);
    }

    //根据交易id获取到购买者
    function getBuyer(uint32 _id)private view returns(address){
        return _tradeMes[_id].buyerAddress;
    }

    //根据交易id获取到出售者
    function getSeller(uint32 _id)private view returns(address){
        return _tradeMes[_id].sellerAddress;
    }

    //得到奖励池地址
    function getTimeCatpitalPool()private view returns(address){
        address capitalPool=ITimeCapitalPoolFactory(timeCapitalPoolFactory).getCapitalPool(thisMarketId);
        require(capitalPool!=address(0),"ZeroAddress");
        return capitalPool;
    }

    //返回当前清算时间
    function getClearTime()private view returns(uint256){
       return ITimeGovern(timeGovern).getClearingTime(thisMarketId);
    }

    //返回当前目标token
    function getTargetToken()private view returns(address){
        return ITimeGovern(timeGovern).getTargetToken(thisMarketId);
    }

    //根据交易id得到_tradeMes
    function getTradeMes(uint32 _id)external view returns(TimeLibrary.tradeMes memory){
        return _tradeMes[_id];
    }

    //得到用户deposite
    function getUserDeposite(uint32 _id,address userAddress)external view returns(TimeLibrary.userDeposite memory){
        return _userDeposite[_id][userAddress];
    }

}