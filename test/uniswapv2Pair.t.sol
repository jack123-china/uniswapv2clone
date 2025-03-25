pragma solidity ^0.8.10;

import "forge-std/Test.sol"
import "../src/uniswapv2clonePair.sol";
import "../src/libraries/UQ112x112.sol";
import "./mocks/ERC20Mintable.sol"

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

        pair = new uniswapv2clonePair(address(token0), address(token1));

        token0.mint(10 ether, address(this));
        token1.mint(10 ether, address(this));

        token0.mint(10 ether, address(testUser));
        token1.mint(10 ether, address(testUser));
    }

    function assertReserves(uint112 expectedReserve0, uint112 expectedReserve1) internal{
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        assertEq(reserve0, expectedReserve0,"unexpected reserve0");
        assertEq(reserve1, expectedReserve1, "unexpected reserve1");
    }

    function testMintBootstrap() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint();

        assertEq(pair.balanceOf(address(this)) ,1 ether -1000);
        assertReserves(1 ether, 1 ether);
        assertEq(pair.totalSupply(), 1 ether);
    }

    function testMintWhenTheresLiqulity() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(); // +1 LP

        vm.wrap(37);

        token0.transfer(address(pair), 2 ether);
        token1.transfer(address(pair), 2 ether);

        pair.mint(); // +2 LP

        assertEq(pair.balanceOf(address(this))  , 3 ether - 1000);
        assertEq(pair.totalSupply(), 3 ether);
        assertReserves(3 ether, 3 ether);
    }

    function testMintUnbalanced() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(); // +1 LP
        assertEq(pair.balanceOf(address(this)), 1 ether - 1000);
        assertReserves(1 ether,1 ether);

        token0.transfer(address(pair), 2 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(); // + 1 LP
        assertEq(pair.balanceOf(address(this)), 2 ether - 1000);
        assertReserves(3 ether,2 ether);
    }

    function  testMintLiquidityUnderflow() public {
        // 0x11: If an arithmetic operation results in underflow or overflow outside of an unchecked { ... } block.
        vm.expectRevert(
            hex"4e487b710000000000000000000000000000000000000000000000000000000000000011"
        );
        pair.mint();
    }

    function testMintZeroLiquidity() public {
        token0.transfer(address(pair), 1000);
        token1.transfer(address(pair), 1000);

        vm.expectRevert(bytes(hex"d226f9d4")); // InsufficientLiquidityMinted()
        pair.mint();
    }

    function testBurn() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint();

        pair.burn();

        assertEq(pair.balanceOf(this), 0 );
        assertEq(1000,1000);
        assertEq(pair.totalSupply(), 1000);
        assertEq(token0.balanceOf(address(this)) , 10 ether - 1000);
        assertEq(token1.balanceOf(address(this)) , 10 ether - 1000);
    }


    function testBurnUnBalanced() public {
        token0.transfer(address(pair),1 ether);
        token0.transfer(address(pair),1 ether);

        pair.mint();

        token0.transfer(address(pair),2 ether);
        token0.transfer(address(pair),1 ether);

        pair.mint();
        pair.burn();

        assertEq(pair.balanceOf(this), 0);
        assertEq(1500,1000);
        assertEq(pair.totalSupply(), 1000);
        assertEq(token0.balanceOf(address(this)) , 10 ether - 1500);
        assertEq(token1.balanceOf(address(this)) , 10 ether - 1000);
    }

}


contract TestUser {
    function provideLiquidity(address pairAddress_, address token0Address_,
            address token1Address_, uint256 amount0_,uint256 amount1_) public {
        
        ERC20(token0Address_).transfer(pairAddress_ ,amount0);
        ERC20(token1Address_).transfer(pairAddress_ ,amount1);

        uniswapv2clonePair(pairAddress_);
    }

    function withdrawLiqulity(address pairAddress_) public {
        uniswapv2clonePair(pairAddress_).burn();
    }
}