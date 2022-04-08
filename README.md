# No loss lottery

This is a solidity project about a lottery with the next characteristics:

* It´s an upgradeable smart contract.
* The owner of the contract start an specific amount of lotteries.
* The owner receive a fee on the prize.
* The owner set the ticket price.
* The player can buy any amount of tickets.
* The player can only pay in DAI, USDC or USDT.
* All the tokens will be converted to DAI.
* When the lottery has two days since started, the owner invest the pot on Compound.
* If a player buys a ticket from two days since started, he is going to be added to the next lottery.
* The investment in Compound will be for five days.
* When retire, the owner select the winner, takes the fee on the price and devolutes the money.

## INSTALATION

1. Clone this repo
2. Install the dependencies with 
    > npm install
3. Run test with any of
    > npx hardhat test
    > npm run test

## WALKTHROUGH

    The project is intended to make swaps with Curve Finance, and is using the Stable Swap pool, but if you have problems with this pool you can change any swap you want, by changing the corresponding function, here you have an example for Uniswap. You just have to change this function




    ``` javascript
        function _swapTokensForDAI(address _tokenIn, uint256 _amountIn)
        internal {
            IERC20Upgradeable(_tokenIn).approve(StableSwap, _amountIn);
            for(uint128 q = 1; q <= _tokensAccepted.length; q++) {
                if(_tokenIn == _tokensAccepted[q]) {
                    int128 _index = int128(q);
                    IStableSwap(StableSwap).exchange(_index, 0, _amountIn, 1);
                }
            }
    }
    ```
    For this one




    ``` javascript
        function _swapTokensForDAI(address _tokenIn, uint256 _amountIn)
        internal{
            IERC20Upgradeable(_tokenIn).transferFrom(msg.sender, address(this), _amountIn);
            IERC20Upgradeable(_tokenIn).approve(UniswapV2Router02, _amountIn);
            address[] memory _path;
            _path = new address[](2);
            _path[0] = _tokenIn;
            _path[1] = DAIaddress;
            IUniswapV2Router02(UniswapV2Router02).
                swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    _amountIn, 1, _path, address(this), block.timestamp + 1);
        }
    ```
    You can also change pools on Uniswap, for example 3pool. here you have the address for this one
    > 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7








    
 

# REFERENCIAS
# TECNOLOGIAS EMPLEADAS






```shell
npx hardhat accounts
npx hardhat compile
npx hardhat clean
npx hardhat test
npx hardhat node
node scripts/sample-script.js
npx hardhat help
```
