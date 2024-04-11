const hre = require("hardhat");
const market = require()
async function main() {
  const [owner1,owner2]=await hre.ethers.getSigners();

  //部署测试token
  const TestTokenDepoly = await hre.ethers.deployContract("TestTimeToken");
  await TestTokenDepoly.deployed();
  //部署合约的合约地址
  console.log("Test Token:", TestTokenDepoly.address);

  //部署TimeGovern
  const TimeGovern = await hre.ethers.deployContract("TimeGovern");
  await TimeGovern.deployed();
  //部署合约的合约地址
  console.log("TimeGovern:", TimeGovern.address);

  const allowStableTokens = [
    "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8",
    "0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0"
  ]
  const allowATokens=[
    "0x16dA4541aD1807f4443d92D26044C1147406EB80",
    "0xAF0F6e8b0Dc5c913bbF4d14c22B4E78Dd14310B6"
  ]

  //set Token
  const setTokens=await TimeGovern.setAllowToken(allowATokens,allowStableTokens);
  await setTokens.wait();
  console.log("设置tokens成功");

  //部署TimeMarketFactory
  const TimeMarketFactory = await hre.ethers.deployContract("TimeMarketFactory");
  await TimeMarketFactory.deployed();
  //部署合约的合约地址
  console.log("TimeMarketFactory:", TimeMarketFactory.address);

  //创建market
  const createMarket = await TimeMarketFactory.createMarket();
  await createMarket.wait();
  console.log("创建市场成功");

  //得到市场0
  const thisMarket = await TimeMarketFactory.getMarket(0);
  console.log("市场0地址:",thisMarket);

  //部署TimeCapitalPoolFactory
  const TimeCapitalPoolFactory = await hre.ethers.deployContract("TimeCapitalPoolFactory");
  await TimeCapitalPoolFactory.deployed();
  //部署合约的合约地址
  console.log("TimeCapitalPoolFactory:", TimeCapitalPoolFactory.address);

  //创建capitalPool(0)
  const createCapitalPool = await TimeCapitalPoolFactory.createCapitalPool(thisMarket,0);
  await createCapitalPool.wait();
  console.log("创建capitalPool成功");

  //得到CapitalPool
  const thisCapitalPool = await TimeCapitalPoolFactory.getCapitalPool(0);
  console.log("capitalPool地址:",thisCapitalPool);

  //部署TimeERC721Storage
  const TimeERC721Storage = await hre.ethers.deployContract("TimeERC721Storage");
  await TimeERC721Storage.deployed();
  //部署合约的合约地址
  console.log("TimeERC721Storage:", TimeERC721Storage.address);

  //initialize
  const initializeStorage = await TimeERC721Storage.initialize(TimeCapitalPoolFactory.address);
  await initializeStorage.await();
  console.log("initializeStorage成功");


}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
