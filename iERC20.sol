pragma solidity ^0.8.0;

import "./ERC20Interface.sol";

contract interERC20 {
   

    struct CrossIntoTransfer {
        string uniqueHash;
        address sender;
        address receiver;
        uint256 fromChainId;
        uint256 value;
        uint256 pledgedDAOTokenAmount;
        address operator;
        uint256 intoChainId;
        uint256 startBlock;
        uint256 status;
    }

    struct VoteRecord {
        string uniqueHash;
        bool support;
        address user;
        uint256 pledgedAmount;
        uint256 voteBlock;
    }


    function syncMintForCrossInto(string memory uniqueHash, address sender, address receiver, uint256 fromChainId, uint256 value, uint256 pledgedDAOTokenAmount) external {
        // ...DO STH...
    }

    function DAOVote(string memory uniqueHash, bool support, uint256 pledgedDAOTokenAmount) external {
        // ...DO STH...

        if (supportTokens > ERC20(DAOTokenAddress).totalSupply() / 2) {
            crossIntoTransfers[uniqueHash].status = 1;
            emit TransferSuccess(uniqueHash);
            distributeOpposeTokens(uniqueHash, supportTokens, opposeTokens);
            balanceOf[address(receiver)] += value;
            emit Transfer(address(0), address(receiver), value);
        }
        // ...DO STH...
    }

    // ...DO STH...
}
