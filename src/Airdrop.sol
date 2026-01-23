// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./libraries/Errors.sol";

contract Airdrop is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    bytes32 public merkleRoot;
    uint256 public expiryTime;

    mapping(address => bool) public hasClaimed;
    mapping(bytes32 => bool) public kycVerified;

    uint256 public totalClaimed;
    uint256 public claimCount;

    uint256 public constant MAX_BATCH_SIZE = 100;

    event MerkleRootUpdated(bytes32 oldRoot, bytes32 newRoot);
    event AirdropClaimed(address indexed account, uint256 amount);
    event KYCVerified(bytes32 indexed kycHash);
    event KYCRevoked(bytes32 indexed kycHash);
    event ExpiryUpdated(uint256 oldExpiry, uint256 newExpiry);
    event TokensWithdrawn(address indexed to, uint256 amount);

    constructor(
        address _token,
        bytes32 _merkleRoot,
        uint256 _expiryTime,
        address _owner
    ) Ownable(_owner) {
        if (_token == address(0)) revert Errors.ZeroAddressNotAllowed();
        if (_expiryTime <= block.timestamp) revert Errors.AirdropExpired();

        token = IERC20(_token);
        merkleRoot = _merkleRoot;
        expiryTime = _expiryTime;
    }

    function claim(
        uint256 amount,
        bytes32 kycHash,
        bytes32[] calldata merkleProof
    ) external nonReentrant {
        if (block.timestamp >= expiryTime) revert Errors.AirdropExpired();
        if (hasClaimed[msg.sender]) revert Errors.AlreadyClaimed(msg.sender);
        if (!kycVerified[kycHash])
            revert Errors.KYCVerificationFailed(msg.sender);

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount, kycHash));
        if (!MerkleProof.verify(merkleProof, merkleRoot, leaf)) {
            revert Errors.InvalidMerkleProof();
        }

        hasClaimed[msg.sender] = true;
        totalClaimed += amount;
        claimCount++;

        token.safeTransfer(msg.sender, amount);

        emit AirdropClaimed(msg.sender, amount);
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        bytes32 oldRoot = merkleRoot;
        merkleRoot = _merkleRoot;
        emit MerkleRootUpdated(oldRoot, _merkleRoot);
    }

    function setExpiry(uint256 _expiryTime) external onlyOwner {
        uint256 oldExpiry = expiryTime;
        expiryTime = _expiryTime;
        emit ExpiryUpdated(oldExpiry, _expiryTime);
    }

    function verifyKYC(bytes32 kycHash) external onlyOwner {
        kycVerified[kycHash] = true;
        emit KYCVerified(kycHash);
    }

    function verifyKYCBatch(bytes32[] calldata kycHashes) external onlyOwner {
        if (kycHashes.length > MAX_BATCH_SIZE) revert Errors.BatchTooLarge();
        for (uint256 i = 0; i < kycHashes.length; ) {
            kycVerified[kycHashes[i]] = true;
            emit KYCVerified(kycHashes[i]);
            unchecked {
                ++i;
            }
        }
    }

    function revokeKYC(bytes32 kycHash) external onlyOwner {
        kycVerified[kycHash] = false;
        emit KYCRevoked(kycHash);
    }

    function withdrawRemaining(address to) external onlyOwner {
        if (block.timestamp < expiryTime) revert Errors.AirdropNotExpired();

        uint256 balance = token.balanceOf(address(this));
        if (balance == 0) revert Errors.ZeroAmountNotAllowed();

        token.safeTransfer(to, balance);
        emit TokensWithdrawn(to, balance);
    }

    function isEligible(
        address account,
        uint256 amount,
        bytes32 kycHash,
        bytes32[] calldata merkleProof
    ) external view returns (bool eligible, string memory reason) {
        if (block.timestamp >= expiryTime) {
            return (false, "Airdrop expired");
        }
        if (hasClaimed[account]) {
            return (false, "Already claimed");
        }
        if (!kycVerified[kycHash]) {
            return (false, "KYC not verified");
        }

        bytes32 leaf = keccak256(abi.encodePacked(account, amount, kycHash));
        if (!MerkleProof.verify(merkleProof, merkleRoot, leaf)) {
            return (false, "Invalid proof");
        }

        return (true, "Eligible");
    }
}
