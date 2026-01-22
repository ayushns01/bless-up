// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IAirdrop {
    event MerkleRootUpdated(bytes32 oldRoot, bytes32 newRoot);
    event AirdropClaimed(address indexed account, uint256 amount);
    event KYCVerified(bytes32 indexed kycHash);
    event KYCRevoked(bytes32 indexed kycHash);

    function claim(
        uint256 amount,
        bytes32 kycHash,
        bytes32[] calldata merkleProof
    ) external;
    function setMerkleRoot(bytes32 _merkleRoot) external;
    function verifyKYC(bytes32 kycHash) external;
    function revokeKYC(bytes32 kycHash) external;
}
