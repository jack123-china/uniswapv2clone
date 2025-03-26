pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/uniswapv2clonePair.sol";
import "../src/libraries/UQ112x112.sol";
import "./mocks/ERC20Mintable.sol";

contract uniswapv2clonePairTest is Test {
    ERC20Mintable token0;
    ERC20Mintable token1;
    uniswapv2clonePair pair;
    TestUser testUser;

    function setUp() public 
    {
        testUser = new TestUser();

        token0 = new ERC20Mintable("Token A", "TKNA");
        token1 = new ERC20Mintable("Token B", "TKNB");

        pair = new uniswapv2clonePair();
        pair.initialize(address(token0), address(token1));

        token0.mint(10 ether, address(this));
        token1.mint(10 ether, address(this));

        token0.mint(10 ether, address(testUser));
        token1.mint(10 ether, address(testUser));
    }

    function assertReserves(uint112 expectedReserve0, uint112 expectedReserve1) internal view {
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        assertEq(reserve0, expectedReserve0,"unexpected reserve0");
        assertEq(reserve1, expectedReserve1, "unexpected reserve1");
    }

 
}


contract TestUser {
    function provideLiquidity(address pairAddress_, address token0Address_,
            address token1Address_, uint256 amount0_,uint256 amount1_) public {
        
        ERC20(token0Address_).transfer(pairAddress_ ,amount0_);
        ERC20(token1Address_).transfer(pairAddress_ ,amount1_);

        uniswapv2clonePair(pairAddress_).mint(address(this));
    }

    function withdrawLiqulity(address pairAddress_) public {
        uniswapv2clonePair(pairAddress_).burn();
    }
}