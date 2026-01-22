// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../../src/ACTXToken.sol";
import "../../src/Airdrop.sol";
import "../../src/libraries/Errors.sol";

contract AirdropTest is Test {
    ACTXToken public token;
    Airdrop public airdrop;

    address public treasury = makeAddr("treasury");
    address public reservoir = makeAddr("reservoir");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    bytes32 public merkleRoot;
    bytes32 public kycHash1;
    bytes32 public kycHash2;
    uint256 public amount1 = 1000 ether;
    uint256 public amount2 = 2000 ether;
    uint256 public expiryTime;

    function setUp() public {
        ACTXToken implementation = new ACTXToken();
        bytes memory initData = abi.encodeWithSelector(
            ACTXToken.initialize.selector,
            treasury,
            reservoir,
            200
        );
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        token = ACTXToken(address(proxy));

        kycHash1 = keccak256(abi.encodePacked("KYC_USER1"));
        kycHash2 = keccak256(abi.encodePacked("KYC_USER2"));
        expiryTime = block.timestamp + 30 days;

        bytes32 leaf1 = keccak256(abi.encodePacked(user1, amount1, kycHash1));
        bytes32 leaf2 = keccak256(abi.encodePacked(user2, amount2, kycHash2));
        merkleRoot = keccak256(abi.encodePacked(leaf1, leaf2));

        airdrop = new Airdrop(address(token), merkleRoot, expiryTime, treasury);

        vm.prank(treasury);
        token.transfer(address(airdrop), 100_000 ether);
    }

    function test_Deploy_SetsCorrectValues() public view {
        assertEq(address(airdrop.token()), address(token));
        assertEq(airdrop.merkleRoot(), merkleRoot);
        assertEq(airdrop.expiryTime(), expiryTime);
    }

    function test_VerifyKYC_Success() public {
        vm.prank(treasury);
        airdrop.verifyKYC(kycHash1);

        assertTrue(airdrop.kycVerified(kycHash1));
    }

    function test_VerifyKYCBatch_Success() public {
        bytes32[] memory hashes = new bytes32[](2);
        hashes[0] = kycHash1;
        hashes[1] = kycHash2;

        vm.prank(treasury);
        airdrop.verifyKYCBatch(hashes);

        assertTrue(airdrop.kycVerified(kycHash1));
        assertTrue(airdrop.kycVerified(kycHash2));
    }

    function test_RevokeKYC_Success() public {
        vm.startPrank(treasury);
        airdrop.verifyKYC(kycHash1);
        airdrop.revokeKYC(kycHash1);
        vm.stopPrank();

        assertFalse(airdrop.kycVerified(kycHash1));
    }

    function test_Claim_RevertIf_NotKYCVerified() public {
        bytes32[] memory proof = new bytes32[](0);

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.KYCVerificationFailed.selector, user1)
        );
        airdrop.claim(amount1, kycHash1, proof);
    }

    function test_Claim_RevertIf_Expired() public {
        vm.prank(treasury);
        airdrop.verifyKYC(kycHash1);

        vm.warp(expiryTime + 1);

        bytes32[] memory proof = new bytes32[](0);

        vm.prank(user1);
        vm.expectRevert(Errors.AirdropExpired.selector);
        airdrop.claim(amount1, kycHash1, proof);
    }

    function test_Claim_RevertIf_InvalidProof() public {
        bytes32[] memory proof = new bytes32[](0);

        vm.prank(treasury);
        airdrop.verifyKYC(kycHash1);

        vm.prank(user1);
        vm.expectRevert(Errors.InvalidMerkleProof.selector);
        airdrop.claim(amount1, kycHash1, proof);
    }

    function test_SetMerkleRoot_Success() public {
        bytes32 newRoot = keccak256("new_root");

        vm.prank(treasury);
        airdrop.setMerkleRoot(newRoot);

        assertEq(airdrop.merkleRoot(), newRoot);
    }

    function test_SetExpiry_Success() public {
        uint256 newExpiry = block.timestamp + 60 days;

        vm.prank(treasury);
        airdrop.setExpiry(newExpiry);

        assertEq(airdrop.expiryTime(), newExpiry);
    }

    function test_WithdrawRemaining_RevertIf_NotExpired() public {
        vm.prank(treasury);
        vm.expectRevert(Errors.AirdropExpired.selector);
        airdrop.withdrawRemaining(treasury);
    }

    function test_WithdrawRemaining_Success() public {
        vm.warp(expiryTime + 1);

        uint256 balanceBefore = token.balanceOf(treasury);
        uint256 airdropBalance = token.balanceOf(address(airdrop));

        vm.prank(treasury);
        airdrop.withdrawRemaining(treasury);

        // 2% tax on transfer from airdrop contract to treasury
        uint256 expectedAfterTax = (airdropBalance * 98) / 100;
        assertEq(token.balanceOf(address(airdrop)), 0);
        assertEq(token.balanceOf(treasury), balanceBefore + expectedAfterTax);
    }

    function test_IsEligible_ReturnsCorrectStatus() public {
        bytes32[] memory proof = new bytes32[](0);

        (bool eligible, string memory reason) = airdrop.isEligible(
            user1,
            amount1,
            kycHash1,
            proof
        );
        assertFalse(eligible);
        assertEq(reason, "KYC not verified");

        vm.prank(treasury);
        airdrop.verifyKYC(kycHash1);

        (eligible, reason) = airdrop.isEligible(
            user1,
            amount1,
            kycHash1,
            proof
        );
        assertFalse(eligible);
        assertEq(reason, "Invalid proof");
    }
}
