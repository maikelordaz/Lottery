const { expect, assert, use } = require("chai");
const { network, ethers, web3 } = require("hardhat");
const { Contract, BigNumber, providers } = require("ethers");
const { Web3Provider } = require("@ethersproject/providers");
const { constants, time } = require('@openzeppelin/test-helpers');
const { printGas, toDays } = require("./utils");
const { latest } = require("@openzeppelin/test-helpers/src/time");

describe("Lottery", function () {

  // CONTRACT //
    let Lottery;
    let lottery;
  // TOKENS ACCEPTED //
    const dai = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
    const usdc = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
    const usdt = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
  // LINK TO FUND CONTRACT //
  const link = "0x514910771AF9Ca656af840dff83E8264EcF986CA";
  // LOTTERIES //
    const price = 10;
    const _numberOfLotteries = 2;
  // SIGNERS //    
    let owner;
    let player1;
    let player2;
    let player3;    
    
// BEFORE EACH TEST //
  
beforeEach(async function () {
    // THE CONTRACT IS INITIALIZED //    
    Lottery = await ethers.getContractFactory("Lottery");
    // THE INTERFACES ARE INITIALIZED //
    DAI = await ethers.getContractAt("IERC20Upgradeable", dai);
    USDC = await ethers.getContractAt("IERC20Upgradeable", usdc);
    USDT = await ethers.getContractAt("IERC20Upgradeable", usdt);  
    // THE ACCOUNTS AND SIGNERS ARE INITIALIZED // 
    [owner, player1, player2, player3] = await ethers.getSigners();
  
  });
// START OF THE TESTS //
it("Should deploy the lottery contract, first version, upgradeable", async function (){
  lottery = await upgrades.deployProxy(Lottery);
  await lottery.deployed(); 
  const lotteryAddress = lottery.address;
  console.log(lotteryAddress);
      // IMPERSONATE ACCOUNT TO FUND THE CONTRACT WITH LINK //
      /*
      await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: ["0xbe6977E08D4479C0A6777539Ae0e8fa27BE4e9d6"],
        });
      const signer = await ethers.getSigner("0xbe6977E08D4479C0A6777539Ae0e8fa27BE4e9d6")
      signer.sendTransaction(); 
      LINK = await ethers.getContractAt("IERC20Upgradeable", link); 
      await LINK.connect(signer).transfer(lottery.address, 10);
      */ 
      
});  
it("Should set the right owner of the lottery", async function (){
  expect(await lottery.owner()).to.equal(owner.address);
});
it("Should set the fee", async function (){
  const _fee = BigNumber.from(5);
  await lottery.setFee(_fee);
});
it("Should set the ticket price to 10 DAI", async function (){
  await lottery.setTicketPrice(price);
});
it("Should get the actual ticket price", async function (){
  const expectedPrice = await lottery.getTicketPrice();
  console.log("Ticket Price", expectedPrice);
});
it("Should fail to buy a ticket if there is no lotteries actives", async function (){
  await expect(lottery.buyTicket(10, dai)).
  to.be.revertedWith("There are no lotteries active right now");
});
it("Should start the lotteries", async function (){
  await lottery.startLottery(_numberOfLotteries);
});
it("Should fail to buy a ticket if the token is incorrect", async function (){
  await expect(lottery.buyTicket(price, constants.ZERO_ADDRESS)).
    to.be.revertedWith("We only accept DAI, USDT or USDC tokens.");
});
it("Should fail to buy a ticket if the payment is less than needed", async function (){
    await expect(lottery.buyTicket(0, dai)).
      to.be.revertedWith("You have to buy at least one ticket.");
});
it("Should buy tickets to the actual lottery with DAI", async function (){
  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: ["0x1e3D6eAb4BCF24bcD04721caA11C478a2e59852D"],
    });
  const daiBuyer = await ethers.getSigner("0x1e3D6eAb4BCF24bcD04721caA11C478a2e59852D")
  daiBuyer.sendTransaction();
  await DAI.connect(daiBuyer).approve(lottery.address, 50); 
  await lottery.connect(daiBuyer).buyTicket(50, dai);  
});

})
