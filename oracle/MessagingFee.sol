// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IMessagingFeeInterface.sol";

abstract contract MessagingFee is IMessagingFeeInterface {
    mapping(address setter => bool authorized) private feeSetters;

    mapping(bytes32 jobId => IMessagingFeeInterface.MessagingFee)
        public messagingFees;
    uint256 public EXPIRYTIME;

    /**
     *  @dev See {IMessagingFeeInterface-setExpirytime}.
     */
    function setExpirytime(uint256 secs) public override authorizedFeeSetter {
        require(secs > 0, "Non zero");
        uint256 before = EXPIRYTIME;
        EXPIRYTIME = secs;
        emit ExpirytimeChanged(before, EXPIRYTIME);
    }
    /**
     *  @dev See {IMessagingFeeInterface-setFeeSetter}.
     */
    function setFeeSetter(
        address setter,
        bool authorized
    ) public override authorizedFeeSetterSetter {
        require(setter != address(0), "Non zero address");
        require(feeSetters[setter] != authorized, "Invalid operation");
        feeSetters[setter] = authorized;
        emit FeeSetterChanged(setter, authorized);
    }

    /**
     *  @dev See {IMessagingFeeInterface-isAuthorizedFeeSetter}.
     */
    function isAuthorizedFeeSetter(
        address setter
    ) public view override returns (bool) {
        return feeSetters[setter];
    }

    /**
     *  @dev See {IMessagingFeeInterface-setMessagingFees}.
     */
    function setMessagingFees(
        IMessagingFeeInterface.MessagingFee[] memory fees
    ) public override authorizedFeeSetter {
        require(fees.length > 0, "Invalid fees data");
        for (uint256 i = 0; i < fees.length; i++) {
            require(fees[i].jobId != 0, "Invalid jobId");
            if (fees[i].free) {
                require(fees[i].gasAmount > 0, "Invalid gasAmount");
            }
            messagingFees[fees[i].jobId] = fees[i];
        }
        emit MessagingFeesChanged(msg.sender, fees);
    }

    /**
     *  @dev See {IMessagingFeeInterface-getMessagingFee}.
     */
    function getMessagingFee(
        bytes32 jobId
    )
        public
        view
        override
        returns (IMessagingFeeInterface.MessagingFee memory)
    {
        return messagingFees[jobId];
    }

    /**
     *  @dev See {IMessagingFeeInterface-withdrawFee}.
     */
    function withdrawFee(
        address to,
        uint256 amount
    ) public override authorizedFeeSetter {
        require(to != address(0), "Non zero address");
        require(address(this).balance >= amount, "Insufficient balance");
        (bool success, ) = to.call{value: amount}("");
        require(success, "Withdraw native token failed");
        emit Withdraw(msg.sender, to, amount);
    }

    // @notice customizable guard of who can update the authorized feesetter list
    // @return bool whether sender can update authorized feesetter list
    function _canSetFeeSetter() internal view virtual returns (bool);

    // @notice prevents non-authorized addresses from calling this method
    modifier authorizedFeeSetterSetter() {
        require(_canSetFeeSetter(), "Cannot set fee setter");
        _;
    }

    // @notice prevents non-authorized addresses from calling this method
    modifier authorizedFeeSetter() {
        require(feeSetters[msg.sender], "Non authorized fee setter");
        _;
    }

    // @notice receives funds
    receive() external payable {}
}
