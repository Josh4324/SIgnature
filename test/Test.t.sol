// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Bank, USDC} from "../src/Token.sol";

// Take all tokens out of the pool. If possible, in a single transaction.

contract BankTest is Test {
    Bank public bank;
    USDC public usdc;

    uint256 ownerPrivateKey = uint256(keccak256("owner private key"));
    address owner = vm.addr(ownerPrivateKey);
    address treasurer = makeAddr("treasurer");

    uint256 user1PrivateKey = uint256(keccak256("user1 private key"));
    address user1 = vm.addr(user1PrivateKey);

    address user2 = makeAddr("2");
    address user3 = makeAddr("3");
    address user4 = makeAddr("4");

    function setUp() public {
        usdc = new USDC();

        usdc.mint(owner, 100 ether);
        usdc.mint(user1, 100 ether);
        usdc.mint(user2, 100 ether);
        usdc.mint(user3, 100 ether);
        usdc.mint(user4, 100 ether);

        vm.startPrank(owner);
        bank = new Bank(address(usdc), 1);
        vm.stopPrank();
    }

    function test_1() public {
        uint256 chainId = block.chainid;
        uint256 nonce = usdc.nonces(owner);
        uint256 deadline = type(uint256).max;
        uint256 value = 60 ether;

        bytes32 domainSeparator = usdc.DOMAIN_SEPARATOR();

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                user1,
                address(bank),
                value,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);

        vm.prank(address(bank));
        usdc.permit(user1, address(bank), 60 ether, deadline, v, r, s);

        assert(usdc.allowance(user1, address(bank)) == 60 ether);

        bytes32 domainSeparator1 = bank.getDomainSeparator();

        bytes32 structHash1 = keccak256(
            abi.encode(
                keccak256("Sig(address from,address to,uint256 amount,uint256 deadline)"),
                user1,
                address(bank),
                20 ether,
                deadline
            )
        );

        bytes32 digest1 = keccak256(abi.encodePacked("\x19\x01", domainSeparator1, structHash1));
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(user1PrivateKey, digest1);

        vm.prank(address(bank));
        bank.depositWithSig(Bank.Sig(user1, address(bank), 20 ether, deadline), v1, r1, s1);

        vm.prank(address(bank));
        bank.depositWithSig(Bank.Sig(user1, address(bank), 20 ether, deadline), v1, r1, s1);

        assert(usdc.balanceOf(address(bank)) == 40 ether);
    }

    function test_2() public {
        uint256 chainId = block.chainid;
        uint256 nonce = usdc.nonces(owner);
        uint256 deadline = type(uint256).max;
        uint256 value = 60 ether;

        bytes32 domainSeparator = usdc.DOMAIN_SEPARATOR();

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                user1,
                address(bank),
                value,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);

        vm.prank(address(bank));
        usdc.permit(user1, address(bank), 60 ether, deadline, v, r, s);

        assert(usdc.allowance(user1, address(bank)) == 60 ether);

        bytes32 domainSeparator1 = bank.getDomainSeparator();

        bytes32 structHash1 = keccak256(
            abi.encode(
                keccak256("Sig(address from,address to,uint256 amount,uint256 deadline)"),
                user1,
                address(bank),
                40 ether,
                deadline
            )
        );

        bytes32 digest1 = keccak256(abi.encodePacked("\x19\x01", domainSeparator1, structHash1));
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(user1PrivateKey, digest1);

        vm.prank(address(bank));
        bank.depositWithSig(Bank.Sig(user1, address(bank), 40 ether, deadline), v1, r1, s1);

        bytes32 structHash2 = keccak256(abi.encode(keccak256("Withsig(address to,uint256 amount)"), user1, 20 ether));

        bytes32 digest2 = keccak256(abi.encodePacked("\x19\x01", domainSeparator1, structHash2));
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(user1PrivateKey, digest2);

        vm.prank(address(bank));
        bank.withdrawWithSig(Bank.Withsig(user1, 20 ether), v2, r2, s2, user1);

        vm.prank(user2);
        bank.withdrawWithSig(Bank.Withsig(user1, 20 ether), v2, r2, s2, user2);

        assert(usdc.balanceOf(user1) == 80 ether);
        assert(usdc.balanceOf(user2) == 120 ether);

        //bank.depositWithSig(Bank.Sig(user1, address(bank), 20 ether, deadline), v1, r1, s1);
    }

    // (x + y) + z == x + (y + z)
    function test_3(uint256 amount) public {
        amount = bound(amount, 1, type(uint256).max);

        uint256 balanceb4 = usdc.balanceOf(user1);

        vm.prank(user1);
        usdc.approve(address(bank), amount);

        vm.prank(user1);
        bank.deposit(amount);

        uint256 balanceAfter = usdc.balanceOf(user1);

        console.log("1st", usdc.allowance(user1, address(bank)));
        console.log("2nd", 0);
        console.log("3rd", usdc.balanceOf(address(bank)));

        assert(usdc.balanceOf(address(bank)) == amount);
        assert(usdc.allowance(user1, address(bank)) == 0);
        assert((balanceb4 - balanceAfter) == amount);
    }
}
