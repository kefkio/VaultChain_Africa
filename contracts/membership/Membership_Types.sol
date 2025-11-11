// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

library MembershipTypes {
    enum MemberType { REGULAR, PREMIUM, FOUNDER }

    struct Member {
        string name;
        uint256 nationalIdHash;
        string passportNumberHash;
        string phone;
        string email;
        string nextOfKinName;
        string nextOfKinPhone;
        string nextOfKinEmail;
        string nextOfKinIdNumber;
        address wallet;
        uint256 registeredAt;
        bool isActive;
        bool isGuarantor;
        uint256 shares;
        MemberType memberType;
    }
}
