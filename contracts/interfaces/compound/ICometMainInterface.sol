// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.15;

/**
 * @title Compound's Comet Main Interface (without Ext)
 * @notice An efficient monolithic money market protocol
 * @author Compound
 */
interface ICometMainInterface {
    
    struct AssetInfo {
        uint8 offset;
        address asset;
        address priceFeed;
        uint64 scale;
        uint64 borrowCollateralFactor;
        uint64 liquidateCollateralFactor;
        uint64 liquidationFactor;
        uint128 supplyCap;
    }


    function supply(address asset, uint amount) external;
    function supplyTo(address dst, address asset, uint amount) external;
    function supplyFrom(address from, address dst, address asset, uint amount) external;

    function transfer(address dst, uint amount) external returns (bool);
    function transferFrom(address src, address dst, uint amount) external returns (bool);

    function transferAsset(address dst, address asset, uint amount) external;
    function transferAssetFrom(address src, address dst, address asset, uint amount) external;

    function withdraw(address asset, uint amount) external;
    function withdrawTo(address to, address asset, uint amount) external;
    function withdrawFrom(address src, address to, address asset, uint amount) external;

    function approveThis(address manager, address asset, uint amount) external;
    function withdrawReserves(address to, uint amount) external;

    function absorb(address absorber, address[] calldata accounts) external;
    function buyCollateral(address asset, uint minAmount, uint baseAmount, address recipient) external;
    function quoteCollateral(address asset, uint baseAmount) external view returns (uint);

    function getAssetInfo(uint8 i) external view returns (AssetInfo memory);
    function getAssetInfoByAddress(address asset) external view returns (AssetInfo memory);
    function getCollateralReserves(address asset) external view returns (uint);
    function getReserves() external view returns (int);
    function getPrice(address priceFeed) external view returns (uint);

    function isBorrowCollateralized(address account) external view returns (bool);
    function isLiquidatable(address account) external view returns (bool);

    function totalSupply() external view returns (uint256);
    function totalBorrow() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function borrowBalanceOf(address account) external view returns (uint256);

    function pause(bool supplyPaused, bool transferPaused, bool withdrawPaused, bool absorbPaused, bool buyPaused) external;
    function isSupplyPaused() external view returns (bool);
    function isTransferPaused() external view returns (bool);
    function isWithdrawPaused() external view returns (bool);
    function isAbsorbPaused() external view returns (bool);
    function isBuyPaused() external view returns (bool);

    function accrueAccount(address account) external;
    function getSupplyRate(uint utilization) external view returns (uint64);
    function getBorrowRate(uint utilization) external view returns (uint64);
    function getUtilization() external view returns (uint);

    function governor() external view returns (address);
    function pauseGuardian() external view returns (address);
    function baseToken() external view returns (address);
    function baseTokenPriceFeed() external view returns (address);
    function extensionDelegate() external view returns (address);
    function baseIndexScale() external pure returns (uint64);

    /// @dev uint64
    function supplyKink() external view returns (uint);
    /// @dev uint64
    function supplyPerSecondInterestRateSlopeLow() external view returns (uint);
    /// @dev uint64
    function supplyPerSecondInterestRateSlopeHigh() external view returns (uint);
    /// @dev uint64
    function supplyPerSecondInterestRateBase() external view returns (uint);
    /// @dev uint64
    function borrowKink() external view returns (uint);
    /// @dev uint64
    function borrowPerSecondInterestRateSlopeLow() external view returns (uint);
    /// @dev uint64
    function borrowPerSecondInterestRateSlopeHigh() external view returns (uint);
    /// @dev uint64
    function borrowPerSecondInterestRateBase() external view returns (uint);
    /// @dev uint64
    function storeFrontPriceFactor() external view returns (uint);

    /// @dev uint64
    function baseScale() external view returns (uint);
    /// @dev uint64
    function trackingIndexScale() external view returns (uint);

    /// @dev uint64
    function baseTrackingSupplySpeed() external view returns (uint);
    /// @dev uint64
    function baseTrackingBorrowSpeed() external view returns (uint);
    /// @dev uint104
    function baseMinForRewards() external view returns (uint);
    /// @dev uint104
    function baseBorrowMin() external view returns (uint);
    /// @dev uint104
    function targetReserves() external view returns (uint);

    function numAssets() external view returns (uint8);
    function decimals() external view returns (uint8);

    function initializeStorage() external;
}