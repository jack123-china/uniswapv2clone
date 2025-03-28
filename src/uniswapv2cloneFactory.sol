pragma solidity ^0.8.10;

import "./interface/Iuniswapv2Factory.sol";
import "./uniswapv2clonePair.sol";
import "./interface/Iuniswapv2Pair.sol";

contract UniswapV2Factory{
    error IdenticalAddress();
    error PairExists();
    error ZeroAddress();

    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    mapping(address => mapping(address => address)) public pairs;
    address[] public allPairs;


    function createPair(address tokenA, address tokenB) public returns (address pair) {
        if(tokenA == tokenB) revert IdenticalAddress();

        (address token0,address token1) = tokenA < tokenB ? (tokenA ,tokenB) : (tokenB,tokenA);
        if(token0 == address(0)) revert ZeroAddress();

        if(pairs[token0][token1] != address(0)) revert PairExists();

        bytes memory bytecode = type(uniswapv2clonePair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0,token1)) ;

        assembly {
            pair := create2(0, add(bytecode,32) , mload(bytecode), salt)
        }

        IUniswapV2Pair(pair).initialize(token0,token1);

        pairs[token0][token1] = pair;
        pairs[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1,pair, allPairs.length);
    }
}

