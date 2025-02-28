// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IClaim {
    struct ClaimFee {
        uint256 gasAmount;
        bool free;
    }

    event ClaimFeeChanged(
        address indexed sender,
        IClaim.ClaimFee before,
        IClaim.ClaimFee current
    );

    event ClaimCommitted(bytes32 indexed claimID, address operator);

    // @notice Set the fee that needs to be paid for generating a claim.
    // @param fee The claim fee object that should be set
    // emits event ClaimFeeChanged
    function setClaimFee(IClaim.ClaimFee calldata fee) external;

    // @notice Commits a new claim.
    // @param claimID The unique identifier of the claim
    // @param _claim The claim object that should be committed
    // emits event ClaimCommited
    function commitClaim(bytes32 claimID, string calldata _claim) external;

    // @notice Gets a claim.
    // @param _claim The claim object
    function getClaim(bytes32 claimID) external view returns (string memory);
}
