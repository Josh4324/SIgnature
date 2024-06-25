// contracts/MockToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract USDC is ERC20, ERC20Permit {
    constructor() ERC20("USDCoin", "USDC") ERC20Permit("USDCoin") {}

    function mint(address user, uint256 amount) public {
        _mint(user, amount);
    }
}

contract Bank {
    IERC20 public usdc;
    bytes32 public DOMAIN_SEPARATOR;
    mapping(address => uint256) balance;
    uint256 nonceId;
    mapping(bytes32 id => uint256 nonce) nonceMap;

    constructor(address usdcCoin, uint256 chainId) {
        usdc = IERC20(usdcCoin);
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Bank Contract")), // Name of the app. Should this be a constructor param?
                keccak256(bytes("1")), // Version. Should this be a constructor param?
                chainId, // Replace with actual chainId (Base Sepolia: 84532)
                address(this)
            )
        );
    }

    struct Sig {
        address from;
        address to;
        uint256 amount;
        uint256 deadline;
    }

    struct Withsig {
        address to;
        uint256 amount;
    }

    function deposit(uint256 amount) public {
        require(amount > 0, "amount must be greater than zero");
        balance[msg.sender] = balance[msg.sender] + amount;

        usdc.transferFrom(msg.sender, address(this), amount);
    }

    function depositWithSig(Sig calldata message, uint8 v, bytes32 r, bytes32 s) public {
        require(block.timestamp <= message.deadline);

        bytes32 hashedMessage = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, _hashMessage(message)));

        address recoveredAddress = ecrecover(hashedMessage, v, r, s);

        require(recoveredAddress == message.from, "The 'from' address must sign the deposit message");

        balance[message.from] = balance[message.from] + message.amount;

        bool success = usdc.transferFrom(message.from, address(this), message.amount);

        require(success, "USDC transfer to creator failed");
    }

    function withdraw(uint256 amount) public {
        require(amount > 0, "amount must be greater than zero");

        balance[msg.sender] = balance[msg.sender] - amount;

        usdc.transfer(msg.sender, amount);
    }

    function withdrawWithSig(Withsig calldata message, uint8 v, bytes32 r, bytes32 s, address user) public {
        bytes32 IdHash = keccak256(abi.encodePacked(message.to, message.amount));

        require(nonceMap[IdHash] == 0, "nonce has been used");

        bytes32 hashedMessage = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, _hashMessage2(message)));

        address recoveredAddress = ecrecover(hashedMessage, v, r, s);

        require(recoveredAddress == message.to, "The 'to' address must sign the withdraw message");

        balance[message.to] = balance[message.to] - message.amount;

        usdc.transfer(user, message.amount);

        nonceMap[IdHash] = nonceMap[IdHash] + 1;
    }

    function getDomainSeparator() public view returns (bytes32) {
        return DOMAIN_SEPARATOR;
    }

    function _hashMessage(Sig calldata message) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("Sig(address from,address to,uint256 amount,uint256 deadline)"),
                message.from,
                message.to,
                message.amount,
                message.deadline
            )
        );
    }

    function _hashMessage2(Withsig calldata message) internal view returns (bytes32) {
        return keccak256(abi.encode(keccak256("Withsig(address to,uint256 amount)"), message.to, message.amount));
    }

    function add(uint256 a, uint256 b) external pure returns (uint256) {
        return a + b;
    }
}

interface IERC20 {
    // Returns the amount of tokens owned by `account`.
    function balanceOf(address account) external view returns (uint256);

    // Returns the remaining number of tokens that `spender` will be
    // allowed to spend on behalf of `owner` through {transferFrom}. This is
    // zero by default.
    function allowance(address owner, address spender) external view returns (uint256);

    // Sets `amount` as the allowance of `spender` over the caller's tokens.
    function approve(address spender, uint256 amount) external returns (bool);

    // Moves `amount` tokens from `sender` to `recipient` using the
    // allowance mechanism. `amount` is then deducted from the caller's
    // allowance.
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function transfer(address user, uint256 amount) external returns (bool);
}
