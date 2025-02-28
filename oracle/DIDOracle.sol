// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IDIDOracle.sol";
import "../interfaces/IDIDOracleRequest.sol";
import "./Operator.sol";
import "./MessagingFee.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract DIDOracle is
    IDIDOracle,
    Operator,
    MessagingFee,
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    mapping(bytes32 => Commitment) public commitments;
    mapping(address => uint256) public Counters;
    mapping(bytes32 => JobOvnMapping) private jobOvnMappings;
    mapping(bytes32 => string) private claims;
    ClaimFee public Claim_Fee;

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

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    // @notice The current release version.
    function version() public pure returns (string memory) {
        return "v1.1";
    }

    /**
     *  @dev See {IDIDOracle-setOvnsForJobs}.
     */
    function setOvnsForJobs(JobOvnMapping[] calldata mappings)
        public
        override
        whenNotPaused
        authorizedFeeSetter
    {
        uint256 len = mappings.length;
        require(len != 0, "Cannot be a empty array");
        for (uint256 i = 0; i < len; i++) {
            _setOvnsForJob(mappings[i]);
        }
    }

    /**
     *  @dev See {IDIDOracle-getOvnsOfJob}.
     */
    function getOvnsOfJob(bytes32 jobId)
        public
        view
        override
        returns (address[] memory)
    {
        require(jobId != bytes32(0), "Invalid jobId");
        return jobOvnMappings[jobId].ovns;
    }

    /**
     *  @dev See {IClaim-setClaimFee}.
     */
    function setClaimFee(IClaim.ClaimFee calldata fee)
        public
        override
        whenNotPaused
        authorizedFeeSetter
    {
        IClaim.ClaimFee memory before = Claim_Fee;
        Claim_Fee = fee;
        emit ClaimFeeChanged(msg.sender, before, fee);
    }

    /**
     *  @dev See {IClaim-commitClaim}.
     */
    function commitClaim(bytes32 claimID, string calldata claim)
        public
        override
        whenNotPaused
        authorizedOperator
    {
        require(claimID != bytes32(0), "Invalid claimID");
        require(bytes(claim).length != 0, "Claim cannot be empty");
        require(bytes(claims[claimID]).length == 0, "Claim already exists");
        claims[claimID] = claim;
        emit ClaimCommitted(claimID, msg.sender);
    }

    /**
     *  @dev See {IClaim-getClaim}.
     */
    function getClaim(bytes32 claimID)
        public
        view
        override
        returns (string memory)
    {
        require(claimID != bytes32(0), "Invalid claimID");
        return claims[claimID];
    }

    /**
     *  @dev See {IDIDOracle-quote}.
     */
    function quote(bytes32 jobId, bool generateClaim)
        public
        view
        override
        returns (uint256)
    {
        IMessagingFee.MessagingFee memory fee = getMessagingFee(jobId);
        require(fee.jobId != bytes32(0), "Unsupported job");
        uint256 totalFee;
        if (!fee.free) {
            totalFee += fee.gasAmount;
        }
        if (generateClaim && !Claim_Fee.free) {
            totalFee += Claim_Fee.gasAmount;
        }
        return totalFee;
    }

    /**
     *  @dev See {IDIDOracle-oracleRequest}.
     */
    function oracleRequest(
        bytes32 jobId,
        address callbackAddress,
        address[] calldata ovns,
        bool generateClaim,
        string calldata data
    ) public payable override whenNotPaused returns (bytes32) {
        require(jobId != bytes32(0), "Invalid jobId");
        require(_verifyOvnsSupported(jobId, ovns), "Invalid ovns");
        uint256 payment = msg.value;
        _requireJobFeeMeet(jobId, generateClaim, ovns.length, payment);
        bytes32 requestId = _saveOracleRequest(
            jobId,
            callbackAddress,
            ovns,
            generateClaim,
            msg.sender,
            payment,
            data
        );
        return requestId;
    }

    /**
     *  @dev See {IDIDOracle-cancelOracleRequest}.
     */
    function cancelOracleRequest(bytes32 requestId, address refundAddress)
        public
        override
        whenNotPaused
        returns (bool)
    {
        require(refundAddress != address(0), "Non zero address");
        Commitment memory commitment = commitments[requestId];
        require(commitment.jobId != 0, "Invalid operation");
        require(commitment.expiration < block.timestamp, "Not yet due");
        require(commitment.requester == msg.sender, "Mismatched requester");
        require(
            commitment.fulfillCount == 0,
            "Fulfillment records already exist"
        );
        delete commitments[requestId];

        emit OracleRequestCanceled(
            commitment.jobId,
            requestId,
            commitment.callbackAddr,
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
     *  @dev See {IDIDOracle-fulfillOracleRequest}.
     */
    function fulfillOracleRequest(bytes32 requestId, string calldata data)
        public
        override
        whenNotPaused
        returns (bool)
    {
        Commitment storage commitment = commitments[requestId];
        require(commitment.jobId != bytes32(0), "Invalid requestId");
        (bool specified, uint256 index) = _verifyOvnSpecified(
            commitment.ovns,
            msg.sender
        );
        require(specified, "Non-specified ovn");
        address callbackAddress = commitment.callbackAddr;
        bytes4 callbackFunctionId = commitment.callbackFunctionId;
        uint256 len = commitment.ovns.length;
        if (len == 1) {
            delete commitments[requestId];
        } else {
            commitment.fulfillCount++;
            commitment.ovns[index] = commitment.ovns[len - 1];
            commitment.ovns.pop();
        }
        emit fulfillOracleRequested(requestId, msg.sender);
        if (isContract(callbackAddress)) {
            (bool success, ) = callbackAddress.call(
                abi.encodeWithSelector(callbackFunctionId, requestId, data)
            );
            require(success, "Callback error occurred");
            return success;
        }
        return true;
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
        uint256 length;
        assembly {
            length := extcodesize(addr)
        }
        return length > 0;
    }

    // @notice Set the supported ovn collection for the specified job.
    function _setOvnsForJob(JobOvnMapping calldata _mapping) internal {
        require(_mapping.jobId != bytes32(0), "Invalid jobId");
        require(_mapping.ovns.length != 0, "ovns cannot be a empty array");
        address[] memory before = getOvnsOfJob(_mapping.jobId);
        jobOvnMappings[_mapping.jobId] = _mapping;
        emit JobOvnMappingChanged(
            msg.sender,
            _mapping.jobId,
            before,
            _mapping.ovns
        );
    }

    // @notice Require payment to meet the job fee condition, otherwise throw an exception.
    function _requireJobFeeMeet(
        bytes32 jobId,
        bool generateClaim,
        uint256 ovnNum,
        uint256 payment
    ) internal view {
        uint256 jobfee = quote(jobId, generateClaim);
        require(
            payment >= jobfee * ovnNum * tx.gasprice,
            "Insufficient payment"
        );
    }

    // @notice Verify that the ovn specified by the job is valid.
    function _verifyOvnsSupported(bytes32 jobId, address[] calldata ovns)
        internal
        view
        returns (bool)
    {
        address[] memory allOvns = getOvnsOfJob(jobId);
        uint256 allOvnslen = allOvns.length;
        uint256 len = ovns.length;
        if (len == 0 || len > allOvnslen) {
            return false;
        }
        for (uint256 i = 0; i < len; i++) {
            address specifiedOvn = ovns[i];
            bool flag = false;
            for (uint256 j = 0; j < allOvnslen; j++) {
                if (allOvns[j] == specifiedOvn) {
                    flag = true;
                    break;
                }
            }
            if (!flag) {
                return false;
            }
        }
        return true;
    }

    // @notice Generate and save commitments for oracle request.
    // emits event OracleRequested
    function _saveOracleRequest(
        bytes32 jobId,
        address callbackAddress,
        address[] calldata ovns,
        bool generateClaim,
        address requester,
        uint256 amount,
        string calldata data
    ) internal returns (bytes32 requestId) {
        uint256 nonce = Counters[requester];
        bytes4 callbackFunctionId;
        if (isContract(callbackAddress)) {
            callbackFunctionId = IDIDOracleRequest.oracleResponse.selector;
        }
        uint256 expiration = block.timestamp + EXPIRYTIME;
        requestId = keccak256(abi.encodePacked(requester, nonce));
        require(commitments[requestId].jobId == 0, "Duplicated requestId");
        Counters[requester]++;
        commitments[requestId] = Commitment(
            jobId,
            callbackAddress,
            callbackFunctionId,
            amount,
            expiration,
            requester,
            ovns,
            generateClaim,
            0
        );

        emit OracleRequested(
            jobId,
            requestId,
            requester,
            ovns,
            generateClaim,
            amount,
            data
        );
    }

    // @notice Verify whether the sender is in the specified OVN list. If it is true, return the index position.
    function _verifyOvnSpecified(address[] storage ovns, address sender)
        internal
        view
        returns (bool, uint256)
    {
        bool flag;
        uint256 index;
        for (uint256 i = 0; i < ovns.length; i++) {
            if (ovns[i] == sender) {
                flag = true;
                index = i;
                break;
            }
        }
        return (flag, index);
    }
}
