// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library Errors {
    error UnauthorizedAccess(address caller, bytes32 requiredRole);
    error OnlyMultiSig(address caller);
    error ZeroAddressNotAllowed();
    error ZeroAmountNotAllowed();
    error TaxRateExceedsMaximum(uint16 rate, uint16 maxRate);
    error InsufficientRewardPool(uint256 requested, uint256 available);
    error RewardPoolFundingFailed();
    error TransferWhilePaused();
    error SelfTransferNotAllowed();
    error UnauthorizedUpgrade(address caller);
    error CliffNotReached(uint256 cliffEnd, uint256 currentTime);
    error NoTokensToRelease();
    error BeneficiaryAlreadyExists(address beneficiary);
    error InvalidMerkleProof();
    error AlreadyClaimed(address account);
    error KYCVerificationFailed(address account);
    error AirdropExpired();
}
