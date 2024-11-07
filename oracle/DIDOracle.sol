// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/DIDOracleInterface.sol";
import "../interfaces/DIDOracleRequestInterface.sol";
import "./Operator.sol";
import "./MessagingFee.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract DIDOracle is
    DIDOracleInterface,
    Operator,
    MessagingFee,
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    mapping(bytes32 => Commitment) public commitments;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Pausable_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /**
     *  @dev See {DIDOracleInterface-quote}.
     */
    function quote(bytes32 jobId) public view returns (uint256) {
        IMessagingFeeInterface.MessagingFee memory fee = getMessagingFee(jobId);
        if (fee.free) {
            return 0;
        }
        return fee.gasAmount;
    }

    /**
     *  @dev See {DIDOracleInterface-oracleRequest}.
     */
    function oracleRequest(
        bytes32 jobId,
        address callbackAddress,
        uint256 nonce,
        string memory data
    ) public payable override whenNotPaused returns (bool) {
        uint256 amount = msg.value;
        address requester = msg.sender;
        bytes4 callbackFunctionId = DIDOracleRequestInterface
            .oracleResponse
            .selector;
        bytes32 requestId = _verifyAndProcessOracleRequest(
            jobId,
            requester,
            amount,
            callbackAddress,
            callbackFunctionId,
            nonce
        );
        emit OracleRequest(
            jobId,
            requester,
            requestId,
            amount,
            callbackAddress,
            callbackFunctionId,
            data
        );
        return true;
    }

    /**
     *  @dev See {DIDOracleInterface-cancelOracleRequest}.
     */
    function cancelOracleRequest(
        bytes32 requestId,
        address refundAddress
    ) public override whenNotPaused returns (bool) {
        require(refundAddress != address(0), "Non zero address");
        Commitment memory commitment = commitments[requestId];
        require(commitment.jobId != 0, "Invalid operation");
        require(commitment.expiration < block.timestamp, "Not yet due");
        require(
            commitment.callbackAddr == msg.sender,
            "Mismatched callback address"
        );
        delete commitments[requestId];

        emit OracleRequestCanceled(
            commitment.jobId,
            commitment.callbackAddr,
            requestId,
            commitment.amount
        );

        if (commitment.amount > 0) {
            require(
                address(this).balance >= commitment.amount,
                "Insufficient balance"
            );
            (bool success, ) = refundAddress.call{value: commitment.amount}("");
            require(success, "Refund failed");
        }
        return true;
    }

    /**
     *  @dev See {DIDOracleInterface-fulfillOracleRequest}.
     */
    function fulfillOracleRequest(
        bytes32 requestId,
        string memory data
    ) public override whenNotPaused authorizedOperator returns (bool) {
        require(commitments[requestId].jobId != 0, "Invalid requestId");
        address callbackAddress = commitments[requestId].callbackAddr;
        bytes4 callbackFunctionId = commitments[requestId].callbackFunctionId;
        delete commitments[requestId];
        emit OracleResponse(requestId, msg.sender);
        // All updates to the oracle's fulfillment should come before calling the
        // callback(addr+functionId) as it is untrusted.
        // See: https://solidity.readthedocs.io/en/develop/security-considerations.html#use-the-checks-effects-interactions-pattern
        (bool success, ) = callbackAddress.call(
            abi.encodeWithSelector(callbackFunctionId, requestId, data)
        ); // solhint-disable-line avoid-low-level-calls
        require(success, "Callback error occurred");
        return success;
    }

    // @notice Verify the Oracle Request and record necessary information
    // @param sender The sender of the request
    // @param amount The quantity of native token for payment with specified job
    // @param callbackAddress The callback address for the response
    // @param callbackFunctionId The callback function ID for the response
    // @param nonce The nonce sent by the requester
    // @param data The request parameters
    // @return requestId
    function _verifyAndProcessOracleRequest(
        bytes32 jobId,
        address sender,
        uint256 amount,
        address callbackAddress,
        bytes4 callbackFunctionId,
        uint256 nonce
    ) private returns (bytes32 requestId) {
        require(isContract(sender), "EOA calls are not supported");
        IMessagingFeeInterface.MessagingFee memory fee = getMessagingFee(jobId);
        require(fee.jobId != 0, "Unsupported job");
        if (fee.free == false) {
            require(
                amount >= fee.gasAmount * tx.gasprice,
                "Insufficient payment"
            );
        }
        uint256 expiration = block.timestamp + EXPIRYTIME;
        requestId = keccak256(abi.encodePacked(sender, nonce));
        require(commitments[requestId].jobId == 0, "Duplicated requestId");
        commitments[requestId] = Commitment(
            jobId,
            callbackAddress,
            callbackFunctionId,
            amount,
            expiration
        );
        return requestId;
    }

    /**
     *  @dev See {Operator-_canSetOperator}.
     */
    function _canSetOperator() internal view override returns (bool) {
        return owner() == msg.sender;
    }

    /**
     *  @dev See {MessagingFee-_canSetFeeSetter}.
     */
    function _canSetFeeSetter() internal view override returns (bool) {
        return owner() == msg.sender;
    }

    // return true if `addr` is a contract.
    function isContract(address addr) private view returns (bool hasCode) {
        uint length;
        assembly {
            length := extcodesize(addr)
        }
        return length > 0;
    }
}
