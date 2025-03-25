pragma solidity ^0.8.10;

import "solmate/tokens/ERC20.sol";
import "./libraries/Math.sol";
import "./libraries/UQ112x112.sol";


interface IERC20{
    function balanceOf(address) external returns (uint256);
    function transfer(address to, uint256 amount) external;
}

error BalanceOverflow();
error InsufficientLiquidityMinted();
error InsufficientLiquidityBurned();
error InsufficientOutputAmount();
error InsufficientLiquidity();
error InvalidK();
error TransferFailed();

contract uniswapv2clonePair is ERC20 , Math{
    uint256 constant MININUM_LIQUIDITY = 1000;

    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;

    uint32 private blockTimeStampLast; //store last swap time

    uint256 public price0Cumulativelast;
    uint256 public price1Cumulativelast;

    event Burn(address indexed sender, uint256 amount0 , uint256 amount1);
    event Mint(address indexed sender, uint256 amount0 , uint256 amount1);
    event Sync(uint256 reserve0, uint256 reserve1);
    event Swap(address indexed sender, uint256 amount0out,uint256 amount1out, address indexed to);


    constructor(address token0_, address token1_)
        ERC20("uniswapv2 pair","zunv2", 18)
    {
        token0 = token0_;
        token1 = token1_;
    }

    function mint() public {
        (uint112 _reserve0,uint112 _reserve1, ) =getReserves();
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        uint256 liquidity ;

        if(0 == totalSupply){
            liquidity = Math.sqrt(amount0*amount1) - MININUM_LIQUIDITY;
            _mint(address(0), MININUM_LIQUIDITY);
        }else {
            liquidity = Math.min(
                (amount0*totalSupply) / _reserve0,
                (amount1*totalSupply) / _reserve1
            );
        }

        if(liquidity <= 0)  revert  InsufficientLiquidityMinted();

        _mint(msg.sender, liquidity);
        _update(balance0 , balance1);

        emit Mint(msg.sender, amount0,amount1);
    }

    function burn() public{
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 liquidity = balanceOf[msg.sender];

        uint256 amount0 = (liquidity * balance0)/ totalSupply;
        uint256 amount1 = (liquidity * balance1)/ totalSupply;

        if(amount0 <= 0 || amount1 <= 0) revert InsufficientLiquidityBurned();

        _burn(msg.sender, liquidity);

        _safeTransfer(token0, msg.sender, amount0);
        _safeTransfer(token1, msg.sender, amount1);

        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));

        _update(balance0, balance1);
        emit Burn(msg.sender, amount0, amount1);
    }
    
    
    //防止重入攻击的两种常见方法：
    // 1) 使用重入保护机制。例如，OpenZeppelin 合约中的重入保护。UniswapV2 使用自己实现的方式，
    // 因为这个实现并不复杂。其主要思想是在函数被调用时设置一个标志，并且在标志被设置时不允许再次调用该函数；
    // 在函数调用完成后再取消标志。这个机制不允许在函数正在被调用时再次调用它（由于交易是原子性应用的，
    // 任何时候只有一个调用者，锁定一个函数不会使其对其他调用者不可访问）。
    // 2) 遵循检查、效果、交互模式（Checks, Effects, Interactions Pattern）。
    // 该模式强制合约函数按照严格的操作顺序进行：
    //     首先，进行所有必要的检查，以确保函数在正确的状态下运行。
    //     其次，函数根据其逻辑更新自身的状态。
    //     最后，函数进行外部调用。这种顺序保证了每次函数调用在函数状态最终确定且正确时进行，
                // 即没有待处理的状态更新。
    function swap(uint256 amount0Out, uint256 amount1Out,address to) public {
        if (amount0Out ==0 && amount1Out ==0) revert InsufficientOutputAmount();

        (uint112 reserve0_, uint112 reserve1_, ) = getReserves();

        if(amount0 > reserve0_ || amount1Out > reserve1_) 
            revert InsufficientLiquidity();

        uint256 balance0 = IERC20(token0).balanceOf(address(this)) - amount0Out;
        uint256 balance1 = IERC20(token1).balanceOf(address(this)) - amount1Out;

        if(balance0 * balance1 < uint256(reserve0_)*uint256(reserve1_) )
            revert InvalidK();

        _update(balance0, balance1,reserve0_, reserve1_);

        if(amount0Out > 0) _safeTransfer(token0, to, amount0Out);
        if(amount1Out > 0) _safeTransfer(token1, to, amount1Out);

        emit Swap(msg.sender,amount0Out, amount1Out, to);
    }


    function sync() public{
        (uint112 reserve0_,uint112 reserve1_, ) = getReserves();   
        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this)),
            reserve0_, reserve1_
        );
    }

    function getReserves() public view returns(uint112,uint112,uint32){
        return (reserve0,reserve1,0);
    }


    // function _update(uint256 balance0, uint256 balance1) private{
    //     reserve0 = uint112(balance0);
    //     reserve1 = uint112(balance1);

    //     emit Sync(reserve0, reserve1);
    // }

    function _update(uint256 balance0, uint256 balance1,uint112 reserve0_,uint112 reserve1_) private{
        if (balance0 > type(uint112).max || balance1 type(uint112).max) 
            revert BalanceOverflow();

        unchecked {
            uint32 timeElapsed = uint32(block.timestamp) - blockTimeStampLast;

            if(timeElapsed > 0 && reserve0_ > 0 && reserve1_ > 0){
                price0Cumulativelast += 
                    uint256(UQ112x112.encode(reserve1_).uqdiv(reserve0_)) * timeElapsed;

                price1Cumulativelast += 
                    uint256(UQ112x112.encode(reserve0_).uqdiv(reserve1_)) * timeElapsed;
            }
        }

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimeStampLast = uint32(block.timestamp);

        emit Sync(reserve0, reserve1); 
    }

    function _safeTransfer(address token ,address to, uint256 value) private {
        (bool success ,bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)",to,value)
        );

        if(!success || (data.length != 0 && !abi.decode(data,(bool)))){
            revert TransferFailed();
        }
    }
}