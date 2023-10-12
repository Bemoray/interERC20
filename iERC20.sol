// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract interERC20 {

    ERC20 public DAOToken;


    string public name = "interERC20";
    string public symbol = "iERC20";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(string => CrossIntoTransfer) public crossIntoTransfers;
    mapping(string => VoteRecord[]) public voteRecords;
    mapping(string => CrossOutTransfer) public crossOutTransfers;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

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

  struct CrossOutTransfer {
    string uniqueHash;
    address sender;
    address receiver;
    uint256 amount;
    uint256 fromChainId;
    uint256 intoChainId;
    uint256 startBlock;
  }


    event CrossOutTransferEvent(
        string uniqueHash,
        address indexed sender,
        address indexed receiver,
        uint256 amount,
        uint256 fromChainId,
        uint256 intoChainId,
        uint256 startBlock
    );

    event CrossIntoRequested(string uniqueHash, address sender, address receiver, uint256 fromChainId, uint256 value, uint256 pledgedDAOTokenAmount, address operator, uint256 intoChainId, uint256 startBlock);
    event TransferSuccess(string uniqueHash);
    event TransferFailed(string uniqueHash);
    event Voted(string uniqueHash, bool support, address user, uint256 pledgedAmount);



    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);


    constructor(uint256 initialSupply,address _DAOTokenAddress) {
        DAOToken = ERC20(_DAOTokenAddress);
        totalSupply = initialSupply * 10 ** uint256(decimals);
        balanceOf[msg.sender] = totalSupply;

    }
    
    function syncMintForCrossInto(string memory uniqueHash, address sender, address receiver, uint256 fromChainId, uint256 value, uint256 pledgedDAOTokenAmount) external {
        require(DAOToken.balanceOf(msg.sender) >= DAOToken.totalSupply() / 10, "Insufficient DAOToken balance for operation");
        require(crossIntoTransfers[uniqueHash].startBlock == 0, "CrossInto request with this hash already exists");

        CrossIntoTransfer memory newTransfer = CrossIntoTransfer({
            uniqueHash: uniqueHash,
            sender: sender,
            receiver: receiver,
            fromChainId: fromChainId,
            value: value,
            pledgedDAOTokenAmount: pledgedDAOTokenAmount,
            operator: msg.sender,
            intoChainId: block.chainid,
            startBlock: block.number,
            status: 0
        });

        crossIntoTransfers[uniqueHash] = newTransfer;
        emit CrossIntoRequested(uniqueHash, sender, receiver, fromChainId, value, pledgedDAOTokenAmount, msg.sender, block.chainid, block.number);
    }





