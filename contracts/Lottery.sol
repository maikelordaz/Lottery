//SPDX-License-Identifier: MIT
/**
* @title Lottery
* @author Maikel Ordaz.
* @notice a no loss lotery
* @dev this contract is upgradeable, and this is the first version.
*/
pragma solidity ^0.8.4;

// CONTRACTS INHERITED //
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
// INTERFACES USED //
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./interfaces/Compound.sol";
// LIBRARIES USED //
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

contract Lottery is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    using SafeMathUpgradeable for uint256;

// VARIABLES //

    uint256 public fee;
    uint256 public slippage;
    uint256 public ticketPrice;
    uint256 numberOfLotteries;
    address private UniswapV2Router02;
    // tokens accepted
    address private DAIaddress;
    IERC20Upgradeable public DAI;
    address private USDTaddress;
    IERC20Upgradeable USDT;
    address private USDCaddress;
    IERC20Upgradeable USDC;
    // token invested
    CErc20 public cDAI;


    struct player {
        address playerAddress; 
        uint256 DAIamount; // the amount of DAI after conversion.
        uint256 ticketsBuyed; // the amount of tockets the user has purchased.
        uint256 lotteryNumber; 
        bool playing; // sets true when the player register, set false when the player wins or retire.           
    }    
    struct lottery {
        uint256 pot;
        uint256 startDate;
        uint256 buyingDeadline;
        uint256 finishDate;
        uint256 prize;
        address winner;
    }

//EVENTS

    event newPlayer (
        address playerAddress, 
        uint256 DAIamount,
        uint256 ticketsBuyed,
        uint256 lotteryNumber,
        bool playing
    );    
    event newLottery (
        uint256 pot,
        uint256 startDate,
        uint256 buyingDeadline,
        uint256 finishDate,
        uint256 prize,
        address winner
    );
    
//MAPPINGS

    mapping(uint256 => player) private _idToPlayer;
    uint256 private _playerId;
    mapping(uint256 => lottery) private _idToLottery;
    uint256 private _lotteryId;

