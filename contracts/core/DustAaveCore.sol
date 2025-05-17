// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {Dust} from "./Dust.sol";
import {IDustCore} from "../interfaces/IDustCore.sol";

import {IPool} from "../interfaces/aave/IPool.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title DUST Stablecoin core contract
 * @notice The collateral will directly enter compoundV3 to generate additional benefits for DUST. Meanwhile,
 * any Token can be used to perform secure transfers and stream payments with the help of DUST's Flow feature
 * @author One of the members of VineLabs, 0xlive
 */

contract DustAaveCore is Dust, ReentrancyGuard, IDustCore {
    using SafeERC20 for IERC20;

    bytes1 private immutable ZEROBYTES1;
    bytes1 private immutable ONEBYTES1 = 0x01;
    bytes1 public lockState;
    bytes1 public initializeState;
    uint16 private constant MINIMUM_LIQUIDITY = 10000;
    uint16 public referralCode;
    uint16 public feeRate;
    address public owner;
    address public manager;
    address public collateral;
    address public aToken;
    address public feeReceiver;
    address public aavePool;
    address public dustPool;

    uint256 public flowId;
    uint256 public totalCollateral;

    constructor(
        address _aavePool,
        address _aToken,
        address _owner, 
        address _manager, 
        address _feeReceiver, 
        uint16 _feeRate
    ) {
        aavePool = _aavePool;
        aToken = _aToken;
        owner = _owner;
        manager = _manager;
        feeReceiver = _feeReceiver;
        feeRate = _feeRate;
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    modifier onlyManager() {
        _checkManager();
        _;
    }

    modifier Lock() {
        require(lockState == ZEROBYTES1, "Locked");
        _;
    }


    mapping(address => bool) private blacklist;
    mapping(uint256 => DustFlowInfo) private dustFlowInfo;
    mapping(address => mapping(UserFlowState => uint256[])) private userFlowId;

    function transferOwner(address _newOwner) external onlyOwner {
        address olderOwner = owner;
        owner = _newOwner;
        emit ChangeOwner(olderOwner, owner);
    }

    function transferManager(address _newManager) external onlyOwner {
        address olderManager = manager;
        manager = _newManager;
        emit ChangeManager(olderManager, manager);
    }

    function setAave(
        uint16 _referralCode,
        address _aavePool, 
        address _aToken
    ) external onlyOwner {
        referralCode = _referralCode;
        aavePool = _aavePool;
        aToken = _aToken;
        emit UpdateAave(referralCode, aavePool);
    }
    
    function setFeeInfo(
        uint16 _feeRate,
        address _feeReceiver, 
        address _dustPool
    ) external onlyOwner {
        require(_feeRate <= 10000);
        feeReceiver = _feeReceiver;
        dustPool = _dustPool;
        feeRate = _feeRate;
        emit ChangeFeeInfo(_feeReceiver, _feeRate);
    }

    function initialize(address thisCollateral) external onlyManager {
        require(initializeState == ZEROBYTES1);
        collateral = thisCollateral;
        initializeState = ONEBYTES1;
        emit Initialize(initializeState);
    }

    function setLockState(bytes1 state) external onlyManager {
        lockState = state;
        emit LockEvent(state);
    }

    function setBlacklist(
        address[] calldata blacklistGroup, 
        bool[] calldata states
    ) external onlyManager {
        unchecked {
            for(uint256 i; i<blacklistGroup.length; i++){
                blacklist[blacklistGroup[i]] = states[i];
                emit Blacklist(blacklistGroup[i], states[i]);
            }
        }
    }

    function mintDust(
        uint256 amount
    ) external Lock nonReentrant {
        _checkBlacklist(msg.sender);
        uint256 mintAmount;
        uint8 collateralDecimals = _getTokenDecimals(collateral);
        uint8 dustDecimals = decimals();
        if(collateralDecimals > 0){
            if(collateralDecimals > decimals()){
                mintAmount = amount / 10 ** (collateralDecimals - dustDecimals);
            }else if(collateralDecimals < decimals()){
                mintAmount = amount * 10 ** (collateralDecimals - dustDecimals);
            }else{
                mintAmount = amount;
            }
        }
        if(mintAmount < 10 ** dustDecimals){
            revert AmountErr(0x00);
        }
        IERC20(collateral).safeTransferFrom(msg.sender, address(this), amount);
        uint256 collateralBalance = _getUserTokenBalance(collateral, address(this));
        if(collateralBalance > 0){
            IERC20(collateral).approve(aavePool, collateralBalance);
            emit MintDUST(msg.sender, amount, mintAmount);
            if(_mint(msg.sender, mintAmount) != true){
                revert MintErr("Mint fail");
            }
            totalCollateral += amount;
            if(_aaveSupply(collateral, collateralBalance) != true){
                revert AaveSupplyErr("Supply fail");
            }
        }else {
            revert AmountErr(0x00);
        }
    }

    function refund(
        uint256 amount
    ) external nonReentrant {
        uint256 refundAmount;
        uint8 collateralDecimals = _getTokenDecimals(collateral);
        uint8 dustDecimals = decimals();
        if(collateralDecimals > 0){
            if(collateralDecimals > decimals()){
                refundAmount = amount * 10 ** (collateralDecimals - dustDecimals);
            }else if(collateralDecimals < decimals()){
                refundAmount = amount / 10 ** (collateralDecimals - dustDecimals);
            }else{
                refundAmount = amount;
            }
        }
        if(refundAmount == 0){
            revert AmountErr(0x00);
        }
        uint256 uint256Max = type(uint256).max;
        if(_aaveWithdraw(collateral, uint256Max) != true){
            revert AaveWithdrawErr("Withdraw fail");
        }
        IERC20(collateral).safeTransfer(msg.sender, refundAmount);
        totalCollateral -= refundAmount;

        uint256 collateralAfterBalance = _getUserTokenBalance(collateral, address(this));
        if(collateralAfterBalance > 0){
            IERC20(collateral).approve(aavePool, collateralAfterBalance);
            if(_aaveSupply(collateral, collateralAfterBalance) != true){
                revert AaveSupplyErr("Supply fail");
            }
        }
        emit Refund(msg.sender, refundAmount, amount);
        if(_burn(msg.sender, amount) != true){
            revert BurnErr("Burn fail");
        }
    }

    function flow(
        FlowWay way,
        uint64 endTime,
        uint128 amount,
        address receiver,
        address token
    ) external nonReentrant {
        _checkBlacklist(receiver);
        uint64 currentTime = uint64(block.timestamp);
        uint64 thisEndTime = currentTime + endTime;
        require(receiver != address(0) && receiver != address(this) && receiver != msg.sender);
        if (way == FlowWay.doTransfer) {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            IERC20(token).safeTransfer(receiver, amount);
        } else if (way == FlowWay.flow) {
            if(amount < 10 ** 18){
                revert AmountErr(0x00);
            }
            require(thisEndTime - 60 >= currentTime, "Invalid endTime");
            userFlowId[msg.sender][UserFlowState.sendFlow].push(flowId);
            userFlowId[receiver][UserFlowState.receiveFlow].push(flowId);
            if(token == address(this)){
                if(_burn(msg.sender, amount) != true){
                    revert BurnErr("Burn fail");
                }
            }else{
                IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
                if(token == collateral){
                    uint256 collateralBalance = _getUserTokenBalance(collateral, address(this));
                    if(collateralBalance > 0){
                        IERC20(collateral).approve(aavePool, collateralBalance);
                        if(_aaveSupply(collateral, collateralBalance) != true){
                            revert AaveSupplyErr("Supply fail");
                        }
                        totalCollateral += amount;
                    }else {
                        revert AmountErr(0x00);
                    }
                }
            }
            dustFlowInfo[flowId] = DustFlowInfo({
                way: way,
                sender: msg.sender,
                receiver: receiver,
                flowToken: token,
                startTime: currentTime,
                endTime: thisEndTime,
                amount: amount,
                doneAmount: 0,
                lastestWithdrawTime: 0
            });
            flowId++;
        } else {
            revert("Invalid way");
        }
        emit Flow(way, msg.sender, receiver, amount);
    }

    function receiveDustFlow(uint256 id) external nonReentrant {
        address receiver = dustFlowInfo[id].receiver;
        address token = dustFlowInfo[id].flowToken;
        require(msg.sender == receiver, "Not this receiver");
        uint128 withdrawAmount = getReceiveAmount(id);
        if(withdrawAmount == 0 || (dustFlowInfo[id].doneAmount + withdrawAmount > dustFlowInfo[id].amount)){
            revert AmountErr(0x00);
        }
        dustFlowInfo[id].doneAmount += withdrawAmount;
        dustFlowInfo[id].lastestWithdrawTime = block.timestamp;
        if(token == address(this)){
            if(_mint(receiver, withdrawAmount) != true){
                revert MintErr("Mint fail");
            }
        }else {
            if(token == collateral){
                uint256 uint256Max = type(uint256).max;
                if(_aaveWithdraw(collateral, uint256Max) != true){
                    revert AaveWithdrawErr("Withdraw fail");
                }
                IERC20(collateral).safeTransfer(msg.sender, withdrawAmount);
                totalCollateral -= withdrawAmount;
                uint256 collateralAfterBalance = _getUserTokenBalance(collateral, address(this));
                if(collateralAfterBalance > 0){
                    IERC20(collateral).approve(aavePool, collateralAfterBalance);
                    if(_aaveSupply(collateral, collateralAfterBalance) != true){
                        revert AaveSupplyErr("Supply fail");
                    }
                }
            }else{
                IERC20(token).safeTransfer(receiver, withdrawAmount);
            }
        }
        emit FlowReceive(receiver, token, withdrawAmount);
    }

    function _checkOwner() private view {
        require(msg.sender == owner);
    }

    function _checkManager() private view {
        require(msg.sender == manager);
    }

    function _checkBlacklist(address user) private view {
        require(blacklist[user] == false, "blacklist");
    }

    function _aaveSupply(address asset, uint256 amount) private returns (bool state) {
        IPool(aavePool).deposit(asset, amount, address(this), referralCode);
        state = true;
    }

    function _aaveWithdraw(address asset, uint256 amount) private returns (bool state) {
        // uint256 aTokenBalance = _getUserTokenBalance(aToken, address(this));
        IERC20(aToken).approve(aavePool, amount);
        IPool(aavePool).withdraw(asset, amount, address(this));
        uint256 currentCollateralBalance = _getUserTokenBalance(collateral, address(this));
        if(currentCollateralBalance > totalCollateral + MINIMUM_LIQUIDITY){
            uint256 profit = currentCollateralBalance - totalCollateral - MINIMUM_LIQUIDITY;
            IERC20(collateral).safeTransfer(feeReceiver, profit * (10000 - feeRate) / 10000);
            IERC20(collateral).safeTransfer(dustPool, profit * feeRate / 10000);
        }
        state = true;
    }

    function _getTokenDecimals(
        address token
    ) private view returns (uint8 thisDecimals) {
        thisDecimals = IERC20Metadata(token).decimals();
    }

    function _getUserTokenBalance(
        address token,
        address user
    ) private view returns (uint256 userBalance) {
        userBalance = IERC20(token).balanceOf(user);
    }

    function getChainTimestamp() external view returns (uint256) {
        return block.timestamp;
    }

    function getUserFlowId(
        address user, 
        UserFlowState state, 
        uint256 index
    ) external view returns (uint256) {
        return userFlowId[user][state][index];
    }

    function getUserFlowIdsLength(address user, UserFlowState state) external view returns (uint256) {
        return userFlowId[user][state].length;
    }

    function getDustFlowInfo(
        uint256 id
    ) external view returns (DustFlowInfo memory) {
        return dustFlowInfo[id];
    }

    function getTokenDecimals(address token) external view returns (uint8) {
        return _getTokenDecimals(token);
    }

    function getTokenBalance(
        address token,
        address user
    ) external view returns (uint256) {
        return _getUserTokenBalance(token, user);
    }

    function getReceiveAmount(
        uint256 id
    ) public view returns (uint128 remainAmount) {
        uint64 startTime = dustFlowInfo[id].startTime;
        uint64 endTime = dustFlowInfo[id].endTime;
        uint128 amount = dustFlowInfo[id].amount;
        uint128 doneAmount = dustFlowInfo[id].doneAmount;
        uint256 lastestWithdrawTime = dustFlowInfo[id].lastestWithdrawTime;
        if(endTime - startTime > 0){
            if(amount >= doneAmount){
                uint128 quantityPerSecond = amount / (endTime - startTime);
                if (block.timestamp >= endTime) {
                    remainAmount = amount - doneAmount;
                } else {
                    if(lastestWithdrawTime == 0){
                        remainAmount = uint128((block.timestamp - startTime) *
                        quantityPerSecond);
                    }else{
                        if(lastestWithdrawTime > startTime && lastestWithdrawTime < endTime) {
                            remainAmount = uint128((block.timestamp - lastestWithdrawTime) *
                        quantityPerSecond);
                        }
                    }
                    
                }
            }
        }
    }

    
}