function checkVoteStatus(string memory uniqueHash) public view returns (uint256 supportTokens, uint256 opposeTokens, uint256 lastVoteBlock, uint256 currentStatus) {
    uint256 totalSupport = 0;
    uint256 totalOppose = 0;
    uint256 lastBlock = 0;

    for (uint i = 0; i < voteRecords[uniqueHash].length; i++) {
        if (voteRecords[uniqueHash][i].support) {
            totalSupport += voteRecords[uniqueHash][i].pledgedAmount;
        } else {
            totalOppose += voteRecords[uniqueHash][i].pledgedAmount;
        }
        if (voteRecords[uniqueHash][i].voteBlock > lastBlock) {
            lastBlock = voteRecords[uniqueHash][i].voteBlock;
        }
    }

    return (totalSupport, totalOppose, lastBlock, crossIntoTransfers[uniqueHash].status);
}


    function DAOVote(string memory uniqueHash, bool support, uint256 pledgedDAOTokenAmount) external {
        (uint256 supportTokens, uint256 opposeTokens, uint256 lastVoteBlock, uint256 currentStatus) = checkVoteStatus(uniqueHash);

        require(currentStatus == 0, "Can only vote on active CrossInto requests");

        VoteRecord memory newVote = VoteRecord({
            uniqueHash: uniqueHash,
            support: support,
            user: msg.sender,
            pledgedAmount: pledgedDAOTokenAmount,
            voteBlock: block.number
        });

        voteRecords[uniqueHash].push(newVote);
        emit Voted(uniqueHash, support, msg.sender, pledgedDAOTokenAmount);

        uint256 blocksSinceLastVote = block.number - lastVoteBlock;
        uint256 supportRate = (supportTokens * 100) / (supportTokens + opposeTokens);

        if (blocksSinceLastVote >= 100) {
            if (supportRate > 50 && supportTokens > opposeTokens) {
                crossIntoTransfers[uniqueHash].status = 1;
                emit TransferSuccess(uniqueHash);
                distributeOpposeTokens(uniqueHash);
                _mint(crossIntoTransfers[uniqueHash].receiver, crossIntoTransfers[uniqueHash].value);
            } else if (opposeTokens > supportTokens) {
                crossIntoTransfers[uniqueHash].status = 2;
                emit TransferFailed(uniqueHash);
                distributeSupportTokens(uniqueHash);
            }
        }
    }




    function distributeSupportTokens(string memory uniqueHash) internal {
        uint256 totalSupportTokensToDistribute = 0;
        for (uint i = 0; i < voteRecords[uniqueHash].length; i++) {
            if (voteRecords[uniqueHash][i].support) {
                totalSupportTokensToDistribute += voteRecords[uniqueHash][i].pledgedAmount;
            }
        }

        for (uint i = 0; i < voteRecords[uniqueHash].length; i++) {
            if (!voteRecords[uniqueHash][i].support) {
                uint256 tokensToDistribute = (voteRecords[uniqueHash][i].pledgedAmount * totalSupportTokensToDistribute) / (totalSupply - totalSupportTokensToDistribute);
                DAOToken.transfer(voteRecords[uniqueHash][i].user, tokensToDistribute);
            }
        }
    }

    function distributeOpposeTokens(string memory uniqueHash) internal {
        uint256 totalOpposeTokensToDistribute = 0;
        for (uint i = 0; i < voteRecords[uniqueHash].length; i++) {
            if (!voteRecords[uniqueHash][i].support) {
                totalOpposeTokensToDistribute += voteRecords[uniqueHash][i].pledgedAmount;
            }
        }

        for (uint i = 0; i < voteRecords[uniqueHash].length; i++) {
            if (voteRecords[uniqueHash][i].support) {
                uint256 tokensToDistribute = (voteRecords[uniqueHash][i].pledgedAmount * totalOpposeTokensToDistribute) / DAOToken.totalSupply();
                DAOToken.transfer(voteRecords[uniqueHash][i].user, tokensToDistribute);
            }
        }
    }




    function startCrossOutTransfer(uint256 amount, uint256 intoChainId) external {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        
        balanceOf[msg.sender] -= amount;
        emit Transfer(msg.sender, address(0), amount);

        string memory uniqueHash = bytes32ToString(generateUniqueHash(intoChainId,msg.sender,amount)); // Assuming a function to generate unique hash

        CrossOutTransfer memory transfer = CrossOutTransfer({
            uniqueHash: uniqueHash,
            sender: msg.sender,
            receiver: msg.sender,
            amount: amount,
            fromChainId: block.chainid, // Assuming a function to get current chain id
            intoChainId: intoChainId,
            startBlock: block.number
        });

        crossOutTransfers[uniqueHash] = transfer;
        emit CrossOutTransferEvent(uniqueHash, msg.sender, msg.sender, amount, block.chainid, intoChainId, block.number);
    }

    function startCrossOutTransferTo(address receiver, uint256 amount, uint256 intoChainId) external {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        
        balanceOf[msg.sender] -= amount;
        emit Transfer(msg.sender, address(0), amount);

        string memory uniqueHash = bytes32ToString(generateUniqueHash(intoChainId,msg.sender,amount)); // Assuming a function to generate unique hash

        CrossOutTransfer memory transfer = CrossOutTransfer({
            uniqueHash: uniqueHash,
            sender: msg.sender,
            receiver: receiver,
            amount: amount,
            fromChainId: block.chainid, // Assuming a function to get current chain id
            intoChainId: intoChainId,
            startBlock: block.number
        });

        crossOutTransfers[uniqueHash] = transfer;
        emit CrossOutTransferEvent(uniqueHash, msg.sender, receiver, amount, block.chainid, intoChainId, block.number);
    }

    function generateUniqueHash(uint256 toChainId, address sender, uint256 startBlock) public pure returns (bytes32) {
      return keccak256(abi.encodePacked(toChainId, sender, startBlock));
    }

    function bytes32ToString(bytes32 _bytes32) public pure returns (string memory) {
      uint8 i = 0;
      while(i < 32 && _bytes32[i] != 0) {
          i++;
      }
      bytes memory bytesArray = new bytes(i);
      for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
          bytesArray[i] = _bytes32[i];
      }
      return string(bytesArray);
    }
    
    function _mint(address user,uint amount) internal {
        balanceOf[user] += amount;
        emit Transfer(msg.sender, address(0), amount);
  
    }



}
