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
// LIBRARIES USED //
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

contract Lottery is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    using SafeMathUpgradeable for uint256;

// VARIABLES //

    uint256 public fee;
    uint256 public slippage;
    uint256 public ticketPrice;
    address private UniswapV2Router02;
    // tokens accepted
    address private DAIaddress;
    IERC20Upgradeable DAI;
    address private USDTaddress;
    IERC20Upgradeable USDT;
    address private USDCaddress;
    IERC20Upgradeable USDC;
    
    struct player {
        address payable playerAddress; 
        uint256 DAIamount; // the amount of DAI after conversion.
        uint256 ticketsBuyed; // the amount of tockets the user has purchased. 
        bool playing; // sets true when the player register, set false when the player wins or retire.           
    }
    struct lottery {
        address payable winner;
        uint256 prize;
    }

//MAPPINGS

    mapping(uint256 => player) private _idToPlayer;
    uint256 private _playerId;
    mapping(uint256 => lottery) private _idToLottery;
    uint256 private _lotteryId;

//EVENTS

    event newPlayer (
        address playerAddress, 
        uint256 DAIamount,
        uint256 ticketsBuyed,
        bool playing
    );
    event lotteryWinner (
        address winner,
        uint256 prize
    );

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
            USDT = IERC20Upgradeable(USDTaddress);
            USDCaddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
            USDC = IERC20Upgradeable(USDCaddress);  
            slippage = 5; 
            fee = _fee.div(100);
            _playerId = 0;     
        }
    /**
    * @notice a setter function to set the lottery ticket price.
    * @dev only the owner of the contract can change the fee.
    * @param _ticketPrice the lottery ticket price.
    */
    function setTicketPrice(uint256 _ticketPrice) 
        public
        onlyOwner {
            require(_ticketPrice > 0);
            ticketPrice = _ticketPrice;        
    }
    /**
    * @notice a getter function to get the ticket price
    */
    function getTicketPrice()
        public
        view
        returns(uint256) {
            return ticketPrice;
        }
    /**
    * @notice a function to swap betwen tokens to DAI.
    * @dev this is an auxiliar function.
    * @param _tokenIn is the address of the token that the user have.
    * @param _amountIn is the amount of tokens the user has. 
    */
    function _swapTokensForDAI(address _tokenIn, 
                               uint256 _amountIn)
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
        
    function buyTicket(uint256 amountIn,
                       address tokenIn)
        public
        nonReentrant {

            require(tokenIn == DAIaddress || 
                    tokenIn == USDTaddress || 
                    tokenIn == USDCaddress, 
                    "We only accept DAI, USDT or USDC tokens.");
            require(amountIn >= ticketPrice, "You have to buy at least one ticket");
            uint256 tickets = amountIn.div(ticketPrice);
            uint256 remaining = amountIn % ticketPrice;

            if (remaining != 0) {
                uint256 amountNeeded = tickets.mul(ticketPrice);
                IERC20Upgradeable(tokenIn).transferFrom(msg.sender, address(this), amountNeeded);
                _swapTokensForDAI(tokenIn, amountNeeded);
                _playerId++;
                _idToPlayer[_playerId] = player (payable(msg.sender), 
                                                 amountNeeded,
                                                 tickets, 
                                                 true);
                emit newPlayer (payable(msg.sender), 
                                amountNeeded,
                                tickets,
                                true);

            } else {
                IERC20Upgradeable(tokenIn).transferFrom(msg.sender, address(this), amountIn);
                _swapTokensForDAI(tokenIn, amountIn);
                _playerId++;
                _idToPlayer[_playerId] = player (payable(msg.sender), 
                                                 amountIn,
                                                 tickets, 
                                                 true);
                emit newPlayer (payable(msg.sender), 
                                amountIn,
                                tickets,
                                true);
            }
        }

    
    
}
