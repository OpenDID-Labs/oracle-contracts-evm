// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDIDOracleRequest {
    // @notice gets the Job fee.
    // @param jobId The Job Specification ID
    // @param generateClaim whether to generate a claim
    // @return gasAmount The amount of gas used for job messaging fee
    function quote(bytes32 jobId, bool generateClaim)
        external
        view
        returns (uint256);

    // @notice gets the OVN addresses associated with a given job ID.
    // @param jobId The Job Specification ID
    // @return address[] An array of OVN addresses
    function getOvnsOfJob(bytes32 jobId)
        external
        view
        returns (address[] memory);

    // @notice Creates an oracle request.
    // @param jobId The Job Specification ID
    // @param callbackAddress The contract address that will receive the oracle data
    // @param ovns An array of addresses representing the OVNs involved in the request
    // @param generateClaim A boolean indicating whether to generate a claim for this request
    // @param data a specified format data related to the job request
    // @return requestId a Unique identification of the oracle request of the sender
    // emits event OracleRequested
    function oracleRequest(
        bytes32 jobId,
        address callbackAddress,
        address[] calldata ovns,
        bool generateClaim,
        string calldata data
    ) external payable returns (bytes32);

    // @notice Cancels the oracle request.
    // @param requestId The fulfillment request ID
    // @param refundAddress The address to receive the refund
    // @return Status if the call was successful
    // emits event OracleRequestCanceled
    function cancelOracleRequest(bytes32 requestId, address refundAddress)
        external
        returns (bool);

    // @notice Called by the oracle contract to fulfill requests.
    // @param requestId The fulfillment request ID
    // @param data The response data
    function oracleResponse(bytes32 requestId, string memory data) external;

    // @notice Gets a claim.
    // @param _claim The claim json object
    function getClaim(bytes32 claimID) external view returns (string memory);
}

