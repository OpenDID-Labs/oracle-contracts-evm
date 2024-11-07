// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "./DIDOracleRequestInterface.sol"
interface DIDOracleInterface {
    struct Commitment {
        bytes32 jobId;
        address callbackAddr;
        bytes4 callbackFunctionId;
        uint256 amount;
        uint256 expiration;
    }

    event OracleRequest(
        bytes32 indexed jobId,
        address requester,
        bytes32 requestId,
        uint256 amount,
        address callbackAddr,
        bytes4 callbackFunctionId,
        string data
    );

    event OracleResponse(bytes32 indexed requestId, address operator);

    event OracleRequestCanceled(
        bytes32 indexed jobId,
        address requester,
        bytes32 requestId,
        uint256 amount
    );

    // @notice gets the Job fee.
    // @param jobId The Job Specification ID
    // @return gasAmount The amount of gas used for job messaging fee
    function quote(bytes32 jobId) external view returns (uint256);

    // @notice Creates the oracle request.
    // @param callbackAddress The consumer of the request
    // @param jobId The Job Specification ID
    // @param callbackAddress The address the oracle data will be sent to
    // @param nonce The nonce sent by the requester
    // @param data The request parameters associated with jobid
    // @return Status if the call was successful
    // emits event OracleRequest
    function oracleRequest(
        bytes32 jobId,
        address callbackAddress,
        uint256 nonce,
        string memory data
    ) external payable returns (bool);

    // @notice Cancels the oracle request.
    // @param requestId The fulfillment request ID
    // @param refundAddress The address to receive the refund
    // @return Status if the call was successful
    // emits event OracleRequestCanceled
    function cancelOracleRequest(
        bytes32 requestId,
        address refundAddress
    ) external returns (bool);

    // @notice Called by the oracle node to fulfill requests.
    // @param requestId The fulfillment request ID that must match the requester's
    // @param data The data to return to the consuming contract
    // @return Status if the external call was successful
    // emits event OracleResponse
    function fulfillOracleRequest(
        bytes32 requestId,
        string memory data
    ) external returns (bool);
}
