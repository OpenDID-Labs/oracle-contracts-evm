// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMessagingFeeInterface {
    struct MessagingFee {
        bytes32 jobId;
        bool free;
        uint256 gasAmount;
    }
    event MessagingFeesChanged(
        address indexed sender,
        IMessagingFeeInterface.MessagingFee[] fees
    );

    event FeeSetterChanged(address indexed setter, bool authorized);

    event Withdraw(address indexed sender, address to, uint256 amount);

    event ExpirytimeChanged(uint256 before, uint256 current);

    // @notice Sets the effective time for canceling Oracle requests.
    // @param secs Seconds count
    // emits event ExpirytimeChanged
    function setExpirytime(uint256 secs) external;

    // @notice Sets the messageing fee permission for a given setter. Use `true` to allow, `false` to disallow.
    // @param setter The address of the authorized account
    // emits event FeeSetterChanged
    function setFeeSetter(address setter, bool authorized) external;

    // @notice Use this to check if a addresss is authorized for set messaging fees.
    // @param setter The address of the account
    // @return The authorization status of the account
    function isAuthorizedFeeSetter(address setter) external view returns (bool);

    // @notice Sets the Job fees.
    // @param fees The Job Fee list
    // emits event MessagingFeesChanged
    function setMessagingFees(
        IMessagingFeeInterface.MessagingFee[] memory fees
    ) external;

    // @notice gets the Job fee.
    // @param jobId The Job Specification ID
    // @return fee The calculated messaging fee inforamtion
    function getMessagingFee(
        bytes32 jobId
    ) external view returns (MessagingFee memory);

    // @notice Called by the FeeSetter to withdraw fee.
    // @param to address to withdraw fee to
    // @param amount amount to withdraw
    function withdrawFee(address to, uint256 amount) external;
}