// FUNCTIONS //

    function initialize(uint256 _fee) 
    public
    initializer {
        require(_fee > 0);
        __Ownable_init(); 
        __ReentrancyGuard_init();
        UniswapV2Router02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
        DAIaddress = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        DAI = IERC20Upgradeable(DAIaddress);
        USDTaddress = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        USDCaddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; 
        cDAI = CErc20(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
        slippage = 5; 
        fee = _fee.div(100);
        _playerId = 0;
        _lotteryId = 0;     
    }
    /**
    * @notice a setter function to set the lottery ticket price.
    * @dev only the owner of the contract can change the fee.
    * @param _ticketPrice the lottery ticket price.
    */
    //---------------------------- Lottery settings --------------------------------------------//

    function setTicketPrice(uint256 _ticketPrice) 
    public
    onlyOwner {
        require(_ticketPrice > 0);
        ticketPrice = _ticketPrice;        
    }
    /**
    * @notice a getter function to get the ticket price.
    */
    function getTicketPrice()
    public
    view
    returns(uint256) {
        return ticketPrice;
    }
    /**
    * @notice a function to start the lottery process
    * @dev it makes a loop to create the lotteries and to register their dates on the corresponding
    * mapping.
    * @param _numberOfLotteries the number of lotteries the owner allow.
    */
    function startLottery(uint256 _numberOfLotteries)
    public
    onlyOwner {
        numberOfLotteries = _numberOfLotteries;
        for(uint256 i = 0; i <= numberOfLotteries ; i++) {
            _lotteryId++;
            _idToLottery[_lotteryId] = 
                lottery (0,
                        block.timestamp,
                        block.timestamp.add(2 days),
                        block.timestamp.add(7 days),
                        0,
                        address(0));
            emit newLottery(0, 
                            block.timestamp, 
                            block.timestamp.add(2 days), 
                            block.timestamp.add(7 days),
                            0,
                            address(0));                       
        }           
    }
    /**
    * @notice a function to swap betwen tokens to DAI.
    * @dev this is an auxiliar function.
    * @param _tokenIn is the address of the token that the user have.
    * @param _amountIn is the amount of tokens the user has. 
    */
    function _swapTokensForDAI(address _tokenIn, uint256 _amountIn)
    internal {            
            IERC20Upgradeable(_tokenIn).approve(UniswapV2Router02, _amountIn);
            uint256 _amountOutMin = _amountIn.mul(slippage).div(1000);
            address[] memory _path;
            _path = new address[](2);
            _path[0] = _tokenIn;
            _path[1] = DAIaddress;
            IUniswapV2Router02(UniswapV2Router02).
                swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    _amountIn, _amountOutMin, _path, address(this), block.timestamp + 1);                    
    }
    //----------------------------- Compound Investment ----------------------------------------//
    function potInvestment() 
    private {
        for(uint256 k = 0; k == numberOfLotteries; k++) {
            uint256 potToInvest = _idToLottery[k].pot;
            uint256 rightNow = block.timestamp;
            while(_idToLottery[k].finishDate < rightNow) {
                if(_idToLottery[k].buyingDeadline == rightNow) {
                    DAI.approve(address(cDAI), potToInvest);
                    require(cDAI.mint(potToInvest) == 0, "mint failed");                  
                } 
                if (_idToLottery[k].finishDate == rightNow) {
                    uint256 totalToRedeem = cDAI.balanceOf(address(this));
                    uint256 _prize = totalToRedeem.sub(potToInvest);
                    require(cDAI.redeem(totalToRedeem) == 0, "redeem failed");
                    _idToLottery[k].prize = _prize;
                }
            }
        }
    }
    //----------------------------- Player functions -------------------------------------------//
    /**
    * @notice a function to buy the lottery tickets.
    * @dev only DAI, USDT and USDC are accepted as payments.
    * @dev only an exact amount of tokens are needed. For example if the ticket price is 10 and
    * the player pay 25 tokens only 20 are used and the remaining 5 are given back to the player.
    * @param amountIn the amount of tokens the player pays.
    * @param tokenIn the token used by the player to buy tickets.  
    */
    function buyTicket(uint256 amountIn, address tokenIn)
    public
    nonReentrant {
        // Some requirements about tokens, tickets and lotteries.
        require(tokenIn == DAIaddress || 
                tokenIn == USDTaddress || 
                tokenIn == USDCaddress, 
                "We only accept DAI, USDT or USDC tokens.");
        require(amountIn >= ticketPrice, "You have to buy at least one ticket.");
        require(numberOfLotteries > 0, "There are no lotteries active right now");
        // Transfer all tokens to contract and swap it to DAI.  
        IERC20Upgradeable(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        _swapTokensForDAI(tokenIn, amountIn);
        uint256 tickets = amountIn.div(ticketPrice);
        uint256 playersBuyDate = block.timestamp;
        // A loop to iterate between all lotteries.
        for(uint256 j = 0; j <= numberOfLotteries ; j++) {
            _playerId++;            
            uint256 deadlineToBuy = _idToLottery[j].buyingDeadline;
            // A condition to check if the buying date has already passed.
            if(playersBuyDate <= deadlineToBuy) {
                // Add the player to the actual lottery, and emit the event.
                _idToPlayer[_playerId] = 
                    player (msg.sender, 
                            amountIn,
                            tickets,
                            j, 
                            true);
                emit newPlayer (msg.sender, 
                                amountIn,
                                tickets,
                                j,
                                true);
                // Add the payment to the lottery pot.
                _idToLottery[j].pot += amountIn;                
            }
            // If the time already passed, I add the player and the payment to the next lottery. 
            else {              
                if(j == numberOfLotteries) revert ("There are no more loteries");
                _idToPlayer[_playerId] = 
                    player (msg.sender, 
                            amountIn,
                            tickets,
                            j.add(1), 
                            true);
                emit newPlayer (msg.sender, 
                                amountIn,
                                tickets,
                                j.add(1),
                                true);
                    _idToLottery[j.add(1)].pot += amountIn;
            }
        }
    }
    /**
    * @notice a function to retire from the lottery.
    * @dev the player can not retire the investment if is already invested, if thats the case the
    * player has to wait until the contract redeem the invest and pick the winner.
    * @param ID the players Id.
    */
    function retirement(uint256 ID)
    public
    nonReentrant {
        
        require(_idToPlayer[ID].playerAddress == msg.sender &&
                _idToPlayer[ID].playing == true, "You are not playing right now");
        uint256 retirementDate = block.timestamp;
        uint256 playersLottery = _idToPlayer[ID].lotteryNumber;
        uint256 lotteryDate = _idToLottery[playersLottery].buyingDeadline;
        require(retirementDate < lotteryDate, 
                "Your money is already invested, wait until the finisf date");
        uint256 devolution = _idToPlayer[ID].DAIamount;
        DAI.transferFrom(address(this), msg.sender, devolution);
        
    }



}          
         
