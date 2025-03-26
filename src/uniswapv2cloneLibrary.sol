pragma solidity ^0.8.10;

import "./interface/Iuniswapv2Factory.sol";
import "./interface/Iuniswapv2Pair.sol";
import {uniswapv2clonePair} from "./uniswapv2clonePair.sol";

library Uniswapv2Library{
    error InsufficientAmount();
    error InsufficientLiqulity();

    function getReserves(
        address factoryAddress,
        address tokenA,address tokenB
    ) public returns(uint256 reserveA, uint256 reserveB){
        (address token0, address token1) = sortTokens(tokenA,tokenB);
        (uint256 reserve0,uint256 reserve1, ) = IUniswapV2Pair(
            pairFor(factoryAddress,token0,token1)
        ).getReserves();

        (reserveA,reserveB) = tokenA == token0 ? (reserve0,reserve1) :(reserve1,reserve0);
    }

    function quote(
        uint256 amountIn,uint256 reserveIn, uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        if(amountIn == 0) revert InsufficientAmount();

        if(0 == reserveIn || 0 == reserveOut) revert InsufficientLiqulity();

        return (amountIn * reserveOut) / reserveIn;
    }


    function sortTokens(address tokenA, address tokenB) internal pure returns(address token0, address token1){
        return tokenA < tokenB ? ( tokenA , tokenB) :( tokenB, tokenA );    
    }

    function pairFor(address factoryAddress, address tokenA,address tokenB) internal pure returns(address pairAddress){
        (address token0, address token1) = sortTokens(tokenA, tokenB);

        pairAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factoryAddress,
                            keccak256(abi.encodePacked(token0,token1)),
                            keccak256(type(uniswapv2clonePair).creationCode)
                        )
                    )
                )
            )
        );
    }
}