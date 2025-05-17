const hre = require("hardhat");
const fs = require("fs");

const GovernanceABI = require("../artifacts/contracts/core/Governance.sol/Governance.json");
const DustFlowFactoryABI = require("../artifacts/contracts/core/DustFlowFactory.sol/DustFlowFactory.json");
const DustFlowCoreABI = require("../artifacts/contracts/core/DustFlowCore.sol/DustFlowCore.json");
const DustCoreABI = require("../artifacts/contracts/core/DustCore.sol/DustCore.json");
const DustAaveCoreABI = require("../artifacts/contracts/core/DustAaveCore.sol/DustAaveCore.json");
const ERC20ABI = require("../artifacts/contracts/TestToken.sol/TestToken.json");
const DustFlowHelperABI = require("../artifacts/contracts/helper/DustFlowHelper.sol/DustFlowHelper.json");
const Set = require("../set.json");

async function main() {
  const [owner] = await hre.ethers.getSigners();
  console.log("owner:", owner.address);

  const provider = ethers.provider;
  const network = await provider.getNetwork();
  const chainId = network.chainId;
  console.log("Chain ID:", chainId);

  const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
  let config = {};

  async function sendETH(toAddress, amountInEther) {
    const amountInWei = ethers.parseEther(amountInEther);
    const tx = {
      to: toAddress,
      value: amountInWei,
    };
    const transactionResponse = await owner.sendTransaction(tx);
    await transactionResponse.wait();
    console.log("Transfer eth success");
  }

  let allAddresses = {};
  let chainConfig;
  let USDCAddress;
  let DustCore;
  let DustCoreAddress;
  let ThisDustCoreABI;
  if (chainId === 1n || chainId === 11155111n) {
    chainConfig = Set["Ethereum_Sepolia"];
    USDCAddress = chainConfig.USDC;
  } else if (chainId === 42161n || chainId === 421614n) {
    chainConfig = Set["Arbitrum_Sepolia"];
    USDCAddress = chainConfig.USDC;
  } else if (chainId === 43114n || chainId === 43113n) {
    chainConfig = Set["Avalanche_Fuji"];
    USDCAddress = chainConfig.USDC;
  } else if (chainId === 8453n || chainId === 84532n) {
    chainConfig = Set["Base_Sepolia"];
    USDCAddress = chainConfig.USDC;
  } else if (chainId === 10n || chainId === 11155420n) {
    chainConfig = Set["Op_Sepolia"];
    USDCAddress = chainConfig.USDC;
  } else {
    // const usdc = await ethers.getContractFactory("TestToken");
    // const USDC = await usdc.deploy("DustFlow Test USDC", "USDC");
    // USDCAddress = await USDC.target;
    USDCAddress = "0xB3aDc46252C2abd33903854A6D5bD37500eAD989";
    console.log("USDC Address:", USDCAddress);
  }
  // const testToken = await ethers.getContractFactory("TestToken");
  // const DTT = await testToken.deploy("DustFlow Test Token", "DTT");
  // const DTTAddress = await DTT.target;
  const DTTAddress = "0xfbF60F3cc210f7931c3c15920CC71A03C0B4dAc3";
  console.log("DTT Address:", DTTAddress);

  if (chainId === 57054n || chainId === 688688n) {
    // const dustCore = await ethers.getContractFactory("DustCore");
    // DustCore = await dustCore.deploy(
    //   owner.address,
    //   owner.address,
    //   owner.address,
    //   5000
    // );
    // DustCoreAddress = await DustCore.target;
    ThisDustCoreABI = DustCoreABI;
  } else if (chainId === 421614n) {
    const dustCore = await ethers.getContractFactory("DustAaveCore");
    DustCore = await dustCore.deploy(
      chainConfig.AaveV3Pool,
      chainConfig.AUSDC,
      owner.address,
      owner.address,
      owner.address,
      5000
    );
    DustCoreAddress = await DustCore.target;
    ThisDustCoreABI = DustAaveCoreABI;
  }
  DustCoreAddress = "0xe082b5a1F1aEf5fA15e4B9ACB2bDa74A2a0BDE3e";
  DustCore = new ethers.Contract(DustCoreAddress, ThisDustCoreABI.abi, owner);
  console.log("DustCore Address:", DustCoreAddress);

  const initializeState = await DustCore.initializeState();
  if (initializeState === "0x00") {
    const initialize = await DustCore.initialize(USDCAddress);
    const initializeTx = await initialize.wait();
    console.log("initialize:", initializeTx.hash);
  }

  // const dustPool = await ethers.getContractFactory("DustPool");
  // const DustPool = await dustPool.deploy(
  //   owner.address,
  //   owner.address,
  //   DustCoreAddress,
  //   USDCAddress
  // );
  // const DustPoolAddress = await DustPool.target;
  const DustPoolAddress = "0xd4F132a55e8cdd7A41603F378f45972fF8F34848";
  console.log("DustPoolAddress:", DustPoolAddress);

  // const governance = await ethers.getContractFactory("Governance");
  // const Governance = await governance.deploy(
  //   owner.address,
  //   owner.address,
  //   DustCoreAddress,
  //   DustPoolAddress,
  //   owner.address
  // );
  // const GovernanceAddress = await Governance.target;
  const GovernanceAddress = "0x422D8dF4b5a46421AdCe47363DC460d0D5136667";
  const Governance = new ethers.Contract(
    GovernanceAddress,
    GovernanceABI.abi,
    owner
  );
  console.log("Governance Address:", GovernanceAddress);

  const setMarketConfig = await Governance.setMarketConfig(
    0,
    864000n,
    DTTAddress
  );
  const setMarketConfigTx = await setMarketConfig.wait();
  console.log("setMarketConfigTx:", setMarketConfigTx.hash);

  const getMarketConfig = await Governance.getMarketConfig(0);
  console.log("getMarketConfig:", getMarketConfig);

  // const dustFlowFactory = await ethers.getContractFactory("DustFlowFactory");
  // const DustFlowFactory = await dustFlowFactory.deploy(GovernanceAddress);
  // const DustFlowFactoryAddress = await DustFlowFactory.target;
  const DustFlowFactoryAddress = "0x183598b50174566b46bd419b392c1B8FC9087cB3";
  const DustFlowFactory = new ethers.Contract(
    DustFlowFactoryAddress,
    DustFlowFactoryABI.abi,
    owner
  );
  console.log("DustFlowFactory Address:", DustFlowFactoryAddress);

  // const dustFlowHelper = await ethers.getContractFactory("DustFlowHelper");
  // const DustFlowHelper = await dustFlowHelper.deploy(
  //   GovernanceAddress,
  //   DustFlowFactoryAddress
  // );
  // const DustFlowHelperAddress = await DustFlowHelper.target;
  const DustFlowHelperAddress = "0x0B89A5452bee7e40331af133379c24735E2001Ef";
  const DustFlowHelper = new ethers.Contract(
    DustFlowHelperAddress,
    DustFlowHelperABI.abi,
    owner
  );
  console.log("DustFlowHelper Address:", DustFlowHelperAddress);

  // const changeDustFlowFactory = await Governance.changeDustFlowFactory(
  //   DustFlowFactoryAddress
  // );
  // const changeDustFlowFactoryTx = await changeDustFlowFactory.wait();
  // console.log("changeDustFlowFactory:", changeDustFlowFactoryTx.hash);

  // const changeConfig = await DustFlowHelper.changeConfig(
  //   GovernanceAddress,
  //   DustFlowFactoryAddress,
  //   { gasLimit: 300000 }
  // );
  // const changeConfigTx = await changeConfig.wait();
  // console.log("changeConfig:", changeConfigTx.hash);

  const getMarketConfig0 = await Governance.getMarketConfig(0);
  console.log("getMarketConfig:", getMarketConfig0);

  if(getMarketConfig0[3] ===false){
    const initMarketConfig = await Governance.initMarketConfig(0);
    const initMarketConfigTx = await initMarketConfig.wait();
    console.log("initMarketConfigTx:", initMarketConfigTx.hash);
  }

  // const changeCollateral = await Governance.changeCollateral(
  //   0,
  //   DustCoreAddress,
  //   {
  //     gasLimit: 100000,
  //   }
  // );
  // const changeCollateralTx = await changeCollateral.wait();
  // console.log("changeCollateral:", changeCollateralTx.hash);

  // const changeCollateral2 = await Governance.changeCollateral(
  //     1,
  //     DustCoreAddress,
  //     {
  //       gasLimit: 100000,
  //     }
  //   );
  //   const changeCollateral2Tx = await changeCollateral2.wait();
  //   console.log("changeCollateral2:", changeCollateral2Tx.hash);

  // const createMarket1 = await DustFlowFactory.createMarket({
  //   gasLimit: 5200000
  // });
  // const createMarket1Tx = await createMarket1.wait();
  // console.log("createMarket1 tx:", createMarket1Tx.hash);

  const getMarketInfo1 = await DustFlowFactory.getMarketInfo(0n);
  console.log("getMarketInfo1:", getMarketInfo1);

  // const createMarket2 = await DustFlowFactory.createMarket(
  //   {gasLimit: 5200000}
  // );
  // const createMarket2Tx = await createMarket2.wait();
  // console.log("createMarket2 tx:", createMarket2Tx.hash);

  const getMarketInfo2 = await DustFlowFactory.getMarketInfo(1n);
  console.log("getMarketInfo2:", getMarketInfo2);

  const marketId = await DustFlowFactory.marketId();
  console.log("lastest marketId:", marketId);

  const Market = new ethers.Contract(
    getMarketInfo1[0],
    DustFlowCoreABI.abi,
    owner
  );

  async function Approve(token, spender, amount) {
    try {
      const tokenContract = new ethers.Contract(token, ERC20ABI.abi, owner);
      const allowance = await tokenContract.allowance(owner.address, spender);
      if (allowance < ethers.parseEther("10000")) {
        const approve = await tokenContract.approve(spender, amount);
        const approveTx = await approve.wait();
        console.log("approveTx:", approveTx.hash);
      } else {
        console.log("Not approve");
      }
    } catch (e) {
      console.log("e:", e);
    }
  }
  await Approve(
    DustCoreAddress,
    getMarketInfo1[0],
    ethers.parseEther("1000000000")
  );

  await Approve(USDCAddress, DustCoreAddress, ethers.parseEther("1000000000"));

  // const initMarketConfig2 = await Governance.initMarketConfig(1);
  // const initMarketConfig2Tx = await initMarketConfig2.wait();
  // console.log("initMarketConfig2:", initMarketConfig2Tx.hash);

  const setMarketConfig2 = await Governance.setMarketConfig(
    1,
    100000n,
    DTTAddress
  );
  const setMarketConfig2Tx = await setMarketConfig2.wait();
  console.log("setMarketConfig2Tx:", setMarketConfig2Tx.hash);

  // const mintDust = await DustCore.mintDust(
  //   10000n * 10n ** 18n
  // );
  // const mintDustTx = await mintDust.wait();
  // console.log("mintDust tx:", mintDustTx.hash);

  const OrderType = {
    buy: 0,
    sell: 1,
  };

  // const putTrade = await Market.putTrade(
  //   OrderType.sell,
  //   50n * 10n ** 18n,
  //   2n * 10n ** 5n,
  //   { gasLimit: 500000 }
  // );
  // const putTradeTx = await putTrade.wait();
  // console.log("putTradeTx:", putTradeTx.hash);

  // const matchTrade = await Market.matchTrade(
  //   OrderType.buy,
  //   50n * 10n ** 18n,
  //   2n * 10n ** 5n,
  //   [0],
  //   { gasLimit: 500000 }
  // );
  // const matchTradeTx = await matchTrade.wait();
  // console.log("matchTradeTx:", matchTradeTx.hash);

  //

  config.USDC = USDCAddress;
  config.DTT = DTTAddress;
  config.DustCore = DustCoreAddress;
  config.DustPool = DustPoolAddress;
  (config.Governance = GovernanceAddress),
    (config.DustFlowFactory = DustFlowFactoryAddress),
    (config.DustFlowHelper = DustFlowHelperAddress);
  (config.market0 = getMarketInfo1[0]),
    (config.market1 = getMarketInfo2[0]),
    (config.updateTime = new Date().toISOString());

  const filePath = "./deployedAddress.json";
  if (fs.existsSync(filePath)) {
    allAddresses = JSON.parse(fs.readFileSync(filePath, "utf8"));
  }
  allAddresses[chainId] = config;

  fs.writeFileSync(filePath, JSON.stringify(allAddresses, null, 2), "utf8");
  console.log("deployedAddress.json update:", allAddresses);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
