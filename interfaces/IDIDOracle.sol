// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../interfaces/IClaim.sol";

interface IDIDOracle is IClaim {
    struct Commitment {
        bytes32 jobId;
        address callbackAddr;
        bytes4 callbackFunctionId;
        uint256 amount;
        uint256 expiration;
        address requester;
        address[] ovns;
        bool generateClaim;
        uint256 fulfillCount;
    }

    struct JobOvnMapping {
        bytes32 jobId;
        address[] ovns;
    }

    event OracleRequested(
        bytes32 indexed jobId,
        bytes32 indexed requestId,
        address requester,
        address[] ovns,
        bool generateClaim,
        uint256 amount,
        string data
    );

    event fulfillOracleRequested(bytes32 indexed requestId, address ovn);

    event OracleRequestCanceled(
        bytes32 indexed jobId,
        bytes32 indexed requestId,
        address requester,
        uint256 amount
    );

    event JobOvnMappingChanged(
        address indexed sender,
        bytes32 jobId,
        address[] before,
        address[] current
    );

    // @notice Sets OVN addresses for multiple jobs at once.
    // @param records The mapping relationships between job and ovns
    // emits event JobOvnsChanged
    function setOvnsForJobs(JobOvnMapping[] calldata mappings) external;

    // @notice gets the OVN addresses associated with a given job ID.
    // @param jobId The Job Specification ID
    // @return address[] An array of OVN addresses
    function getOvnsOfJob(bytes32 jobId)
        external
        view
        returns (address[] memory);

    // @notice gets the Job fee.
    // @param jobId The Job Specification ID
    // @param generateClaim whether to generate a claim
    // @return gasAmount The amount of gas used for job messaging fee
    function quote(bytes32 jobId, bool generateClaim)
        external
        view
        returns (uint256);

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
    // @return bool if the call was successful
    // emits event OracleRequestCanceled
    function cancelOracleRequest(bytes32 requestId, address refundAddress)
        external
        returns (bool);

    // @notice Called by the oracle node to fulfill requests.
    // @param requestId The fulfillment request ID that must match the requester's
    // @param data The data to return to the consuming contract
    // @return bool if the external call was successful
    // emits event OracleResponse
    function fulfillOracleRequest(bytes32 requestId, string calldata data)
        external
        returns (bool);
}
